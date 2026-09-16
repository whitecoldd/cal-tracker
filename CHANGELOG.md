# Changelog

All notable changes to The Witcher's Diet.

## Versioning

`MAJOR.MINOR.PATCH+BUILD`, and `pubspec.yaml` holds the whole string.

| Part | Moves when | Example |
|---|---|---|
| **PATCH** | every commit | `1.0.0` → `1.0.1` |
| **MINOR** | a large change — a new mechanic, screen or data source, a schema migration, anything that changes what the app *is* for a day | `1.0.1` → `1.1.0` |
| **MAJOR** | a total makeover or remaster: the design language replaced, the seal reworked, the data model rebuilt from nothing | `1.4.2` → `2.0.0` |
| **BUILD** | +1 on every version change, never reused, never decreasing — Play refuses a `versionCode` it has already accepted | `+7` → `+8` |

Bumping a higher part resets the lower ones: after `1.1.0` the next commit is
`1.1.1`, not `1.0.2`. The build number does not reset, ever.

Three places must agree, and `test/version_test.dart` fails the build if they
do not: `pubspec.yaml`, [`lib/version.dart`](lib/version.dart), and the newest
entry here. Each release gets one section, newest first, and each commit adds
its line to it.

---

## 1.0.5+6 — The week, live

- `weekPatternProvider` and `weekFindingsProvider`: the descriptive half read
  straight from the journal, for any week, on any day — including weeks that
  sealed long before this existed.
- `TrackingDao.waterInRange`, and an adapter that carries the food's name and
  day into the domain without `domain/` ever learning that drift exists.

## 1.0.4+5 — The tale the app can tell itself

- `domain/weekly_tale.dart`: the week as prose, in titled sections. Written by
  a model at the seal where there is a key, and by the app from the same
  figures where there is not — so The Tale is never an empty panel.
- Accounts stored by 1.0.x as a plain paragraph still read back, so the richer
  account needs no migration and no new column.

## 1.0.3+4 — Tendencies, goods and bads

- `domain/week_findings.dart`: twenty-one statements a week can support, in
  two tones. Warnings carry the public guideline they rest on; boons are read
  out even in a bad week, because a report that only accuses is not a report.
- Capped at three per tone, so one tone can never take every slot.
- Still nothing user-visible.

## 1.0.2+3 — Read the week without opening the seal

- `domain/week_pattern.dart`: the descriptive half of a week — curses folded
  per day, distinct additives with the foods that listed them, composition,
  fibre density, clean days, best and worst day, movement and Signs.
- Nothing user-visible yet. The type deliberately has **no** field for an
  energy balance, an expenditure or a weight, so the screens that will read it
  cannot render a verdict from it.

## 1.0.1+2 — Name what the count hides

- **Additives are named, not just counted.** A food's E-numbers were stored all
  along and thrown away at the edge of the domain; a creature's entry now lists
  them instead of reporting a bare "7 listed".
- **Fixed: additives were double-counted.** The day's total summed each
  serving's additives rather than taking the distinct set, so a day that
  repeated one packaged food read as though it had eaten two — and Toxicity
  read high accordingly. Already-sealed weeks are untouched: a sealed week is
  never recomputed.

## 1.0.0+1 — First Contract

*2026-09-16.* First stable release. Everything below shipped across T0–T32 and
is considered done rather than in progress.

### The seal

- The verdict — energy balance, weight delta, trend, projection, body
  composition — is a `SealedValue<T>` from the domain to the widget, so no
  screen can render it before the week's end day the user chose.
- Weight is logged daily; only its interpretation is sealed.
- The one AI narrative runs on the reveal day alone, and its facts type cannot
  be built from a week that has not closed.

### Logging

- Foods by name, barcode, free text, photograph or typed nutrition table.
- Resolution order: the user's own library, the bundled seed table, Open Food
  Facts, then AI — and every AI answer is written back, so a food costs at most
  one call ever.
- A barcode Open Food Facts has never held can be read off the packet, written
  by hand, and handed back to the ledger as a transcript to paste.
- Water, portions by hand or by guess, and the photograph the app took is kept
  with the meal.

### The game

- Journal, Alchemy, The Path, Bestiary, Week's End.
- Vitality, Toxicity, glycemic load, the five Signs, Adrenaline.
- XP, levels, ranks and spendable mutagens — awarded for logging honestly and
  eating well, never for which way the scale went.

### The platform

- Drift on SQLite, all on device, no server and no account.
- Health Connect for steps and distance, with hand entry as the fallback.
- Backup to a chosen folder, and a mirror the user can read.
- OpenRouter key in the Android keystore, entered in-app, never in the APK.
- Works fully with no key and no network.
- The version is shown at the foot of Settings, and this changelog, the
  pubspec and `lib/version.dart` are held together by `test/version_test.dart`
  so they cannot drift apart unnoticed.
