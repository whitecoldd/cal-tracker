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

## 1.1.1+10 — The Reckoning Remade

- **T42: the meal parser had never worked.** Describing a meal in words failed
  almost every time, and the flow was wrong in three separate places.

### The model chain carried a model that could not answer

`inclusionai/ling-3.0-flash-vl:free` sat second in the chain from the first AI
release. Its only provider does not implement structured outputs, so every
request routed to it returned `HTTP 400 — model features structured outputs not
support`. It spent a request against the daily budget and fell through, every
time, for four releases. It is replaced by `nex-agi/nex-n2.5-mini:free`.

`provider: {require_parameters: true}` now asks OpenRouter's router to skip any
provider that cannot hold the schema, so the same mistake cannot repeat quietly.

### The models were thinking instead of answering

Every free model in the chain reasons by default, and each one spent thousands
of tokens deliberating before writing JSON that the schema had already
described. On one five-food line:

| Model | Thinking | Time | Foods found |
|---|---|---|---|
| pro | on | cut off at 120 s, twice | none |
| pro | **off** | **17 s** | all six |
| mini | on | 60 s | four of six |
| mini | **off** | **4 s** | all six |
| dots-3 | on | 93 s | all six |
| dots-3 | **off** | **11 s** | all six |

`reasoning: {enabled: false}` is now sent on every call. It is the difference
between the feature working and the feature timing out, and it costs nothing —
the reasoning-off answers were the more complete ones.

### The timeout was shorter than the models

45 seconds per model, against models that were taking 60 to 120. Now 90 seconds
per model and 180 for the whole chain, with a model skipped rather than started
when too little of the deadline is left. A short timeout throws away an answer
that was on its way **and** spends the request, because OpenRouter bills the
attempt rather than the result.

### Smaller things the same investigation turned up

- A failed reading now says something a person can act on. It used to print the
  raw exception: `TimeoutException after 0:00:45.000000: Future not completed`.
- The parser is told to pick a unit that suits the food. It was answering "a
  large coke" with *one slice* and a black coffee with *one bowl* — right
  weight, nonsense in the journal.
- A gram figure too small to be the portion it claims is ignored in favour of
  the unit table. A live call returned a chicken shawarma wrap weighing one
  gram, which logs as four kilocalories and looks like a real entry.

## 1.1.0+9 — The Reckoning Remade

**The first MINOR release.** Week's End is a weekly report now, not a page of
energy balance.

### Two readings

- **The Tally** — the week in figures.
- **The Tale** — the week in words.

The week bar and the verdict panel sit above the switch and never move, so a
mode can never hide *whether* the week is sealed.

### What The Tally says

- **The table** — how the week was composed, fibre density, protein per kg,
  whole-food share, glycemic index.
- **The week's curses** — each harm across the week: how many days it passed
  its guideline, the amount, the public figure it is measured against, and
  **which foods carried it**, ranked by the portion actually eaten.
- **Alchemical residue** — the E-numbers themselves, with how many days each
  appeared and which food listed it. The panel this release was asked for.
- **Tendencies** — what the week held and what it carried, at most three of
  each, so a bad week is still credited and a good one is still honest.
- **The days** — each day's composition score, the Signs across the week,
  steps and water.

### Readable before the reveal

Curses, composition, additives and tendencies are readable on any day, because
none of them says which way the scale went. Energy balance, weight, trend,
projection and body fat stay sealed exactly as before.

The open half states **no quantity of energy and no weight** — shares,
densities and counts of days only. A weekly intake figure, read by someone who
knows their own expenditure, is the verdict with the subtraction done in their
head.

### The Tale

Four sections, written once by a model at the seal where there is a key, and
by the app from the same figures where there is not — so the mode is never an
empty panel. Mid-week it gives the descriptive passages and seals the rest.

## 1.0.7+8 — Give the account something to account for

- The weekly narrative now sees what was eaten: composition, curses with the
  food that carried them, the E-numbers, and the week's tendencies.
- It comes back in four named sections instead of one paragraph, so The Tale
  has something to lay out. Still exactly one call per week.
- Accounts written by 1.0.x still read back unchanged.

## 1.0.6+7 — A switch that belongs to this world

- `RunicTabs`: the app's first segmented control, painted rather than
  Material — lit bottom edge, corner brackets on the chosen segment, no
  animation.
- `CurseLine`: the harm row that existed twice byte-for-byte (Alchemy and the
  creature sheet) is now one widget used in three places.
- Both added to the design gallery, as §5 requires.

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
