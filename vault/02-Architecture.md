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

`RevealGate` (T7) is the single place that answers "is the week closed yet?".
Two ways to be readable, and only two:

- **The week has closed.** A past week is history; there is nothing left to
  influence by reading it, and refusing would make the app useless as a record.
- **Today is the week-end day**, and the value belongs to the week that day
  closes. This is the reveal.

Anything else — the live week on any other day, or a future week — is sealed.

```
lib/domain/
  reveal_gate.dart   RevealGate: the one definition of "closed yet?"
  reckoning.dart     Reckoning: the week's verdict, every field sealed
lib/features/reckoning/
  reckoning_providers.dart
  reckoning_screen.dart
```

### The gate takes a callback, not a value

```dart
SealedValue<T> gate<T>(Day subject, {required Day today, required T Function() compute})
```

A sealed verdict is **never calculated at all**. If the arithmetic ran and the
result were merely wrapped, the number would exist in memory — reachable by a
log line, a `toString`, a crash report, or a future refactor that reaches past
the type. The seal is not a curtain drawn over an answer; there is no answer
yet. There is a test asserting the callback is not invoked.

### What is sealed, and what is not

| Sealed | Not sealed |
|---|---|
| Energy balance, and its per-day average | Days logged |
| Weight delta and trend | Days until the week closes |
| Projected weight change | The week's start and end dates |
| Body-fat estimate | |

`loggedDays` is the interesting exclusion. It says nothing about gaining or
losing, and it is the one figure that tells the user how much the sealed ones
will be worth — a verdict drawn from two logged days deserves to be read with
suspicion. `daysUntilReveal` is likewise a calendar fact, and it is what makes
the seal read as deliberate rather than broken.

### Judgements inside the verdict

- **The average is per *logged* day, not per calendar day.** Dividing a
  four-day week by seven would report a deficit the user never ran. An
  unlogged day is unknown, not fasted.
- **A weight move under 0.3 kg is `holding`.** Day-to-day swings of a kilogram
  from water, glycogen and gut contents are ordinary; calling a 0.2 kg move a
  trend is the behaviour this whole app exists to prevent.
- **Energy balance is rounded to 10 kcal.** It carries the error of a BMR
  estimate, a step count and a hundred portion guesses. Reporting it to the
  calorie would be a lie about how well it is known.
- **Beyond ±2 kg a week the projection is not credible** — almost always a
  mis-typed portion or a missing week of logs, and a confident "you gained
  4 kg" would be worse than saying nothing.

### `RevealGate` has value equality on purpose

It is rebuilt whenever the profile stream emits. Without `==`, each rebuild
produces an instance Riverpod considers *different*, invalidating everything
watching it — including the provider that assembles the week.

Tests freeze the clock to each weekday and assert `Sealed` on every non-reveal
day, across all seven possible week-end days. That is why `package:clock` is
mandatory and `DateTime.now()` is banned outside `clock.now()`.


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

## The scoring engine (T6)

```
lib/domain/
  nutrition.dart   FoodPanel, Serving, NutrientTotals, MacroShare, GI/GL
  harm.dart        HarmKind, HarmFlag, Toxins — the guideline readings
  scoring.dart     Vitality, Toxicity (+ cross-day carry-over)
  rarity.dart      FoodRarity and the ranking rule
lib/data/
  nutrition_adapter.dart   drift rows -> the pure types above
lib/features/alchemy/
  alchemy_providers.dart
  alchemy_screen.dart      vials, meters, humours, curses
```

`domain/` must not import Flutter **or drift**, so the engine works on plain
value types and `nutrition_adapter.dart` is the seam. That is what lets the
whole of the maths be tested against hand-written fixtures with no database in
the room — see `../test/nutrition_test.dart` and `../test/scoring_test.dart`.

### The vials cannot take a target

The hard constraint on this screen. A macro target derived from TDEE can be
subtracted back into a deficit, so intake-against-target on a daily screen
*is* the verdict, however it is dressed. See [[01-Vision]].

So carbohydrate and fat fill against their share of the day's **own** energy,
inside the published AMDR bands (carbs 45–65%, fat 20–35%, protein 10–35%).
The vial answers "how was this day composed", never "was there enough of it".
Protein additionally carries a g/kg adequacy mark and fibre a flat 30 g — both
energy-independent, and body mass is legitimate because weight is logged and
shown daily with only its *interpretation* sealed.

`AlchemyVial` grew optional `valueLabel` / `captionLabel` for this. Its
built-in caption is "of {target}", which is precisely the framing the daily
screens must not carry.

### Shares are taken against Atwater energy, not label energy

`macroKcal` (4/4/9/7 per gram) rather than the food's stated `kcal`. Label
energy and the Atwater sum routinely disagree by a few percent, and shares
taken against a different denominator than their own numerators do not add up
to 100 — which is visible and looks like a bug.

### Unknown is not zero, and not a virtue

Three places where the engine refuses to guess, all for the same reason:

- **Free sugars and trans fat** stay null when absent. "No added sugar" and
  "nobody filled this field in" are different claims, and a defaulted zero
  quietly exonerates every product with a thin record.
- **An unknown NOVA group** counts as neither whole food nor ultra-processed.
  Every hand-typed food has no NOVA group; flattering it upward would make the
  library look excellent, and condemning it would put a red mark on real food.
- **Average GI** is weighted only over foods that actually carried an index.
  Averaging across all carbohydrate would treat an unknown GI as zero and drag
  the figure down, inventing a low-GI day out of missing data.

### Rarity moved into `domain/`

`FoodRarity` carries a name and no colour; the theme maps it to one. Before T6
the enum lived in the widget layer and the ranking rule was copy-pasted at each
call site, which is how the same food could read Epic in one list and Common in
another. There is now exactly one `rankFood`.

## Remote food lookup (T5)

Step three of the resolution order in [[05-AI-Layer]]. Free, keyless, and tried
only after the local library and the seed table have both missed.

```
lib/data/remote/
  remote_food.dart   a food found upstream, not yet in the library
  off_mapper.dart    Open Food Facts product -> RemoteFood. Pure, no network
  food_remote.dart   the FoodRemote interface + the Open Food Facts client
```

**`RemoteFood` is deliberately not `Food`.** A `Food` carries a real row id and
can be logged; a `RemoteFood` cannot, because an entry referencing it would
point at a row that does not exist. The only way across is `toCompanion()` plus
a write to `foods` — which *is* the write-back the budget rule demands. The
type system makes "show it, then forget it" impossible to write by accident,
the same trick [[01-Vision]] uses for the blackout.

**The mapper is pure so the awkward parts are testable.** Open Food Facts is
crowd-sourced and its fields are inconsistent, so all the interesting behaviour
is in fallbacks and unit conversions — and those are exactly what a live test
would not pin down. Three that bite:

| Field | Trap |
|---|---|
| Sodium | Reported in **grams**; the column is **mg**. Many products carry `salt` instead, which is sodium x 2.5 |
| Alcohol | Reported as **% by volume**, not grams. Ethanol is 0.789 g/ml |
| Energy | Often only `energy-kj`. 1 kcal = 4.184 kJ |

**A product with no energy is rejected, not mapped to zero.** Open Food Facts
holds many entries that are barely more than a barcode and a photo. Logging one
as 0 kcal would let someone believe they had recorded their lunch while adding
nothing to the day — worse than not offering the food at all. Same for a
product with no name.

`addedSugar` and `transFat` stay **null** when absent rather than defaulting to
zero: "no added sugar" and "nobody filled this field in" are different claims,
and the T6 harm model has to tell them apart.

**Confidence reflects completeness**, from 0.6 for energy-only to 0.95 for a
full panel. That number decides whether a later, better source may overwrite
the row, so it has to mean "how much of this do we actually know" rather than
just "it came from Open Food Facts".

### Failing quietly

Every network failure — timeout, socket, upstream throttling, malformed JSON —
is funnelled into one `RemoteUnavailable`. The search sheet renders it as a
footnote under the local results, never as an error state, because the app is
fully usable with no network. Without the single type, the sheet would have to
know about each failure mode separately, and the one it forgot would be the one
that broke offline use.

Search results appear **below** local ones. That is the resolution order made
visible: something already on the device is the better answer, because the user
has used or corrected it before.

### Barcodes

`mobile_scanner`, restricted to the formats actually printed on food packaging
(EAN-13/8, UPC-A/E) so it cannot lock onto a QR code on the same label. The
scanner screen returns a `String?` and knows nothing about the food library —
the caller owns the resolution order.

A scanned barcode checks the library **first**. This is not an optimisation: a
barcode the user has already scanned and then corrected by hand must resolve to
their correction, not to whatever Open Food Facts says this week.

Camera permission is requested by the plugin itself — there is no
`permission_handler` here (see below) — so a denial arrives as a
`MobileScannerException`, handled in the scanner's `errorBuilder`.

## Movement (T10)

```
lib/domain/activity.dart        Stamina, the Aard charge, the merge rule
lib/data/health/
  step_reader.dart              Health Connect behind an interface
  activity_sync.dart            platform -> activity_days
lib/features/activity/
  activity_providers.dart
  activity_panel.dart           steps, distance, Stamina — and nothing else
  manual_steps_sheet.dart
```

### `ActivityView` is the guard

| Visible daily | Never rendered |
|---|---|
| Steps, distance | Active energy |
| Stamina, the Aard charge | |

Active energy is a term in expenditure, and intake beside expenditure is the
verdict. A panel reading "8,240 steps · 437 kcal burned" beside the day's
intake hands the user a subtraction.

The stored row carries `activeKcal` because the weekly reckoning needs it. The
UI is handed an `ActivityView`, which has **nowhere to put it** — the same
move as `SealedValue`, one layer up. A widget cannot render what it was never
given, and adding the field would mean editing `activity.dart` with the reason
it is absent written directly above. See [[01-Vision]].

Stamina is safe on the daily side because a **step goal is not a verdict
target**: it is chosen in character creation and has nothing to do with energy
balance, so no arrangement of steps-against-goal can be solved into a deficit.

### Rules the sync holds

- **A manual entry always wins.** The user typed it because the counter was
  wrong; a sync that overwrote it would make the override useless.
- **A day the device never saw is absent, not zero.** A zero claims the user
  did not move. Absent says the device did not see it.
- **Every sync re-reads a week.** Health Connect back-fills, so a day already
  past can gain steps once a watch catches up.
- **An interval counts towards the day it started.** Splitting a
  midnight-crossing walk proportionally would be more correct and less
  predictable, and the figures are read against a remembered calendar day.

### Permissions

Requested by the `health` plugin itself. There is no `permission_handler` in
this project, and `MainActivity` extends `FlutterFragmentActivity` precisely so
the plugin can run its permission contract — see the section below on why.

Health Connect being absent is a **state, not an error**: Settings offers to
install it, and steps can be typed in the Journal either way. The app reads
movement and never writes any, which the permission screen says out loud.

## Getting about (T12b)

The Journal carried every other screen as an app-bar action until the Bestiary
made a fifth. Five 48-pixel buttons plus a title do not fit across 360 logical
pixels, so the destinations moved into a drawer.

```
lib/features/shell/paths_drawer.dart
```

The crowding was the signal rather than the problem: the plan deferred a
navigation shell to T12, and that is when it fell due. A drawer also gives each
destination the **word** that names it, which matters because the vocabulary is
load-bearing (CLAUDE.md §5) — an icon alone does not carry "The Reckoning".

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

The permission is requested by a small platform channel in `MainActivity.kt`,
**not** by `permission_handler` — see below. It fires
`ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` with a package URI so the user
lands on *this* app rather than a list of every app installed, falling back to
the bare action on OEM builds that lack the per-app screen.

### As built (T13)

```
lib/data/backup/
  snapshot.dart        the portable shape, and the Markdown rendering
  storage_access.dart  the channel, behind an interface
  backup_service.dart  database <-> folder
lib/features/backup/
  backup_providers.dart
  restore_offer_screen.dart
```

> [!warning] The mirror reads and writes **below** the type converters
> `Day` is a `yyyymmdd` integer and an enum is its name. Drift's own `toJson`
> hands back the *Dart* objects — a `Day` instance, which will not encode at
> all. The mirror uses `customSelect` / `customInsert` so it carries exactly
> what SQLite holds.
>
> The deeper reason: **a converter is a property of this build, and a backup
> has to outlive it.** A mirror written through today's converters stops
> loading the day one changes. There are tests asserting the `Day` converter
> and an enum column both survive a round trip; losing the former would move
> every meal into a different week, which is the one failure that corrupts the
> product.

Other rules the service holds:

- **A restore is one transaction**, tables cleared in reverse dependency order
  and inserted in forward order. A failure halfway leaves the old data intact —
  the worst outcome is not a failed restore but a half-restored database that
  looks plausible.
- **One bad row does not cost the restore.** An older schema can carry a column
  this build lacks; losing a year to one row would be worse.
- **The JSON is written to `.part` and renamed**, which is atomic on the same
  filesystem. The Markdown goes first: a stale JSON beside a fresh Markdown is
  recoverable, a truncated JSON is not.
- **Restore is offered before onboarding**, and only when the database is fresh
  *and* a backup exists. Asking afterwards would mean restoring over a profile
  the user had just typed.
- **"Continuous" means on pause.** Writing after every meal would spend a file
  write per meal on a file nobody reads between meals; backgrounding is both
  the end of a session and the last reliable moment in the process's life.

The Markdown exists to be *read* — a row count per table, the profile, and every
closed week with its account. A backup nobody ever opens is a backup nobody
discovers is broken, and the file says plainly which of the two restores.

## Icon and splash (T14)

Both are **vector and XML**, with no binary asset anywhere. minSdk 26 means
every device supports adaptive icons, so the launcher mark lives in the repo as
text — a hollow diamond node inside ornate corner brackets, the app's own
language, gold on void black.

```
res/drawable/ic_launcher_foreground.xml
res/mipmap-anydpi-v26/ic_launcher.xml
res/drawable/launch_background.xml      API 26-30
res/values-v31/styles.xml               API 31+
```

The splash needs **both** files. Android 12 replaced the `windowBackground`
mechanism with a real API; without `values-v31` a modern phone ignores
`launch_background.xml` and draws the system default. `NormalTheme` is void
black too, so there is no white frame anywhere between the icon tap and the
first Flutter frame.

> [!note] `<bitmap>` cannot point at a vector
> It needs a raster and fails to inflate. Use a sized layer-list item with
> explicit width and height — a bare item stretches its drawable across the
> whole window.

## Release

```bash
flutter build apk --release --split-per-abi
```

R8 and resource shrinking are on. **Signed with the debug key deliberately**:
this is a sideloaded personal build that will never see the Play Store. It
installs and updates fine, but will not upgrade over a build signed with a
different key.

arm64 lands around 29 MB — mostly the two bundled variable fonts and the native
libraries for sqlite3, Health Connect, the scanner and the image picker.

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
