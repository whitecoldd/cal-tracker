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
