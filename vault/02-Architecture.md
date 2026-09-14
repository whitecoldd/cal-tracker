---
tags: [architecture]
---

# Architecture

## Stack

| Concern | Choice | Note |
|---|---|---|
| State | `flutter_riverpod` 2.6.1 | Hand-written providers, no codegen |
| DB | `drift` 2.34.x + `sqlite3` 3.5.2 | Reactive, migrations, type-safe SQL |
| Food data | `openfoodfacts` 3.30.2 | Free, **no API key**, barcodes/brands/NOVA/additives |
| AI | OpenRouter REST via `dio` | See [[05-AI-Layer]] |
| Activity | `health` 13.3.2 | Health Connect; real step *history* |
| Capture | `mobile_scanner`, `image_picker` | Barcode + meal photos |
| Charts | `fl_chart` | Week's End reveal only |
| Secrets | `flutter_secure_storage` | Android keystore |
| Fonts | Bundled Cinzel + EB Garamond | Offline; variable, `wght` axis |
| Time | `package:clock` | So tests can freeze the calendar |

## Repository layout

```
cal-tracker/
  lib/              app source (see Layering below)
  test/             unit + widget + golden tests
  assets/           seed food table, fonts
  android/          minSdk 26, FlutterFragmentActivity
  tools/            one-off generators and scripts
  vault/            ← this Obsidian vault, versioned with the code
  CLAUDE.md         the rules
```

The vault sits **in** the repo. It was moved here from
`C:\dev\cal-tracker-vault\cal-tracker` because the one-task-one-commit rule
requires a task’s code and its [[90-Progress-Log]] entry to be the same
commit, which two separate repos cannot give you. `vault/.obsidian/` is
committed (theme, accent, enabled plugins); `workspace*.json` is not, since
it is per-machine window state that would churn on every commit.

## Layering

```
lib/
  data/        drift database, DAOs, OpenRouter + Open Food Facts clients
  domain/      PURE DART. nutrition engine, scoring, reveal gate, models
  features/    <feature>/ screens + riverpod providers
  theme/       tokens, typography, MaterialTheme assembly
  widgets/     shared ornate primitives (panels, vials, cards, sealed nodes)
```

**`domain/` must not import Flutter.** All the maths that matters — TDEE,
glycemic load, toxicity, the reveal gate — is pure Dart and tested directly
against fixtures with no widget tree involved.

## The blackout, as a type

The invariant from [[01-Vision]] is enforced at compile time:

```dart
sealed class SealedValue<T> { const SealedValue(); }
final class Sealed<T>   extends SealedValue<T> { const Sealed(); }
final class Revealed<T> extends SealedValue<T> { final T value; const Revealed(this.value); }
```

Every verdict-bearing value crosses into the UI as `SealedValue<T>`. A widget
physically cannot render a number it has not unwrapped, and
`non_exhaustive_switch_expression` is an **analyzer error**, so adding a state
without handling it fails the build.

`RevealGate` decides: revealed if the date is before the current week's start,
or today is the configured week-end weekday.

Tests freeze the clock to each weekday and assert `Sealed` on every non-reveal
day. That is why `package:clock` is mandatory and `DateTime.now()` is banned
outside `clock.now()`.

## The energy model (T3)

Two estimates of the same movement must never be added together.

| Path | Formula | When |
|---|---|---|
| **Measured** | `BMR x 1.2 + walking above ~3,000 steps` | Whenever step data exists |
| **Estimated** | `BMR x activityLevel.multiplier` | Fallback only |

The 1.2 sedentary multiplier already contains roughly 3,000 steps, so measured
walking bills only what is above that. Health Connect's active energy, when
reported, **replaces** the walking estimate rather than adding to it.

Inflating maintenance would make a deficit look real when it is not — the exact
failure this product exists to avoid — so each rule has a test asserting the
result is *not* the naive sum.

`dailyTarget` is floored at 1,200 kcal. `ActivityLevel.hearthbound` equals the
sedentary multiplier exactly, so the two paths agree for a sedentary user.

**Maintenance appears at setup and in Settings, never on a daily screen.**
Knowing your maintenance is knowing your body; printing it beside today's intake
is handing over the verdict.

## Durability — "survives reinstall"

Two independent layers, because Android Auto Backup alone is not trustworthy
(needs Google backup enabled, 25MB cap, silent failure):

1. **Android Auto Backup** — `backup_rules.xml` / `data_extraction_rules.xml`
   include the database, prefs and meal photos; explicitly *exclude* the
   secure-storage keystore file.
2. **Folder mirror** — a continuously-written JSON + Markdown mirror in
   `/storage/emulated/0/Documents/WitchersDiet/`, outside the app sandbox, so
   an uninstall cannot touch it. On first launch after a reinstall the app
   offers to restore from it.

The mirror uses `MANAGE_EXTERNAL_STORAGE`. That is acceptable **because this is
a sideloaded personal build**; Play Store distribution would require swapping in
a SAF directory picker with a persisted URI grant.

The permission is requested by a small platform channel in `MainActivity.kt`
firing `Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`, **not** by
`permission_handler` — see below.

## Toolchain constraints

Pinned to Flutter **3.41.6** / Dart **3.11.4**.

Flutter pins `meta` 1.17.0 → caps `analyzer` → caps `drift_dev` at 2.34.x,
which is incompatible with `drift` ≥ 2.35.0. So:

- `drift` + `drift_dev` both held at `>=2.34.0 <2.35.0`, moved together
- `flutter_riverpod` stays 2.6.1 (3.4.1+ needs Dart 3.12)
- **No `sqlite3_flutter_libs`** — EOL, superseded by `sqlite3` 3.x native assets

Upgrading the Flutter SDK clears all three at once, but the same SDK serves the
user's other projects, so it is not done unilaterally.

## Android specifics

- `minSdk 26` — the floor for Health Connect, and gives native `java.time`
- `MainActivity : FlutterFragmentActivity` — the health plugin needs a
  FragmentActivity host for its permission contract
- Core library desugaring on; R8 + resource shrinking on release
- Release signs with debug keys (personal sideload, no keystore ceremony)

### No `permission_handler`

Its Android module (14.1.0) fails to compile against Gradle 8.14 / KGP 2.2.20 —
the build script uses the `kotlin { compilerOptions { } }` DSL and hits
`srcDirs` deprecation-as-error. It is not needed:

| Permission | Requested by |
|---|---|
| Camera | `image_picker` / `mobile_scanner` |
| `ACTIVITY_RECOGNITION`, Health Connect | `health` |
| `MANAGE_EXTERNAL_STORAGE` | platform channel in `MainActivity.kt` (T13) |
