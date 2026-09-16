# The Witcher's Diet

A gamified food, activity and body tracker for Android that **refuses to tell you
whether you are losing or gaining weight until the week is over.**

Personal, serverless, offline-first. All data lives on the phone.

**Version 1.1.0 — "The Reckoning Remade".** Versioning
scheme and release notes: [CHANGELOG.md](CHANGELOG.md).

---

## Why

Body weight swings 1–2kg a day on water, sodium and glycogen — more than any real
weekly fat change. A daily weigh-in mostly measures yesterday's salt, and reacting
to it drives the wrong behaviour.

So this app collects everything and reveals nothing directional until week's end.

- **Every day except the last** — calories, macros, glycemic load, toxicity,
  steps, streak. Enough to make decisions, useless for guessing the trend.
- **Week's End** — read as **The Tally** (figures) or **The Tale** (prose).
  The curses the week carried, the E-numbers eaten, what it held and what it
  carried — readable any day. Energy balance, weight delta, projection and
  body composition wait for the week to close.

Weight is still logged every day. Only its *interpretation* is sealed, and that
seal is enforced by the type system, not by UI discipline: verdict values cross
into the UI as `SealedValue<T>`, and a widget cannot render what it has not
unwrapped.

The week-end day is whichever weekday you pick during character creation.

## The Witcher 3 frame

Harsh feedback lands better as lore than as judgement.

| Screen | What it is |
|---|---|
| **Journal** | Today. Log by name, barcode, description or photograph |
| **Alchemy** | Macro vials, the glycemic reading, Vitality and Toxicity |
| **The Path** | Character sheet: level, streak, Adrenaline, the five Signs |
| **Bestiary** | Every food you have eaten, as a creature with weaknesses |
| **Week's End** | The Reckoning — the reveal, and the week's written account |
| **Settings** | The AI key and its budget, Health Connect, the archive |

Derived stats: **Vitality** (diet quality), **Toxicity** (additives, NOVA-4,
free sugar, sodium, trans fat, alcohol — and it carries between days),
**Stamina** (steps against your own goal), and five **Signs** tied to real
behaviours.

XP is awarded for logging honestly and eating well. **Never for which way the
scale went** — a score that moved with your weight would be the verdict wearing
a hat.

> Harm flags are public food data dressed as game lore.
> **Not medical advice.**

## Stack

Flutter 3.41.6 · drift/SQLite · Riverpod · Open Food Facts (free, no key) ·
Health Connect for step history · OpenRouter free models for meal parsing and
photo recognition.

AI is always the *last* resort behind your own food library, a bundled seed
table and Open Food Facts — every resolution is cached permanently, so a food
costs at most one API call in its lifetime.

---

## Putting it on a phone

```bash
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64
python tools/check_apk_libs.py
```

One APK, at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. **arm64
is the only target** — every phone made in the last several years is arm64, and
this is a personal sideload rather than a Play Store upload. Drop
`--target-platform` to build all three again if a 32-bit device ever needs one.

> `--split-per-abi` is doing real work here and is not redundant with
> `--target-platform`. On its own, `--target-platform android-arm64` stops Dart
> being compiled for the other ABIs but **does not remove them from the APK** —
> plugin `.so` files arrive from AARs regardless, so the file still carries
> `armeabi-v7a` and `x86_64` folders and weighs 41 MB against this command's
> 29 MB. Only the split actually drops them.

**The second command is not optional.** SQLite arrives as a Dart code asset that
is copied into the APK by a step nothing verifies; when that copy is skipped the
build still succeeds and the app dies at its first query with "The Path is
blocked". `check_apk_libs.py` opens the APK and is the only check that catches it
before the phone does. See `CLAUDE.md` §3.

Copy it across and open it. Android will ask you to allow installing from this
source the first time.

> Signed with the debug key, deliberately: this is a sideloaded personal build
> and never goes near the Play Store. It installs and updates fine, but it will
> not upgrade *over* a build signed with a different key — uninstall first if
> you have been running one.

Straight to a connected phone instead:

```bash
flutter run --release
```

### First run

1. **Character creation** — sex, height, weight, activity level, goal, and the
   weekday your week ends on. The last one decides when the seal lifts.
2. **Settings → The archive → Grant file access.** Android asks separately for
   all-files access; without it the backup mirror cannot write. Everything else
   works without it.
3. **Settings → Health Connect** — optional. Install Health Connect from the
   Play Store first if you want step history, including for days you never
   opened the app. Steps can be typed by hand instead.
4. **Settings → The Oracle** — optional. An [OpenRouter](https://openrouter.ai)
   key (free, no card) turns on typed-meal reading, photo reading and the weekly
   account. The free tier gives 50 requests a day, which the app tracks and
   shows. Everything else works without a key.

Then log a meal. Search by name works offline from the first launch — there are
132 seeded foods before you type anything.

## Data durability

Two layers, because Android Auto Backup alone fails silently:

1. **Auto Backup** of the database, preferences and photos — and explicitly
   *not* the keystore holding your API key.
2. **A JSON + Markdown mirror** in `Documents/WitchersDiet/`, outside the app
   sandbox, written whenever the app goes to the background. An uninstall cannot
   touch it, and the app offers to restore from it on first launch.

The Markdown is there to be read: open `Journal.md` on a computer to see what the
backup actually holds. `witchers-diet-backup.json` beside it is the one that
restores — keep them together.

**To move to a new phone:** copy the whole `Documents/WitchersDiet/` folder
across, install the app, grant file access, and take the offer on first launch.

## Development

See [`CLAUDE.md`](CLAUDE.md) for the rules, especially the blackout invariant and
the pinned-toolchain constraints. Design notes live in the Obsidian vault in
[`vault/`](vault/) — open that folder as the vault root in Obsidian, or just
read the Markdown on GitHub. [`00-Index`](vault/00-Index.md) is the way in;
[`90-Progress-Log`](vault/90-Progress-Log.md) is the build history, one entry per
task, with the reasoning.

```bash
flutter analyze && flutter test          # 1017 tests
flutter test --update-goldens --tags golden   # after a deliberate visual change
```

The goldens render real screens to PNGs that are committed and reviewed in the
diff, so a visual regression fails the build without needing a device.
