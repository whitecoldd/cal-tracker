---
tags: [log]
---

# Progress Log

One entry per shipped task. Newest at the bottom.

---

## T0 — Scaffold, rules, vault
**Date:** 2026-09-14

Created the Flutter project in place at `C:\dev\cal-tracker` (`cal_tracker`,
org `com.whitecoldd`, platforms android + web).

**Dependency resolution was the interesting part.** Two upstream problems surfaced:

1. `sqlite3_flutter_libs` is **end-of-life** — as of 0.6.0 it is an empty stub.
   `package:sqlite3` 3.x now builds the native library itself via native assets.
   Dropped it entirely.
2. Flutter 3.41.6 pins `meta` to 1.17.0 → caps `analyzer` → caps `drift_dev` at
   **2.34.x**, which cannot be used with `drift` ≥ 2.35.0. Held both at
   `>=2.34.0 <2.35.0`. Same root cause blocks `flutter_riverpod` ≥ 3.4.1
   (needs Dart 3.12), so Riverpod stays on the mature 2.6.1 line rather than
   pinning to an early 3.0.0.

Upgrading the Flutter SDK would clear all of this, but that toolchain is shared
with the user's other projects, so it is their call. Recorded in [[02-Architecture]].

3. `permission_handler` 14.1.0's Android module **does not compile** against this
   project's Gradle 8.14 / KGP 2.2.20 — its build script uses the
   `kotlin { compilerOptions { } }` DSL and trips `srcDirs` deprecation-as-error.
   Removed it. Verified by a clean `flutter build apk --debug` afterwards: it was
   the only blocker, and all nine remaining plugins build.
   `MANAGE_EXTERNAL_STORAGE` will instead be requested by a small platform
   channel in MainActivity (T13). See [[02-Architecture]].

**Also in this task:**
- `CLAUDE.md` with the blackout invariant written as the first rule
- Stricter `analysis_options.yaml`; `non_exhaustive_switch_*` promoted to **error**
  so the `SealedValue` switches can never silently lose a branch
- Bundled Cinzel + EB Garamond (OFL variable fonts) for offline use
- Android: `minSdk 26` (Health Connect floor), `FlutterFragmentActivity`,
  Health Connect permissions + rationale intents, camera, storage-mirror
  permission, Auto Backup rules (excluding the secure-storage keystore),
  core library desugaring, R8 + resource shrinking on release
- This vault (then a separate folder outside the repo; moved to `vault/`
  in the side task below)

**Verified:** `flutter analyze` clean, `flutter test` green,
`flutter build apk --debug` succeeds.

> [!note] Lesson
> Building the APK at T0 rather than assuming the plugin set works caught the
> `permission_handler` failure before any feature code depended on it. Keep doing
> a real Android build at each task that adds a plugin.


---

## T1 — Witcher design system
**Date:** 2026-09-14

Tokens, typography, and the ornate primitives everything else will be built from.
See [[03-Game-Design]] for the vocabulary these encode.

**Primitives:** `OrnatePanel` (corner brackets, tintable frame), `RunicDivider`,
`StatBar` (segmented HUD meter), `AlchemyVial` (macro flask that visibly
over-fills), `SealedNode`, `SignGlyph`, `WitcherButton` (bevelled, no pills),
`FoodCard` (Gwent-style, rarity strip + cost gem).

**`SealedValue<T>` landed here rather than in T7.** The type is tiny and it is
the app's spine, so it belongs next to its visual treatment; T7 builds
`RevealGate` and the providers on top of it.

**Rendered the gallery to a golden PNG and actually looked at it.** That caught
three things no test would have:

1. The sealed node was broken — the chain ran diagonally straight through the
   label and flavour text, making both unreadable. Rewritten: the chain is now
   confined to its own 40px band with a wax-seal medallion set into the middle,
   and the band shares a height with the revealed numeral so unsealing does not
   make the panel jump.
2. Two runes did not read. Igni was an arrow, Axii looked like the digit **5**.
   Igni is now a proper two-tongued flame; Axii is an Archimedean spiral.
3. `Hue.bloodRed` as header text on the panel fill was unreadable. `OrnatePanel`
   now lifts any accent below 0.12 luminance towards parchment for the title
   only, keeping the frame at full strength.

Also: the food card's toxicity strip was bright green spanning most of the card,
which reads as a *success* bar. It now lerps green → blood red with severity, so
a mostly-full strip can never be misread.

> [!note] Lesson
> `Ink` collides with Flutter's Material `Ink` widget — the token class is
> `Hue`. And a design system that has never been rendered is a guess: the golden
> is worth keeping in the normal test suite.

**Verified:** `flutter analyze` clean, 13 tests green (including the golden and
an assertion that a sealed node renders no digit anywhere in its widget tree).


---

## T2 — Data layer
**Date:** 2026-09-14

Drift schema, five DAOs, a 132-food seed table, and 55 tests. Schema detail in
[[04-Data-Model]].

**Days are `yyyymmdd` integers, not `DateTime`.** A timezone shift moving a log
across midnight would move it into a different *week*, which would corrupt the
one number the product exists to produce. `Day` is a value type with a drift
`TypeConverter`, and all week arithmetic lives on it. `Day.today()` reads
`clock.now()`, so tests freeze the calendar.

The week-end day closes its *own* week rather than opening the next — otherwise
the Sunday reveal would describe the week that has only just started. There is a
test for every weekday, plus year-boundary and leap-day cases.

**Three real bugs caught by writing the tests, not by review:**

1. **`day` was optional in every generated insert.** SQLite treats a lone
   `INTEGER PRIMARY KEY` as an alias for rowid, so drift made it optional — a
   row written without a day would have been silently assigned one (day 1 =
   year 0). Fixed by marking the four day-keyed tables `WITHOUT ROWID`, which is
   both correct and a better fit for lookup tables. `day` is now `required`.
2. **Re-running the seed loader duplicated the entire food table.**
   `InsertMode.insertOrIgnore` only ignores on a constraint conflict, and the
   only unique key is `barcode` — which is NULL for every seed food, and SQLite
   does not treat two NULLs as conflicting. Replaced with an explicit
   search-key check (`insertMissing`), so a grown seed file adds only what is
   new and a user's corrections always survive.
3. **`upsert` trusted the caller's `searchKey`.** A caller that normalised it
   differently silently created a duplicate. It now recomputes the key itself.
   Also made the barcode lookup fall back to the name key, so scanning a
   barcode enriches a food already in the library instead of sitting beside it.

**The source-precedence rule** is the interesting one: `manual` > `openFoodFacts`
> `seed` > `ai`. A worse source may never overwrite a better one, so a background
Open Food Facts refresh cannot discard a correction typed by hand. See
[[05-AI-Layer]] for why the cache matters so much.

**Seed table:** 132 generic whole foods, generated from a compact table in
`tools/gen_seed.py` so the values stay auditable. Both the generator and a test
validate the shipped asset for the mistakes hand-typed nutrition data actually
makes — macros that do not add up to the stated energy, sugar exceeding total
carbohydrate, a GI attached to a food with no carbohydrate.

> [!note] Lesson
> `flutter analyze` passed while the app could not compile: the generated part
> file referenced `Day`, and `database.dart` had only imported `tables.dart`.
> Part files see their library's imports, not transitive ones. Run the tests,
> not just the analyzer.

**Verified:** `flutter analyze` clean, 67 tests green, APK builds.


---

## T3 — Profile and character creation
**Date:** 2026-09-14

The energy model, the profile, and a five-page onboarding flow. 43 new tests.

**The interesting problem was double counting.** An activity multiplier and a
step counter both estimate the same movement, so the usual
`BMR x multiplier + step energy` quietly inflates expenditure — and an inflated
maintenance makes a deficit look real when it is not, which is exactly the lie
this app exists to avoid.

The model instead treats them as two separate paths that never mix:

- **Measured** (preferred): `BMR x 1.2 + walking`, where walking bills only the
  steps above the ~3,000 already inside the 1.2 sedentary multiplier.
- **Estimated** (fallback, no step data): `BMR x activityLevel.multiplier`.

Health Connect's reported active energy, when present, *replaces* the walking
estimate rather than adding to it — it already includes walking. Every one of
these rules has a test asserting the sum is **not** what the naive version would
produce.

Also: `ActivityLevel.hearthbound` is exactly 1.2, so a sedentary user gets the
same answer whether or not their steps happened to sync that day. And
`dailyTarget` is floored at 1,200 kcal — an aggressive deficit on a small
maintenance would otherwise send the arithmetic somewhere no app should.

**`Sex.unspecified` uses the midpoint of the two Mifflin-St Jeor constants.**
The formula only offers two, so the app says so in the UI rather than quietly
picking one.

**Maintenance is shown at setup and in Settings, never on the daily screens.**
Knowing your maintenance is knowing your body; seeing it printed beside today's
intake is being handed the verdict. Recorded in [[02-Architecture]].

**Two real layout bugs, both caught by widget tests at phone width:**
"BEGIN THE PATH" overflowed beside the Back button, and "DAILY TARGET"
overflowed its summary row. Same root cause — engraved labels carry 2.2px letter
spacing, which makes them much wider than they look. `WitcherButton` and every
`spaceBetween` label row now let the label tighten before the layout breaks.
Added phone-width goldens for all five pages so this class of bug shows up as a
picture rather than a crash.

**`Patch<T>` replaced an `Object?` sentinel in `copyWith`.** The sentinel let
`targetWeightKg: 74` compile and then fail at runtime on the cast to `double?`.
A typed wrapper keeps "leave alone" and "set to null" distinguishable *and*
keeps the field's type.

> [!warning] Recurring trap, now in CLAUDE.md
> `flutter analyze` passed again on code that could not compile — the generated
> part file referenced the new `Sex`/`ActivityLevel`/`Goal` enums, which
> `database.dart` had not imported. Second time this exact thing has happened.
> Every domain type used in a column must be imported in `database.dart`, not
> just in `tables.dart`.

**Verified:** `flutter analyze` clean, 110 tests green, APK builds.


---

## T4 — Manual food logging
**Date:** 2026-09-14

The Journal, portion resolution, local search, and edit/delete. 34 new tests,
144 in total.

**Portions are allowed to be vague, and say so.** People eat "a handful of
almonds", not "28 grams of almonds", and demanding precision at the moment of
logging is how food diaries get abandoned. So every unit resolves to grams and
carries a confidence: `g`/`ml` are exact, a piece resolves through the food's
own piece weight at 0.95 when it has one, a tablespoon is 0.85, a handful 0.5, a
plate 0.4. The Journal marks low-confidence entries so they can be corrected,
and `worthRefining` is the hook T8 will use to decide whether an AI call could
actually improve an entry.

`describePortion` reads the portion back in the user's own words — "2 eggs", not
"100 g" — because seeing your own phrasing is what makes a wrong entry obvious.

**The Journal shows no target, no remainder, no ring.** `DailyTotals` carries
absolute figures only, and there is a widget test that scrapes every `Text` on
the screen and fails if it contains *remaining, target, goal, deficit, surplus,
maintenance, tdee, losing, gaining, burned, balance* — or even a `/`, which
would imply progress framing. See [[01-Vision]].

**Two testing traps, both now in CLAUDE.md:**

1. **An awaited drift query inside `testWidgets` never completes.** The body runs
   in fake async, which never turns the real event loop, so the test just hangs
   until timeout with no useful error — four minutes of nothing. Database work in
   a widget test has to go through `tester.runAsync`. While chasing it I also
   changed `JournalDao.forDay` from `watchDay(day).first` to a plain query:
   there was never a reason to build and tear down a stream for a single read.
2. **Handing a widget a live drift stream leaks a timer.** Drift schedules a
   zero-duration timer when a query stream is cancelled, and the binding reports
   it as a leak. Widget tests now get a settled snapshot via
   `journalEntriesProvider.overrideWith((ref) => Stream.value(items))`; the DAO
   tests cover the querying.

Also: killing a `flutter test` mid-run left a half-copied `sqlite3.dll` in
`build/native_assets/`, and the next run died with a `PathExistsException`
rather than anything legible. Noted in CLAUDE.md with the fix.

**Verified:** `flutter analyze` clean, 144 tests green, APK builds, Journal
golden rendered and inspected at phone width.

---

## Side task — Move the vault into the repo
**Date:** 2026-09-14

Moved `C:\dev\cal-tracker-vault\cal-tracker\` to `cal-tracker/vault/` and
committed it. `C:\dev\cal-tracker-vault\` is gone.

**Why: the one-task-one-commit rule was unenforceable across two repos.**
Every task is supposed to land its code and its progress-log entry in the
same commit, but the log lived in a folder git could not see. In practice
that made the log a thing you update *afterwards*, which is exactly how
build journals rot. Now a task that forgets its entry shows up as an
incomplete commit. It also means the design notes travel with a clone, and
the reasoning behind a decision is readable in the same diff as the
decision.

Against it: the vault is now public, since the repo is. Nothing in these
notes is sensitive — no key, no body data, only design reasoning — so this
is fine, but it is now a standing constraint. **Personal measurements and
anything resembling a credential do not go in the vault.**

`.obsidian/` is committed, so the accent colour, theme and enabled plugin
set follow the repo. `vault/.obsidian/workspace*.json` is gitignored — it is
per-machine pane layout and would otherwise dirty the tree on every session.
`vault/attachments/` keeps a `.gitkeep` so the path configured in
`.obsidian/app.json` exists in a fresh clone.

Docs updated for the new location: `CLAUDE.md` §2 and §6, `README.md`,
[[00-Index]], and [[02-Architecture]] which gained a repository-layout
section.

> [!note] Wikilinks do not leave the vault
> Obsidian resolves `[[...]]` only within `vault/`. Notes that want to point
> at source must use a relative path like `../lib/domain/portion.dart`.

**Verified:** `flutter analyze` clean, 144 tests green — no source changed,
but the rule in §2 is the rule.

---

## T5 — Open Food Facts and barcodes
**Date:** 2026-09-15

Step three of the resolution order: a keyless Open Food Facts client, barcode
scanning, and the write-back that keeps a food from ever costing a second
lookup. 34 new tests, 178 in total. Detail in [[02-Architecture]].

**`RemoteFood` is a different type from `Food`, and that is the design.** A
`Food` has a row id and can be logged; a `RemoteFood` has none and cannot,
because an entry referencing it would point at a row that does not exist. The
only way across is `toCompanion()` plus a write to `foods` — which *is* the
write-back the budget rule requires. I could have mapped straight to `Food`
with a placeholder id and saved a file; that version has a path where an
upstream result is shown, tapped, logged, and never persisted, and nothing but
care would prevent it. Same move as `SealedValue`: make the wrong thing
unwriteable rather than merely discouraged.

**The mapper is pure, and that is where the bodies are buried.** Open Food
Facts is crowd-sourced, so the interesting behaviour is entirely in fallbacks
and unit conversions — and a live test would pin down none of it. Three
conversions that would each have been a silent, plausible-looking bug:

1. **Sodium is grams upstream, milligrams in our column.** A 1000x error that
   looks like a perfectly ordinary number.
2. **Alcohol is % by volume, not grams.** 5% lager is 3.9 g/100ml, not 5.
3. **Energy is often only kJ.** 1046 kJ silently becoming 1046 kcal is a
   four-fold overcount of a slice of bread.

Plus the salt fallback — many products carry `salt` and no `sodium`, and salt is
sodium x 2.5.

**A product with no energy is rejected rather than mapped to zero.** Open Food
Facts holds a great many entries that are barely more than a barcode and a
photo. Offering one would let someone log their lunch, see it appear in the
Journal, and add nothing to the day's total. A missing food is obvious; a food
that reads 0 kcal is a lie the user cannot see. Same for a product with no name.

`addedSugar` and `transFat` stay null when absent instead of defaulting to zero.
"No added sugar" and "nobody filled this field in" are different claims, and T6's
harm model needs to tell them apart — a defaulted zero would quietly exonerate
every product with a thin record.

**Confidence is computed from completeness**, 0.6 for energy-only up to 0.95 for
a full panel, because that number is what decides whether a better source may
later overwrite the row. A flat "it came from Open Food Facts" would let a
one-field record outrank nothing and block nothing.

**Failure is a footnote, not an error state.** Timeout, socket error, upstream
throttling and malformed JSON all funnel into one `RemoteUnavailable`, and the
search sheet renders it as a grey line under the local results. The app is
required to stay fully usable with no network, and the honest way to express
that is that the wider world is a bonus row, not a dependency. Local results
paint immediately and are never blocked on the network — merging the two lists
would have made every search as slow as the slowest one.

**A scanned barcode checks the library first.** Not an optimisation: a barcode
the user has scanned and then corrected by hand must resolve to their
correction, not to whatever Open Food Facts says this week. There is a test that
asserts the network is not touched at all in that case, because the guarantee is
about the call count and no amount of checking the returned data would prove it.

Scanner is restricted to EAN-13/8 and UPC-A/E — the formats actually printed on
food packaging — so it cannot lock onto a QR code on the same label. It returns
a `String?` and knows nothing about the food library; the caller owns the
resolution order.

**Both lookup providers are `autoDispose`.** The first version was not, and
carried a `ref.keepAlive()` with a comment about holding results for the life of
the sheet. Riverpod's own docs say plainly that `keepAlive()` **has no effect on
a provider that is not auto-dispose** — so the call was dead code and the
comment described behaviour that was not happening. What *was* happening: a
`.family` keyed by query string, never disposed, caching every distinct string
ever typed for the life of the app. For `barcodeLookupProvider` the stale cache
would have been worse than a leak — it would survive a later hand-correction of
that food and keep returning the row the user had replaced.

> [!note] Two lessons, same shape
> 1. The analyzer passed on `saveRemoteFood(Ref ref, ...)` being called with a
>    `WidgetRef`. It did not — that was the compiler, on the next run. In
>    Riverpod 2.x `WidgetRef` is not a `Ref`. CLAUDE.md §2 is right that the
>    analyzer is not sufficient on its own; this is the third time.
> 2. A no-op call with a confident comment is worse than no call, because the
>    comment is what gets believed on the next read. Check that a lifecycle API
>    applies to the provider kind you actually used.

**Verified:** `flutter analyze` clean, 178 tests green,
`flutter build apk --debug` succeeds — the first task to actually use
`mobile_scanner`, and given this project's history with plugin builds, worth
the minutes.

**Not done here:** no golden for the search sheet's remote section. It renders
network state, and a golden that needs a stubbed async frame to be stable is a
flaky test wearing a useful disguise. The Journal golden still covers the card.

---

## T6 — Alchemy and the scoring engine
**Date:** 2026-09-15

The nutrition engine, the harm model, Vitality, Toxicity, rarity, and the
Alchemy screen they feed. 75 new tests, 253 in total. Detail in
[[02-Architecture]] and [[03-Game-Design]].

**The whole task turned on one question: what can a macro vial fill against?**
A vial needs a reference, and the obvious reference — a macro target split out
of the TDEE-derived calorie goal — is exactly the thing the app must not show.
Sum the gaps between intake and a TDEE-derived target and you have the day's
deficit; the daily screen would answer "am I losing weight?" by subtraction,
whatever the label said.

So carbohydrate and fat fill against their share of the day's **own** energy,
inside the published AMDR bands. The vial says how the day was *composed*,
never whether there was enough of it, and no arrangement of the numbers can be
solved back into an energy balance. Protein additionally carries a g/kg
adequacy mark and fibre a flat 30 g — both energy-independent. Body mass is
legitimate here because weight is logged and shown every day; only its
interpretation is sealed.

`AlchemyVial` had to grow `valueLabel`/`captionLabel` for this. Its built-in
second line is "of {target}", which is precisely the framing §1 forbids — and
with a share passed in, it rendered "0 of 0".

**An unlogged day scores zero Vitality, not full marks.** The trap the scoring
is arranged around, and worth stating plainly: a day with nothing logged has no
sugar, no sodium and no ultra-processed food, so every restraint component
reads perfect. Score it naively and *not logging* becomes the highest-scoring
strategy in the app. The one thing this app asks of the user is that they log
honestly; the scoring must not quietly punish them for doing it.

**Toxicity carries 55% of yesterday forward.** A half-life of a little over a
day. Less and an indulgent evening is erased by the calendar turning over six
hours later; more and it haunts a week and the meter stops responding to food.
History folds over a 7-day window — beyond that the retained fraction is under
a percent, which the meter cannot show anyway.

The day's load caps each reading at **twice** its guideline. Without a cap, one
catastrophic figure saturates the meter alone and hides everything else; without
letting severity exceed 1.0 at all, three times the sodium guideline reads the
same as reaching it. Both were wrong in different directions.

**Unknown is not zero, in three places.** Free sugars and trans fat stay null
when absent, because "no added sugar" and "nobody filled this in" are different
claims and a defaulted zero exonerates every thin record. An unknown NOVA group
counts as neither whole nor ultra-processed. Average GI is weighted only over
foods that carried an index — averaging across all carbohydrate would treat
unknown as zero and invent a low-GI day out of missing data.

`LoggedItem` keeps its own per-item getters because the Journal shows each
row's kcal, so the same multiplication now exists in two places. Rather than
force a circular import to collapse them, there is a test asserting the two
agree — if one is ever changed without the other, a row and its own total
would silently disagree.

**Rarity moved into `domain/`.** It was an enum in the widget layer carrying a
colour, with the ranking rule copy-pasted at each call site — which is how the
same food could read Epic in one list and Common in another. `FoodRarity` now
carries a name, the theme maps it to a colour, and there is exactly one
`rankFood`. `DailyTotals` likewise became a thin wrapper over the domain
rollup rather than a second implementation of the same arithmetic.

**The golden earned its keep again.** Rendering the screen and actually looking
at it caught three things no test asserted:

1. The Curses titles were steel on void and came out *dimmer than their own
   detail text*, inverting the hierarchy — the name of the curse has to lead.
   Not blood red either; T1 already found that unreadable as text on this
   ground. They are parchment now, red only past the guideline.
2. "SWEET ROT — 1 g — 0% of energy" was listed as a curse. Almost every real
   food carries a trace of something, so `isNotable` now needs a twentieth of
   the guideline rather than merely non-zero.
3. The macro lines wrapped to two lines and centred against a one-line label,
   which read as broken alignment. Fixed columns.

> [!note] Two testing lessons
> 1. **The widget test hung, exactly as CLAUDE.md §2 warns.** `toxicityProvider`
>    and `latestWeightProvider` each await a drift query of their own, and a
>    `testWidgets` body runs in fake async that never turns the real event
>    loop — so `pumpAndSettle` spun for its full ten-minute timeout with no
>    useful error. Overriding both with settled values fixed it. `runAsync`
>    around the *setup* is not enough; anything the widget tree itself awaits
>    has to be handed a value too.
> 2. **A text-scraping blackout test must force the whole page into the tree.**
>    The screen is a lazy `ListView`, so at phone height the lower panels are
>    never built and the scrape passes by simply not looking at the half of the
>    screen most likely to leak. The test now renders at 1080x7200. Raising it
>    immediately caught two real `RenderFlex` overflows at 360 logical px.

**Reachability:** an app-bar action on the Journal pushes Alchemy. A real
navigation shell belongs with T12, when there are more screens than two to put
in it.

**Verified:** `flutter analyze` clean, 253 tests green, goldens regenerated and
inspected, `flutter build apk --debug` succeeds.

---

## T7 — RevealGate and the sealed verdict
**Date:** 2026-09-15

The gate, the week's verdict, the Reckoning screen, and the tests that prove
nothing leaks Monday to Saturday. 158 new tests, 411 in total. Detail in
[[02-Architecture]].

`SealedValue<T>` landed back in T1 next to its visual treatment. T7 is
everything that decides *when* it opens.

**The gate takes a callback, not a value.**

```dart
SealedValue<T> gate<T>(Day subject, {required Day today, required T Function() compute})
```

This is the one design decision the task turned on. Wrapping an
already-computed number in `Sealed` would leave it sitting in memory —
reachable by a log line, a `toString`, a crash report, or a future refactor
that reaches past the type. With a callback, a sealed verdict is **never
calculated at all**. The seal is not a curtain drawn over an answer; there is
no answer yet. There is a test that counts invocations and asserts zero.

**Two ways to be readable, and only two:** the week has closed (history is not
the verdict, and refusing it would make the app useless as a record), or today
is the day that closes the week the value belongs to. The live week on any
other day, and any future week, are sealed.

**`loggedDays` and `daysUntilReveal` are deliberately *not* sealed.** Neither
says anything about gaining or losing. `loggedDays` is the figure that tells
the user how much the sealed ones will be worth — a verdict drawn from two
logged days deserves suspicion — and `daysUntilReveal` is what makes a seal
read as deliberate rather than broken. A blackout that cannot say when it lifts
is indistinguishable from a bug.

**Judgements inside the verdict**, each of which could have gone the lazy way:

- The average balance is per *logged* day. Dividing a four-day week by seven
  would report a deficit the user never ran; an unlogged day is unknown, not
  fasted.
- A weight move under 0.3 kg reads as `holding`. Swings of a kilogram from
  water and gut contents are ordinary, and calling 0.2 kg a trend is exactly
  the reflex this app exists to break.
- Energy balance rounds to 10 kcal, because it carries the error of a BMR
  estimate, a step count and a hundred portion guesses.
- Past ±2 kg a week nothing is credible — that is a mis-typed portion, and a
  confident "you gained 4 kg" is worse than silence.

**`RevealGate` needed value equality.** It is rebuilt whenever the profile
stream emits, and without `==` every rebuild yields an instance Riverpod
treats as different, invalidating everything watching it. Found while chasing
the hang below; it was not the cause, but it was a real bug.

> [!note] The hang, and what it actually was
> `reckoning_provider_test.dart` hung on every test. The obvious suspect was
> the fake-async trap in §2, but this was a plain `test`, not `testWidgets` —
> the event loop was real. Bisecting with throwaway probe providers narrowed it
> to a combination: a `FutureProvider` watching **two** live drift streams.
>
> The cause is that `.future` re-chains when a pending provider is invalidated.
> Each stream's first emission invalidated the reckoning mid-flight, and the
> read never settled. **In the app this is invisible** — the UI just rebuilds,
> which is the behaviour we want when food is logged. It only bites a test that
> awaits `.future`. The fix is to let each stream deliver before the provider
> is first built.
>
> Lesson: when a provider test hangs, check whether the provider is being
> invalidated rather than assuming the query is stuck. Awaiting `.future` on
> something with live dependencies is a race, not a read.

**Testing is split by what actually needs a database.** The screen renders a
`Reckoning`, and a `Reckoning` is pure — so the widget tests build one with
`reckon()` directly and never touch drift. That took the screen suite from
6m35s of timeouts to 4 seconds, and lost no coverage: the provider that
assembles one from the database has its own suite, off the widget binding
where the event loop is real.

**The goldens earned their keep twice more.** Rendering the revealed state
showed "-3850" with no unit beside "-0.90 KG", which is ambiguous. Adding
`kcal` then *wrapped and clipped*, because the sealed and revealed states share
a fixed band height so unsealing does not make the panel jump. Fixed in the
primitive: `SealedNode` now scales a long numeral down rather than wrapping it.
Neither problem would have failed a test.

The sealed golden is the one worth keeping an eye on. Four chained wax seals,
their lore, and a countdown — it should read as something locked and waiting,
never as a screen that failed to load.

**Reachability:** a second app-bar action on the Journal. T11 builds this out
into the full Week's End with charts, the level-up and the one AI narrative;
T7 is the gate and the seal.

**Verified:** `flutter analyze` clean, 411 tests green, goldens regenerated and
inspected, `flutter build apk --debug` succeeds.
