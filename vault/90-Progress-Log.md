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

---

## T8 — The OpenRouter client
**Date:** 2026-09-15

Secure key storage, the model fallback chain, strict JSON schemas, the budget
counter, and the write-back. Two of the four permitted uses are live: free-text
meal parsing and vague-portion estimation. 82 new tests, 493 in total. Detail in
[[05-AI-Layer]].

**The prompts are pure functions, so the rules can be tested rather than
intended.** There is a test asserting no daily prompt contains `tdee`,
`deficit`, `surplus`, `weight trend`, `bmr` — or even `kg`. A model cannot leak
a figure it was never told, and that is a far stronger guarantee than asking it
politely not to.

Then a second test asserts the same thing **on the wire**: it serialises every
request the fake adapter saw and scans that. A clean prompt builder with a call
site that appends body data would pass the first and fail the second. The
blackout is worth two tests.

**Every system prompt carries the "never diagnose" clause**, from one shared
preamble — so a fifth use cannot be added without it. §7 says harm is lore
rather than medicine; this is where that reaches the model.

**One call per meal, not per food.** "two eggs, a slice of rye and a coffee" is
a single request however many foods it names. That is the whole reason this is
affordable at fifty a day.

**The resolution order is applied to the model's own output.** A parsed item is
looked up locally first; if the library has it, the model's nutrients are
*discarded* and only its reading of the name and portion survive. If not, the
food is stored with `FoodSource.ai` — the weakest source — so a later barcode
scan or hand correction may overwrite it.

Matching is by exact search key, not the `LIKE` search the picker uses. Fuzzy
is right in a search box where the user is looking at the results; here nothing
would notice "rye bread" quietly resolving to "rye bread crackers" and the meal
being logged against the wrong food.

**Open Food Facts is skipped on this path, deliberately.** It is a brand and
barcode database; a typed meal is almost all generic foods, which the seed
table covers. A search per item would add a round trip each for answers usually
worse than the seed's.

**The device beats the model on portions.** A known piece weight resolves "2
eggs" more reliably than a language model, and the unit table from T4 exists
for exactly this. The model's gram figure is used only when nothing better is
available, and then capped below the exact units' confidence.

**Decoding is distrustful on purpose.** The schema is strict, but a model can
return a number where the schema says number and have it be nonsense. Energy
clamps at 900 kcal/100 g, which is pure fat. A NOVA group outside 1–4 is
*dropped* rather than clamped — clamping would assert a processing level the
model never claimed. A missing confidence reads as 0.5, not as certainty. A
portion estimate is capped at 0.85 whatever the model says, because nobody
weighed it and an estimate presenting itself as exact invites the user to stop
correcting it.

Two leniencies, both because a decode failure costs a call: a fenced ```json
block is unwrapped, and a numeric string is accepted for a number field. Past
that a malformed reply is a failure and the chain moves on.

**The key is never rendered again.** Not even masked with a few characters
showing: there is nothing to check by eye, and every rendering is a chance to
put a credential in a screenshot. Validation is a shape check rather than a
network check — asking OpenRouter whether the key works would spend one of
fifty daily requests to learn what a prefix reveals.

> [!note] A fake that lied
> `InMemoryAiKeyStore` returned `''` for a blank key while `SecureAiKeyStore`
> returned `null`. Both implement the same interface, and `hasKey` is
> `read() != null` — so the fake reported a key present where the device would
> report none. Caught by a test that was only meant to check trimming. A test
> double that does not hold the real contract is worse than no double: it
> passes on behaviour the phone does not have.

**Verified:** `flutter analyze` clean, 493 tests green, goldens regenerated and
inspected, `flutter build apk --debug` succeeds. No test in the suite reaches
OpenRouter — the client is driven through a fake Dio adapter, because a real
call would need a real key and would spend one of fifty daily requests per run.

**Not done here:** photo→items (T9) and the weekly narrative (T11), the other
two permitted uses. The prompt and schema for the narrative are written, since
they belong with their siblings, but nothing calls them yet.

---

## T9 — Vision
**Date:** 2026-09-15

Photograph a plate, get items. Three of the four permitted AI uses are now
live; only the weekly narrative is left. 22 new tests, 515 in total. Detail in
[[05-AI-Layer]].

**It reuses T8 almost entirely.** `parsePhoto` differs from `parseMeal` only in
the shape of the message content — a list of text and image parts rather than a
string — so the model chain, the budget check, the recording, the schema and
the write-back are all shared rather than written twice. The one change to the
client was widening `user` from `String` to `Object`.

A photograph is **one request however many foods are on the plate**, the same
bargain that makes the typed path affordable at fifty a day.

**The picture is shrunk to a 1024 px long edge at quality 70.** A phone camera
produces twelve megapixels and 3–4 MB; a vision model charges for that by the
tile. A plate of food is not a document, so nothing is lost — a real meal lands
around 100–200 KB.

> [!warning] `keepExif: false` is a privacy decision, not an inherited default
> It happens to be the plugin's default, and it is set explicitly anyway. A
> camera photo carries EXIF and EXIF carries GPS. This app keeps everything on
> the device; sending the location of the user's kitchen to a third party along
> with a picture of dinner would quietly undo that. Written out with the reason
> so nobody later removes it as redundant.

The size cap is enforced **after** compression rather than before, so a
compressor that misbehaves cannot push a huge upload through. There is a test
for that specifically — it was the one thing about the ordering that was easy
to get backwards.

**The prompt guards against invented food, not misidentified food.** Getting a
food wrong is visible and correctable at the confirm step. *Inventing* one is
not: a model that infers a side dish out of frame adds a plausible extra line
that the user is unlikely to question. So the prompt says to name only what is
visible, to put anything seen-but-unidentifiable into `unrecognised` in plain
words, and to return no items at all if the picture is not food.

**`MealConfirm` was extracted rather than copied.** The typed sheet had it
inline; the photo sheet needed the same thing. It is the only step standing
between a model's mistake and the day's totals, and two copies would
eventually disagree about what they show.

The photo prompts go through the same blackout scrape as every other daily
prompt — no `tdee`, `deficit`, `bmr`, not even `kg` — and the same
wire-level assertion on the serialised request.

**Verified:** `flutter analyze` clean, 515 tests green, `flutter build apk
--debug` succeeds — the first task to actually use `image_picker`, and this
project has a history of plugins that resolve but do not build.

**Not done here:** no golden for either AI sheet. Both render a network state
behind a permission-gated picker, and a golden that needs a stubbed async
frame plus a fake camera is a flaky test wearing a useful disguise. The
Settings golden covers the one AI surface that is purely local.

---

## T10 — Health Connect
**Date:** 2026-09-15

Steps and distance from Health Connect, the permission flow, the manual
override, and Stamina and Aard wired to real movement. 46 new tests, 561 in
total.

**The interesting half of this task is what the screen is *not* given.**

Steps, distance and Stamina are always-visible — they say how much the user
moved, which is an input like any other. Active energy is not: it is a term in
expenditure, and intake beside expenditure is the verdict. A panel reading
"8,240 steps · 437 kcal burned" next to the day's 1,275 kcal eaten hands the
user a subtraction.

So the stored row carries `activeKcal` — the weekly reckoning needs it — and
the UI is handed an `ActivityView`, which **has nowhere to put it**. The same
trick as `SealedValue`, one layer up: a widget cannot render what it was never
given, and adding the field would mean editing `activity.dart` with the comment
explaining why not sitting right there. There is a test that stores 437 kcal,
renders the panel, and asserts the number never appears.

**A manual entry always wins over a later sync.** The user typed a figure
precisely because the counter was wrong — a phone left on a desk, a walk with
the phone in a bag. A sync that overwrote it would make the override useless.
The DAO already enforced this from T2; `ActivitySync` decides it again above
the DAO so the result can say *why* a day was skipped rather than silently
reporting a write.

**A day the device never saw is left absent, not written as zero.** A zero
claims the user did not move; an absent day says the device did not see it.
Those are different, and the week's reckoning treats them differently.

**The sync re-reads a week every time.** Health Connect back-fills — a phone
that was off, a watch that synced late — so a day already past can gain steps.
Re-reading seven days costs one query and catches all of it.

**Intervals are attributed to the day they started.** A walk crossing midnight
is rare and splitting it proportionally would be more correct and less
predictable; the user reads these numbers against a calendar day they remember.
Written down because it is a judgement rather than an obvious default.

**T7's reckoning needed no changes at all.** It already read `activity_days`
and preferred measured movement over the self-described activity level; T10
simply put real rows there. The weekly expenditure is now measured rather than
guessed, without a line changing in `reckon`.

> [!note] I broke T4's tests, and it was the fake-async trap again
> Adding `ActivityPanel` to the Journal gave that screen a provider that awaits
> a drift query — so every Journal widget test hung for its full ten-minute
> timeout. Nine minutes of nothing before the suite gave up.
>
> The lesson is narrower than "use runAsync": **adding a database-reading
> widget to an existing screen breaks every test of that screen**, and it fails
> as a hang rather than as an error. Worth checking the callers whenever a
> panel gains a provider. Same fix as always — hand it a settled value.

**Verified:** `flutter analyze` clean, 561 tests green, goldens regenerated and
inspected, `flutter build apk --debug` succeeds. The `health` plugin is the one
that needed `FlutterFragmentActivity` back in T0, so a real Android build
mattered here more than usual.

**Not done here:** the five Signs as a screen. `aardCharge` is computed and
tested, but Igni, Quen, Axii and Yrden need the rest of the scoring and a
character sheet to live on — that is T12a.

---

## T11 — Week's End
**Date:** 2026-09-15

The reveal, built on T7's gate: the written account, the charts, XP, and the
week archive. All four permitted AI uses are now live. 30 new tests, 591 in
total.

**`NarrativeFacts` makes the one exception unwriteable.** The weekly narrative
is the only call permitted verdict data (CLAUDE.md §1), and it must run only on
the reveal day. Rather than rely on the call site remembering, the narrative
function takes a type that **cannot be constructed from a sealed week** —
`NarrativeFacts.from` returns null unless the reckoning is revealed, and
`weeklyNarrative` takes nothing else. There is no way to write code that asks a
model to describe a week still in progress.

The same shape as the gate's callback in T7: the guard is that the wrong thing
has no syntax, not that a comment forbids it.

**A sealed week is never recomputed.** Once written, the summary is frozen —
later changes to the scoring maths must not rewrite what the user was already
told. A history that edits itself is not a history. There is a test that seals
a week, seals it again with deliberately different figures, and asserts the
first ones survive.

**The narrative costs exactly one call, once.** Not on a re-open, not after a
restart, and — the case worth testing — **not after a failure**. A week that
failed to get an account keeps its null rather than retrying on every visit,
because a retry per visit is exactly how a fifty-a-day budget disappears.

**A failed narrative never blocks the seal.** No key, no network, no budget: the
week still freezes with every figure it has. The account is flavour on top of
the numbers, and refusing to seal because a model was unreachable would lose
the numbers to save the prose.

**Sealing happens when the screen opens.** There is no background job in a
serverless app, so a week closes when the user comes to read it. The archive is
idempotent, which is what makes that safe.

**XP rewards behaviour, never outcome.** Days logged, diet quality, days at the
step goal — nothing reads which way the scale went. Two reasons, and the second
is load-bearing: paying for weight lost would pay for a number that moves on
water, and would punish an honest week that went sideways; and XP that depended
on weight would be a verdict in disguise, unable to appear on a daily screen
without leaking the answer. The reveal says this out loud — *"Never for which
way the scale went."*

**`Reckoning` gained `dailyBalances`, sealed like the rest.** My first pass had
the chart plot the weekly average for every day, which would have drawn a
perfectly flat week — a lie in picture form. The per-day figures now come from
the reckoning itself and are sealed with everything else, because drawing the
verdict as a chart is no better than printing it. Adding the field made
`reckoning_test.dart`'s verdict list refuse to compile until it was covered,
which is exactly what that list is for.

> [!note] The fake adapter moved to `test/support/`
> T8's `openrouter_client_test.dart` had it inline, and T11 needed the same
> thing. It is the only description in the repo of what the OpenRouter wire
> looks like, and two copies would drift apart. Same argument as extracting
> `MealConfirm` in T9.

Two test files needed `archivedWeekProvider` overridden once the reveal screen
started watching it — unoverridden it reaches a real `AppDatabase` through
`path_provider` and throws `MissingPluginException`. The same class of breakage
as T10's activity panel: **giving an existing screen a new provider breaks that
screen's tests**, and it is worth checking the callers every time.

**Verified:** `flutter analyze` clean, 591 tests green, goldens regenerated and
inspected — the revealed week now shows the account, both charts and the XP
panel, and the sealed one is unchanged. `flutter build apk --debug` succeeds.

**Not done here:** the level-up animation from the plan. XP is awarded, frozen
and shown, but levels are a character-sheet concept and the curve belongs with
the rest of progression in T12a. Animating a level-up before there are levels
would have been a placeholder.

---

## T12a — The Path
**Date:** 2026-09-15

The character sheet: levels and ranks, the streak, Adrenaline, the five Signs,
and the chained weight node. 49 new tests, 640 in total.

**The design decision this task turned on: a streak is good to *show* and bad
to *pay*.**

An all-or-nothing streak that a single missed day destroys gives the user a
reason to invent a meal to keep it alive. This app's one demand is that they
log honestly, and a mechanic that pays for dishonesty would corrupt the only
dataset it has.

So the streak is **display** and Adrenaline is **reward**, and Adrenaline is
driven by days-logged-in-the-last-seven rather than by the streak. A missed day
costs a seventh, never everything. The sheet says so in as many words, because
a mercy the user cannot see does not change their behaviour.

**Nothing on this screen moves with the scale.** Levels come from XP, and XP is
awarded for logging, diet quality and movement (T11) — never for direction. A
level that moved with the weight would be the verdict wearing a hat: it could
not be shown on a daily screen without leaking the answer. The one weight
figure here is the current weigh-in, which is always visible; its *change* sits
chained, and there is a test asserting nothing shaped like `±N kg` is in the
tree while sealed.

**`Sign` moved from the widget layer into `domain/`**, exactly as `Rarity` did
in T6 and for the same reason: which sign is lit is a nutrition judgement, what
it looks like is the theme's business. The charging rules had never been
written down at all — the glyph took a `charge` and every caller invented one.

**Igni reads the Vitality protein component directly** rather than recomputing
protein adequacy. Two rules for the same thing eventually disagree, and a day
that scores well on protein in Alchemy must not leave Igni dark on The Path.
There is a test asserting the two agree.

**Total XP is summed from the sealed weeks, not kept as a running total.** A
counter can drift from the history it claims to summarise; a fold over frozen
rows cannot. A week sealed at 145 XP contributes 145 forever.

Small honesty in Axii: a day with no carbohydrate at all scores *neutral* on
the steadiness term rather than perfect. An absent glycemic load is not
evidence of an even day.

> [!note] A third 360-pixel overflow
> A label beside a numeral in a `Row` with neither able to shrink. The same
> shape as T6's two. Phone width is 360 logical pixels and an engraved label is
> wide; the reflex now is that any label-plus-figure row needs an `Expanded` on
> the label before it is written, not after a test finds it.

**Verified:** `flutter analyze` clean, 640 tests green, goldens regenerated and
inspected — the sheet shows five glyphs at real charges, Yrden visibly dim, and
the weight node chained with its countdown. `flutter build apk --debug`
succeeds.

**Not done here:** mutagens, and the level-up animation. Mutagens are weekly
perks that modify the *following* week's scoring — the only mechanic that
carries forward — and that belongs with the Bestiary and rarity work in T12b
rather than bolted onto the sheet. Yrden also reads a water log the app has no
way to fill yet; the sign is wired and tested but will sit low until there is a
way to record a glass of water.

---

## T12b — The Bestiary and mutagens
**Date:** 2026-09-15

Every food ever logged as a creature entry, with its stats and weaknesses;
mutagens granted when a week seals; and — unplanned, but forced — a navigation
drawer. 46 new tests, 686 in total.

**The Bestiary shows what has been *eaten*, not what is known.** The seed table
is in the library from the first launch, so a collection that claimed 132
creatures on day one would mean nothing. "Known" and "caught" are separate
counts, and the whole library is one chip away for anyone who wants it.

**A creature's rarity and weaknesses come from the same two calls the food
picker makes** — `rankFood` and `readFoodToxins`. Nothing new was invented
here, which is the point: a food must not read Epic in the picker and Rare in
the collection. Sorting happens in Dart rather than SQL for the same reason —
rarity and toxicity are *derived*, and pushing them into the database would
mean storing a score the scoring engine could later disagree with.

The creature sheet is a harm surface, so it carries the standing disclaimer and
every weakness states the public guideline it is measured against. A flag is
never a bare accusation. There is a test scanning the rendered sheet for
diagnostic phrasing.

**Mutagens are behaviour, never outcome.** Granted at the seal for a complete
week, good diet quality, days at the step goal, and a week out of the packet.
No condition may read weight, weight change, or energy balance — a perk that
depended on the verdict would *be* the verdict, arriving on the character sheet
the Monday after. There is a test running the same week with a 1.4 kg loss, no
change and a 1.4 kg gain and asserting identical perks.

They are decided from the **frozen summary**, so re-running the grant on an
archived week always gives the same answer, and `unlock` ignores a repeat award
for the same week — safe to call on every open, like the seal it rides along
with.

The empty-week trap from T6 showed up again: a week with nothing logged has no
toxicity at all, so White Honey would pass on an *absence of evidence*. Guarded
and tested.

> [!note] Five icons stopped fitting, so the app got a drawer
> Adding the Bestiary made a fifth app-bar action. Five 48-pixel buttons plus a
> title do not fit across 360 logical pixels, and the fix was not a smaller
> icon — it was admitting the app now has places to *go*. A drawer holds as
> many as it grows and gives each one the word that names it, which matters
> here because the vocabulary is load-bearing (CLAUDE.md §5) and an icon alone
> does not carry "The Reckoning".
>
> Worth noting that the crowding was the signal, not the problem. The plan
> deferred a nav shell to T12 and this is the moment it actually became due.

The path golden then failed with `!timersPending` rather than a pixel diff: the
new mutagen panel reached providers nobody had overridden, which woke a live
drift stream, which leaks a zero-duration timer on cancel. Exactly the leak
CLAUDE.md §2 describes. Same lesson as T10 and T11 — **a screen that gains a
provider breaks that screen's tests** — but a third failure mode for it.

**Verified:** `flutter analyze` clean, 686 tests green, goldens regenerated and
inspected. `flutter build apk --debug` succeeds.

**Gaps left open, deliberately:**

- **Yrden still reads a water log nothing writes.** Carried from T12a. The sign
  is wired and tested; it will sit low until there is a way to record a glass
  of water.
- **Mutagen bonuses are computed but not yet spent.** `MutagenBonus` is shown
  on the character sheet and applied nowhere — XP is awarded at the seal before
  the following week's perks exist. Wiring the carry-forward means deciding
  whether a perk earned in week N applies to N+1's award or its *scoring*, and
  that is a design call rather than a wiring one.
- **The Bestiary has no image.** `imagePath` is carried through from Open Food
  Facts and never rendered; the card has no room for it as drawn.

---

## T13 — Persistence
**Date:** 2026-09-15

The backup mirror, the restore, and the `MANAGE_EXTERNAL_STORAGE` platform
channel that was deferred from T0. 20 new tests, 706 in total.

**The backup operates below the type converters, and that was the bug worth
finding.** The first pass used drift's own `toJson()` on each row — which
hands back the *Dart* objects, so a `Day` came out as an instance of `Day` and
the whole snapshot refused to encode.

The fix is better than a workaround: the mirror now reads raw SQL through
`customSelect` and writes it back through `customInsert`. A `Day` is a
`yyyymmdd` integer and an enum is its name, which is what SQLite actually
holds. More to the point, **a type converter is a property of this build and a
backup has to outlive it** — a mirror written through today's converters is a
mirror that stops loading the day one changes. There are tests asserting both
the `Day` converter and an enum column survive a full round trip; losing the
former would silently move every meal into a different week, which is the one
thing that would corrupt the product.

**A restore is all-or-nothing.** One transaction, tables cleared in reverse
dependency order and inserted in forward order, so a failure halfway leaves
the existing data intact. The worst outcome here is not a failed restore — it
is a half-restored database that looks plausible.

**One bad row does not cost the restore.** A backup written by an older schema
can carry a column this build no longer has. Losing a year of history to a
single unreadable row would be the worse failure, so the insert skips it and
carries on.

**The JSON is written to a `.part` file and renamed.** A rename is atomic on
the same filesystem, so a backup is never left half-written — and the Markdown
goes first, because a stale JSON beside a fresh Markdown is recoverable while
a truncated JSON is not.

**The Markdown mirror exists to be read.** The JSON is what restores the app;
the Markdown is what makes the folder worth opening. A file nobody ever checks
is a backup nobody finds out is broken, so it carries a row count per table,
the profile, and every closed week with its written account — and it says
plainly which of the two files actually restores.

**Restore is offered before onboarding, not after.** A fresh install with a
backup in the folder is asked first; asking afterwards would mean restoring
over a profile the user had just finished typing. Both conditions have to hold
— nothing here, and something there — so an app with a life of its own is
never quietly overwritten.

**"Continuous" turned out to mean "on pause".** Writing the mirror after every
logged meal would spend a file write per meal on a file nobody reads between
meals. Backgrounding the app is both the moment the user has finished changing
things and the last moment the process is reliably alive.

> [!note] The permission has no callback
> Android returns nothing when the user grants all-files access — they leave
> for a Settings screen and may never come back. Both the Settings panel and
> the app root re-check on `AppLifecycleState.resumed` rather than awaiting a
> result that may never arrive. The channel asks for
> `ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` with a package URI so the
> user lands on this app rather than on a list of every app installed, with a
> fallback for OEM builds that lack the per-app screen.

> [!warning] `.gitignore` was silently eating the new source
> T0 added a bare `backup/` line for a local backup-artefact folder. A git
> pattern with no leading slash matches **at any depth**, so `lib/data/backup/`
> and `lib/features/backup/` — the whole of this task's source — were excluded
> from `git status` and would have been left out of the commit entirely.
>
> Caught only by reading the staged list before committing and noticing two
> directories missing. Anchored to `/backup/`. Worth a look at any other bare
> directory pattern: `secrets.json` and `*.env` are fine, but the same trap is
> one careless line away.

**Verified:** `flutter analyze` clean, 706 tests green, goldens regenerated and
inspected, `flutter build apk --debug` succeeds — the Kotlin change made this
build matter more than usual.

**What a manual run still needs (T14):** an app icon, a splash screen, and a
release APK. The reinstall test from the plan's verification list can only be
done on a device and is the one thing here that no test can stand in for.

---

## T14 — Polish, and a release build
**Date:** 2026-09-15

The launcher mark, the splash, the release APKs, and a README written for
someone about to put this on a phone. No new tests; 706 still green.

**The icon is a vector, not five PNGs.** minSdk is 26, so every device this app
runs on supports adaptive icons — which means the mark can live in the repo as
*text*, editable in a diff and impossible to drift out of step with the theme
tokens it borrows from. It is the app's own language: a hollow diamond node
inside ornate corner brackets, gold `#C9A227` on void black.

The stock PNGs are left in place as a fallback nothing will ever reach; a
`mipmap-anydpi-v26` adaptive icon wins on every device above API 26.

**The splash needed three files, not one.** `launch_background.xml` covers
API 26–30, and Android 12 replaced that mechanism entirely — without a
`values-v31/styles.xml` declaring `windowSplashScreenBackground`, a modern
phone ignores the drawable and draws the system default. Both point at the
same void black, and `NormalTheme` does too, so there is no white frame
anywhere between tapping the icon and the first frame of the app.

One trap on the way: `<bitmap android:src="@drawable/ic_launcher_foreground">`
does not work — `<bitmap>` needs a raster and fails to inflate on a vector. It
is a sized layer-list item instead, with explicit width and height, because a
bare item stretches its drawable across the whole window.

**The backup folder had two spellings.** The code said
`Documents/WitcherDiet`, the README and [[02-Architecture]] both said
`WitchersDiet`. Harmless today and a lost backup later — a user who moved
phones would have copied a folder the app then did not look in. The code now
matches the prose.

**Two providers were opening a stream to read it once.** `creaturesProvider`
and `totalXpProvider` both did `watch...().first`. Drift schedules a
zero-duration timer when a query stream is cancelled, and there was never a
reason to open a stream you immediately close — the same lesson as
`JournalDao.forDay` in T4. Both DAOs gained a plain one-shot read beside the
stream.

**Release:** `flutter build apk --release --split-per-abi` succeeds with R8 and
resource shrinking on. arm64 lands at 28.9 MB, which is mostly the two bundled
variable fonts and the native libraries for sqlite3, Health Connect, the
scanner and the image picker. Signed with the debug key on purpose — this is a
sideloaded personal build and will never see the Play Store. Worth knowing: it
will not upgrade *over* a build signed with a different key.

**The README is now an install guide**, because that is what it is for: which
ABI to take, what Android will ask, and a first-run order that matters — file
access before the first backup, Health Connect before expecting step history,
and the key last, since everything works without it.

**Verified:** `flutter analyze` clean, 706 tests green, goldens regenerated and
inspected, debug **and** release APKs build.

**What only a phone can check.** The reinstall test from the plan's
verification list is the one thing no test here stands in for: uninstall,
reinstall, grant file access, take the restore offer, confirm the history
returns. The round trip is covered against a real database and a real folder,
but the folder in the test is a temp directory, not
`/storage/emulated/0/Documents/`. Same for the icon and splash — they parse,
they build, and what they *look like* is a device question.

---

## T15 — The improvement plan
**Date:** 2026-09-15

No code. The first real-device shakedown of the T14 build produced five reports,
and reading the code around them turned up six more issues that had never been
written down. [[91-Improvement-Plan]] is now where they live, and
[[00-Index]] points at it.

**Why a separate note rather than more of this log.** This file is a record of
what *happened*, in order, and it is 1,176 lines. An open issue buried in it is
an issue nobody will find — which is precisely what happened to four of the six.
Two of them ("Yrden reads a water log nothing writes", carried from T12a to T12b
and then dropped) had been written down twice and still went unscheduled. A
backlog needs to be a list you can read in one sitting.

**Three of the five reports were narrower than they looked**, and that is the
part worth recording here:

- **"New feature: photograph a dish."** Already shipped in T9. The button renders
  only when a key is saved, so on a keyless install it is invisible. The work is
  discoverability, not capability.
- **"Add water tracking."** The table, the DAO and the Yrden sign have existed
  since T12a. `upsertWater` has zero callers. No migration needed.
- **"The barcode scan dies instantly."** Not a camera fault. The scan succeeds
  and returns the code; the failure message is posted through the root
  `ScaffoldMessenger` and painted into the `JournalScreen` scaffold —
  *underneath* the opaque bottom sheet. Both error strings are completely
  covered by void black.

That last one is the lesson of the round. The error handling was written, tested
at the provider level, and correct; it just had nowhere to appear. Every path in
`_scan` reports through one channel, and that channel had been invisible since
the sheet was built in T4. There is no widget test for the search sheet or the
scanner, which is why nothing caught it — `test/food_lookup_test.dart` covers the
providers and the fake remote only.

**Two things it changed about the plan.** The barcode fix leads, because it is
the only report where the app loses data the user tried to give it. And no new
AI use case is added: `../CLAUDE.md` §4 caps AI at four purposes, photo → items
is already one of them, and the portion estimator that T20 wires up is the
second purpose, which Settings has advertised since T8 without anything calling
it. The budget maths is unchanged.

**Verified:** `flutter analyze` clean, 706 tests green — both unchanged, as they
should be for a documentation commit.

---

## T16 — The barcode that answered nothing
**Date:** 2026-09-15

A scan of a packet of salted almonds read the code, closed the scanner, and
added nothing — with no error either. Three separate faults, each of which
would have hidden the other two. 706 → 720 tests.

**The scanner was never the problem.** It read the barcode and returned it
correctly. What failed was everything after, and the reason nothing was said is
the sort of bug that survives a good test suite: `_say` posted a `SnackBar`
through the root `ScaffoldMessenger`, which paints into the `JournalScreen`
scaffold. The search sheet sits *above* that in the navigator and is opaque from
48px to the bottom edge. Every message this sheet has produced since T4 was
drawn underneath it.

The error handling was written, it was correct, and it had nowhere to appear.
The notice is now rendered inside the sheet, above the results, dismissible and
cleared by the next keystroke. Reverting only that one method makes four of the
five new widget tests fail, which is the check that the test is real.

**Four outcomes were collapsed into one `null`.** `barcodeLookupProvider`
returned `Food?` and threw `RemoteUnavailable`, so "upstream has never heard of
this code", "upstream has it and it cannot be used", "the write-back failed" and
"there is no network" all arrived as the same nothing. It now returns a sealed
`BarcodeOutcome`, so `non_exhaustive_switch_*` makes the sheet say something
true about each — the same enforcement the reveal gate uses, for the same
reason. `OffMapper.fromProduct` returns a sealed `ProductLookup` under it, since
only the mapper knows *why* it refused.

**The mapper was rejecting real products as nameless.** This is what the almonds
actually hit. `product_name` carries only the field for the language that was
asked for, and the request pins English; a product named solely in Romanian
arrives with it empty and was thrown away.

Worth recording that the obvious fix is not enough: the package ships
`getBestProductName`, but it too only ever looks at the one language it is
given, so it returns empty for exactly this case. The fields request now asks
for `NAME_ALL_LANGUAGES` and `GENERIC_NAME`, and when the package's own helper
comes back empty the mapper falls back to a name in *any* language upstream has.
A name in a language the user did not ask for is still the name on the packet in
their hand.

The no-energy rejection stays. Mapping a product with no energy figure to
`kcal: 0` adds a silent zero to the day and the user believes they logged their
lunch. But the refusal now carries the name upstream *did* give, so T19 can
offer to record it by hand starting from something.

**Two catches were letting failures escape entirely.** `_guard` caught only
`Exception`, so a `TypeError` from crowd-sourced JSON — a string where the
schema says a number — sailed straight past it, and `_scan` caught only
`RemoteUnavailable`, so a database error from the write-back did too. In a
minified release build, which is what ships, either one is a failure with no
output at all. `_guard` now has a terminal `catch (e)`; catching `Error` is
normally a bug worth crashing on, but upstream's data is not our invariant.

**The scanner screen gained the feedback it never had.** A haptic tick on a
successful read — without it, "the camera never read anything" and "it read
something and the lookup found nothing" are the same experience. Also a
`mounted` guard before popping, and `onDetectError` actually supplied: its
default is a documented no-op, so a damaged or badly-lit label used to leave the
preview running with nothing to show for it.

**One design note.** `BarcodeScannerScreen.scan` is now behind
`barcodeScannerProvider`, injected the same way as `foodRemoteProvider` and
`imagePickerProvider`. A widget test has no camera, and without that seam the
whole reporting path stays untestable — which is precisely how it came to be
broken for four tasks. There is now a `test/food_search_sheet_test.dart`; the
sheet had none at all.

**Verified:** `flutter analyze` clean, 720 tests green, `flutter build apk
--debug` succeeds. The scan itself is still a device question.

---

## T17 — The waterskin
**Date:** 2026-09-15

Yrden has read a water log since T12a that nothing could write. The gap was
recorded twice — once in T12a, again in T12b's "gaps left open" — and scheduled
neither time. It is now fillable. 720 → 738 tests.

**No schema change.** `WaterLogs`, `TrackingDao.upsertWater` and the sign were
all built and tested two tasks ago; the only missing piece was a button. Worth
noting for its own sake: the cheapest feature in this repo was also the one that
sat open longest, because nothing in the log said how cheap it was. That is why
[[91-Improvement-Plan]] now exists.

**A food counts as a drink because of how it was logged**, not because of
anything on the food row. Nothing there marks a food as a liquid, and the same
row is a splash of milk or a glass of it depending on the entry. So the rule is
`entry.unit == PortionUnit.millilitres`, and the volume credits 1:1 — which is
not a fudge, because `PortionUnit.millilitres` already declares one gram per
millilitre, so `grams` on such an entry *is* the volume and has been since T4.

**Only alcohol discounts, and it discounts to zero.** The temptation was to
discount coffee and tea too, and it was refused on the grounds that no caffeine
figure is stored on a food anywhere in this app — any such number would have had
no source behind it, and the current evidence is that caffeinated drinks hydrate
about as well as water anyway. Alcohol differs on both counts: `alcoholG` is
stored, and it is a genuine diuretic. Crediting it as nothing is the
simplification that can never *overstate* how much someone has drunk, which is
the only direction that matters. Lore, not a physician, as everywhere else.

**The two sources cannot double count, by construction.** The tapped figure is a
`water_logs` row; the drink figure derives from `entries`. They are disjoint, and
`Hydration` is the single place they are added, read by both the panel and the
glyph — so the two can never disagree about how much someone drank. The claim is
pinned in `signs_test.dart` as an equality: 2,000 tapped, 2,000 drunk and
1,000 + 1,000 all charge Yrden identically.

Someone who both taps +500 and logs "Water, 500ml" has recorded the same glass
twice. That is a thing they did, not a thing the app did.

**A bug fixed on the way.** `signChargesProvider` read water through `waterFor`,
a one-shot query. While nothing could write water this was merely pointless;
with the waterskin writing to it, the glyph would have shown a figure from
before the last sip. It watches `hydrationProvider` now.

**Two traps worth recording.**

`water_logs` holds one total per day, not a list of sips, so there is no log to
undo — the minus button is a *decrement* and reads as one. It remembers the last
amount added so the immediate undo is exact, and falls back to the smaller step
after a rebuild. Anything better needs a per-sip table, which is not worth a
schema version for a button.

And `journal_test.dart` asserts that no text on the Journal contains `/`, plus a
banned-word list including *target* and *goal*. A default `StatBar` renders
`1500 / 2000` and fails it — correctly, because an `x / y` ring is the progress
framing this app exists to refuse. The bar reads "1,500 of 2,000 ml" and the
caption says Yrden asks for two litres. The test was honoured, not edited; it
caught exactly what it was written to catch, two tasks after it was written.

**Both Journal tests and the Journal golden gained a `waterLogProvider`
override.** Without it every one of them opens a live drift stream, which fake
async never lets finish and which leaks a timer on cancel — the same lesson as
T10, T11 and T12b, and now the fourth time a screen gaining a provider has
broken the widget tests that mount it. `path_screen_test` overrides
`signChargesProvider` wholesale and was unaffected.

**Verified:** `flutter analyze` clean, 738 tests green, `journal_day.png`
regenerated and inspected.

**One note on the toolchain, from doing this wrong.** Two `flutter test` runs
overlapping collide on `build/native_assets/sqlite3.dll` and the second dies
with the `PathExistsException` the rules warn about — the same wreckage as
killing a run, reached from the other direction. Do not start a second run
while one is in flight.

> [!danger] This entry gave the wrong remedy, and T22 is what it cost
> As written on 09-15 it said `rm -rf build/native_assets` was "still the fix".
> It is not. Running it the next day took `android/jniLibs/` with it and shipped
> a release APK with no SQLite in it — see T22 for why the build system then
> never copied the libraries back. Delete **only** the half-copied file:
> `rm -f build/native_assets/windows/sqlite3.dll`, per `../CLAUDE.md` §2.

---

## T18 — A search that finds things
**Date:** 2026-09-15

Two searches came back from first use, and both failed outright: "white monster"
found nothing while "monster ultra" worked, and "5 fried eggs" found nothing at
all. One cause each, plus a third nobody had noticed. 738 → 780 tests.

**The old query was a single `LIKE '%<whole typed string>%'`.** So a multi-word
search only matched words that were *adjacent and in the order typed* — "white
monster" cannot match `monster energy ultra white` by construction — and a
leading digit was searched for literally. There was no tokenisation, no plural
handling and no quantity parsing anywhere in the path. Matching is now
token-based: every term must appear, in any order.

**The plural rule needs no migration, and that is the whole design.** The
instinct is to normalise plurals on both sides, which means re-keying every row
already on a device. It is unnecessary, because the match is *containment*, not
equality. Stem the **query only**, with a purely *truncating* stem, and the stem
is a prefix of both forms: `eggs` → `egg` finds a stored `egg whole` and a
stored `scrambled eggs` alike. `search_key` keeps its exact contract, the T2 test
pinning `'  Coca-Cola   ZERO! '` → `coca cola zero` stays green untouched, and
`schemaVersion` stays at 1.

The length floors matter more than they look: without them `is` becomes `i`,
`fries` becomes `fr`, and `glass` becomes `gla` — terms that match nearly
everything.

**Two bugs found while writing it, both mine, both caught by tests.**

The quantity parser read the *normalised* text, and normalisation strips every
punctuation mark — so `1.5 cup rice` had already become `1 5 cup rice` and the
half was gone before the parser saw it. The quantity is now read off the raw
string, which is also simply more correct: the parser should see what the user
typed.

And `a dozen eggs` came out as quantity **one**, because "a" is itself a number
word and was consumed first. An article followed by another number word now
defers to the second.

**A test expectation of mine was also wrong**, which is worth recording because
the code was right: I had asserted `ricecakes` was a worse answer for "rice"
than `brown rice`. It is not — the term *begins* the word, and a prefix is what
typing into a search box means. `licorice` is the tier-2 case.

**Number words earn their place.** They look like indulgence in a search box
until you notice that *every* term must match: an unrecognised leading "dozen"
would block the entire query and return nothing, which is strictly worse than
what this replaces. Fifteen constant entries buy that off. Fractions, ranges and
"a couple" are deliberately not supported — the free-text path already has a
model behind it, and turning the search box into a second parser duplicates it.

**The ranking was a lie, and is now a comparator.** `FoodsDao.search`'s comment
promised ordering by source quality; there was no ordering term on `source` at
all, so an AI row at confidence 0.95 outranked a seed row at 0.9 — the exact
inversion the comment said could not happen. It is a Dart comparator now, partly
because the tier rule is a domain rule that must be testable without a database,
and partly because this is precisely how quietly an SQL `ORDER BY` stops meaning
what it says it means. The `WHERE` stays in SQLite as N ANDed LIKEs.

**Two stale-state bugs fixed in the same area.**

`foodSearchProvider` was not `autoDispose` and never invalidated, so every
distinct string ever typed was cached for the life of the app — and a food
written by a barcode scan or a remote pick did not appear when the same query
was retyped. `autoDispose` alone does not cover that case, because the sheet
never closed; a `foodLibraryTickProvider` bumped by the three write sites does.

And the clear button set the query directly without cancelling the debounce, so
a timer scheduled a moment earlier fired afterwards and put the cleared query
straight back. Both now go through one `_setQuery`. Reverting only that makes
the new widget test fail, which is the check that the test is real.

**One judgement call in the portion sheet.** A bare number means "5 of them",
not "5 grams", so a parsed quantity is only trusted when the query named a unit
or the food comes in pieces. Otherwise "5 fried eggs" against a food with no
piece weight would open the sheet at **5 g** — worse than the 100 it replaces.
A barcode also deliberately does not carry the count through: it names one
specific product, and whatever number is sitting in the search box is about
something else.

**Verified:** `flutter analyze` clean, 780 tests green. Whether the seed table
actually contains a "fried egg" is a separate question — it does not, and T19's
hand-written foods are the answer to that.

---

## T19 — Write it down yourself
**Date:** 2026-09-15

`FoodSource.manual` has been the top rung of `FoodsDao.upsert`'s trust ladder
since T2, and nothing in the app could write it. The enum value existed, the
precedence rule that protects it was written and tested, and there was no UI
anywhere that produced one. 780 → 790 tests.

The consequence was a dead end at exactly the moment the app is supposed to be
at its most useful. Three of the four resolution steps can miss at once —
nothing in the library, nothing in the seed table, no network or nothing
upstream — and until now the fourth step, the user's own knowledge, had no way
in. A packet in their hand, and the answer was "search by name instead".

**Two entry points, both of which were previously terminal.**

The search sheet's empty state, which is reached whenever there is no key and no
network. That is not an edge case: it is the configuration the app is designed
to remain fully usable in, and it was the one place where it was not.

And T16's `BarcodeUnusable`, prefilled with whatever name upstream did give.
This is why that refusal was made to carry the name rather than just a reason —
"the ledger knows it as Salted almonds but records no energy for it" is a much
better starting point than a blank field, and the row it writes keeps the
barcode, so the scan that failed works from then on.

**A hand-written row is permanently authoritative.** `upsert` already refuses to
let a weaker source overwrite a stronger one, so a later Open Food Facts scan of
the same barcode enriches nothing and replaces nothing. That rule now has a test
that can actually reach it: write 600 kcal by hand, then upsert the same barcode
from upstream at 123 kcal, and the row still reads 600 with one row in the table.
Before this task that assertion could not have been written.

The sheet passes an empty search key on purpose and lets `upsert` compute it —
the same reason T4 put that rule there, and the reason a caller that normalised
differently would silently insert a duplicate.

**Kept deliberately small.** Name, brand, and the five figures on the front of a
packet: energy, protein, carbohydrate, fat, fibre. Per 100 g, like everything
else in the app. Sodium, sugar, NOVA group and additives are all absent, and
that is the point — this is a form someone fills in standing in a kitchen with
a packet, not a data-entry screen. Anything it does not capture can be corrected
later through the same sheet, since a manual row may always be overwritten by
another manual row.

**Two test notes.** `scrollUntilVisible` needs the *sheet's* scrollable, not
`find.byType(Scrollable).last` — a `TextField` has an internal scrollable of its
own, and pointing at it drags something 38 pixels below the bottom of the
screen. Targeting it as the ancestor of a heading unique to the sheet is stable
in a way an index is not.

And a `ListView` does not build what has not been scrolled to, so the submit
button genuinely does not exist in the tree until then. Worth remembering: the
failure reads like a missing widget, not like a scrolling problem.

**Verified:** `flutter analyze` clean, 790 tests green.

---

## T20 — The photograph, made findable
**Date:** 2026-09-15

Reported as a feature request: *"I should be able to take a picture of the dish
I cooked and the AI should break it down."* It has done exactly that since T9.
790 → 797 tests.

**The whole feature was invisible.** Both AI buttons rendered only when a key
was saved, so on a keyless install there was no camera icon at all — no button,
no hint, nothing to suggest the capability existed. The reasoning behind that
gate was sound and is quoted in the source: *"a button that always fails is
worse than no button, and the app is fully usable without one."* It produced the
wrong outcome anyway.

The flaw is that it weighed two options and there was a third. A button that
*explains itself* is neither a button that always fails nor no button. Both now
render always, dimmed without a key, and tapping one says what the model would
do and offers a route to Settings. It is written as an offer rather than a
warning, because nothing has gone wrong: the app is complete without a key, and
the panel says so.

Worth keeping as a general lesson — a capability nobody can discover is worth
nothing, and "it would fail if they tried" is not a reason to hide it, only a
reason to not let them try blindly.

**The prompt was wrong for cooked food.** `photoSystem()` said *"Name only what
you can actually see. Do not infer a side dish that is out of frame."* Right for
a plated meal; wrong for a stew, a bake or a curry, where the components are by
definition not individually visible. A model held to the strict reading returns
one opaque item or nothing.

The composite clause is not a loosening of that rule, it is the rule applied
honestly — a stew is a thing you *can* see. What keeps it truthful is that a
component the model did not see directly must carry a confidence of 0.5 or
below, which the app already surfaces as a portion worth correcting, and that it
is told to prefer a few large components over a long invented recipe.

The "only what you can actually see" line was left **exactly** as it was, rather
than reworded around the new clause. `ai_prompts_test.dart` asserts on that
phrase, and a test guarding a §1-adjacent invariant is not something to edit
around when the clause can simply be added beside it.

The note field was moved out of the margin and given a heading — *"What did you
cook?"* — with a worked example. The cook is the only source in the whole
exchange that was actually present when the food was made, and what they say
outweighs anything a model can infer from pixels.

**`estimatePortion` is finally called.** It has had a client, a schema, a
decoder, a prompt and tests since T8, `ResolvedPortion.worthRefining` has been
sitting there as the hook it was built for, Settings has advertised the feature
for twelve tasks, and nothing in `lib/` ever invoked it. Offered now in the
portion sheet, on a portion the app has already admitted is a guess, only when a
key exists.

This is **not a fifth AI purpose** — CLAUDE.md §4 caps it at four and requires a
deliberate decision to add one. This is the second of the four, completed. The
budget maths is unchanged.

Taking the estimate switches the entry to grams rather than storing a corrected
multiplier against "handful". That is what makes it honest: the entry then reads
45 g, which is what it means, and it inherits the confidence of an exact unit
instead of the handful's 0.5.

**Two things the tests caught.** A four-pixel vertical overflow at 360 logical
pixels — the third time a fixed column at that width has done this in this
project, and the reason the notice is now scrollable. And `WitcherButton`
uppercases its own label, so `find.text('Not now')` finds nothing.

**Verified:** `flutter analyze` clean, 797 tests green. Whether a model actually
breaks a real cooked dish into sensible components is a device-and-key question
that no test here can stand in for.

---

## T21 — Turning the page
**Date:** 2026-09-15

The app's first animation outside onboarding, and the one the progress log has
recorded as planned-and-dropped twice. 797 → 803 tests, no golden changed.

**Not a swipeable `PageView`, and the reason is not the index arithmetic.** Six
providers read the *global* day cursor rather than a page's day —
`journalEntriesProvider`, `dayActivityProvider`, `dayActivityIsManualProvider`,
`toxicityProvider`, `signChargesProvider` and `journalDayViewProvider`. A page
view builds the adjacent page *before* the cursor moves, so the incoming page
would render the current day's numbers and then visibly flicker to the right
ones. Making it honest means re-keying all six as `.family<..., Day>` and
touching every one of their tests. That is its own task, and the right one to do
first if swipe-to-change-day is ever wanted.

**The trap was worse than a loading flash.** When the cursor moves,
`journalEntriesProvider` is recreated, and in Riverpod 2 `whenData` on an
`AsyncLoading` yields a plain `AsyncLoading` — **previous data is not carried
through**. So the old `switch (view)` fell to its `SizedBox.shrink()` arm and the
body blanked for a frame. And `dailyTotalsProvider` was a separate provider with
its own `orElse: empty`, so even a partial fix would have shown the previous
day's rows beside zeroed totals.

Both are fixed by making a rendered page **one atomic value**: `DailyTotals` is
now a `late final` on `JournalDay`, and a small stateful widget holds the last
*settled* page and ignores loading frames. The body therefore lags the date
header by the length of one drift query. That is deliberate and is commented as
such — a page that arrives late beats one that slides in empty and then fills.

The switcher is keyed on the day the **data** is for, not on the cursor, so
adding an entry to the same day is a plain rebuild rather than a page turn.

**Direction is a plain field on the notifier.** Not a second provider: two values
that can disagree is worse than one that cannot, and a second provider raises a
rebuild-ordering question with no good answer. It is only ever read during the
rebuild the day change itself caused, so the fact that it does not notify is
correct rather than a hazard — and `lastShift` is directly unit-testable.

One thing that is easy to get wrong: `AnimatedSwitcher` rebuilds the *outgoing*
child with the same `transitionBuilder` and a reversing animation, so without
telling the two apart by key the old page slides back the way it came instead of
out the other side.

**Two bugs found by the tests, both mine.**

A `CircularProgressIndicator` left in the tree at zero opacity never stops
spinning, so `pumpAndSettle` can never settle — every widget test on the search
sheet timed out at once. The scrim still fades; the spinner inside it is built
only while it is spinning.

And a `SliverAnimatedOpacity` at a constant `opacity: 1` animates nothing. It was
written to fade the Open Food Facts section in, and it would have been a no-op
dressed as an animation, so it was dropped rather than shipped. The local list is
deliberately not animated either: it changes on every settled keystroke, and
fading each one reads as lag.

**Motion lives in the theme tokens**, for the same reason colour does — 220ms and
a 6% slide is a page being turned, not a Material route, and a duration picked
per widget drifts. `tokens.dart` now imports `package:flutter/animation.dart`
rather than `material`: it is the bottom of the theme layer and nothing in it
should be able to reach a widget.

**No golden changed**, which is the check that the claim holds:
`AnimatedSwitcher` does not animate its first child, so a freshly pumped screen
is at rest. Had one changed, the key would have been wrong.

**Verified:** `flutter analyze` clean, 803 tests green, goldens pass without
regeneration.

---

## T22 — The library that was not there
**Date:** 2026-09-16

A release APK that installed, launched, and showed "The Path is blocked" on the
first frame. `Failed to load dynamic library 'libsqlite3.so'`. No code change
caused it; the build system did, and it did so silently.

**What actually happened, in order.** `sqlite3` 3.x has no Android module — it
is a Dart *code asset*. Its build hook downloads a prebuilt `libsqlite3.so` per
ABI into `.dart_tool/hooks_runner/shared/sqlite3/build/download-*/`, and
`flutter assemble`'s `install_code_assets` step copies them into
`build/native_assets/android/jniLibs/lib/<abi>/`, a directory the Flutter Gradle
plugin has registered as a `jniLibs` source dir (`FlutterPlugin.kt:442`, in the
SDK, not this repo).

On 2026-09-15 a `flutter test --update-goldens` run died with the
`PathExistsException` on `build/native_assets/windows/sqlite3.dll` that §2 of
CLAUDE.md warns about — and §2's remedy was `rm -rf build/native_assets`. That
took `android/jniLibs/` with it. The next `flutter build apk --release` then
produced an APK with no SQLite in it.

**The part that makes this a trap rather than a mistake.** `install_code_assets`
declares exactly one output — `native_assets.json` — and that file lives in
`.dart_tool/flutter_build/<hash>/`, not in `build/native_assets/`. So after the
wipe the stamp was still valid, the step was skipped, and it would have gone on
being skipped forever. And Gradle cannot tell: an empty `jniLibs` source
directory is a legal empty source directory. `flutter analyze` was clean,
803 tests were green, Gradle reported success, and the APK was broken.

The evidence was all on disk and none of it needed a phone:

| artifact | time | `libsqlite3.so` |
|---|---|---|
| `app-arm64-v8a-release.apk` | 09-15 17:12 | present |
| `app-debug.apk` | 09-15 18:22 | present |
| *`rm -rf build/native_assets`* | 09-15 18:37 | — |
| `app-release.apk` | 09-15 19:13 | **absent** |

`build/app/intermediates/merged_jni_libs/release/.../out/` was empty while the
debug equivalent had all three ABI folders, which places the loss upstream of
packaging rather than in the release-only `isMinifyEnabled` / `isShrinkResources`
— neither of which touches `lib/`.

**Three things changed, and no app code.**

`tools/check_apk_libs.py` opens the APK and fails if any ABI folder carrying
`libflutter.so` lacks `libsqlite3.so`. Keying on the engine rather than on
`libapp.so` matters: a fat release APK carries plugin `.so` files for ABIs it
was never built for, because those arrive from AARs, so plugin libraries are not
evidence that the app targets an ABI. Verified against all three APKs above —
it passes the two good ones and fails the shipped one.

§2 of CLAUDE.md now says to delete the single half-copied `sqlite3.dll` rather
than the tree, and §3 has a new subsection explaining the missing-output stamp,
because "never `rm -rf` this directory" is not a rule anyone can follow without
knowing why.

The recovery is `rm -f .dart_tool/flutter_build/*/install_code_assets.stamp`,
which is narrower than `flutter clean` and rebuilds in a fraction of the time.

**What was deliberately not done.** A Gradle-side check that fails the build
would be automatic rather than remembered, which is better — but the copy is
produced by a Flutter task and consumed by an AGP task with no declared
dependency between them, so a `doFirst` assertion on `merge*JniLibFolders`
could fire on an ordering that is merely unlucky rather than broken. A check
that fails builds that would have worked is worse than one that runs a second
after them. The APK itself is the honest thing to inspect.

---

## T23 — Correcting the record, and the next backlog
**Date:** 2026-09-16

No app code. Three things the repo was still telling a reader that were no
longer true, and a plan for what is left.

**The T17 entry was giving the instruction that broke the release build.** It
closed with "`rm -rf build/native_assets` is still the fix" for the
`PathExistsException` from overlapping test runs. T22 is the account of what
that cost: run the next day, it took `android/jniLibs/` with it, the
`install_code_assets` stamp stayed valid, and `app-release.apk` shipped with no
SQLite in it. CLAUDE.md §2 was corrected in T22; **the log entry that taught the
wrong habit was not**, and a log is read far more often than a rules file.

It now carries a callout saying what it originally said and what it cost, rather
than being quietly rewritten. The two later mentions of the same command in T22
are history — they describe what was done on 09-15 — and stay exactly as they
are. There is a difference between a record of a mistake and an instruction to
repeat it, and only the second one needed fixing.

**The install guide was still building three APKs.** arm64 is the only target
for now: every phone made in the last several years is arm64, this is a
sideloaded personal build rather than a Play Store upload, and nothing is
gained by paying for `armeabi-v7a` and `x86_64` on every release. The README now
says `--target-platform android-arm64`.

And it now names `tools/check_apk_libs.py` as a required second command. T22
added the script and put the rule in CLAUDE.md §3, but never touched the README
— so the *install guide*, which is the document someone actually follows when
putting this on a phone, still described the exact build sequence that shipped
the broken APK. A check that only the agent's rules file knows about is a check
that stops running the moment a human builds the release.

**The device questions came back answered.** The update-survival pass and T13's
backup round trip — the two largest unknowns [[91-Improvement-Plan]] carried —
both came back clean on a real phone, including an install *over* the
SQLite-less build. Nothing was lost. Worth keeping: a missing native library is
a runtime failure, so it never touched the database on disk, which is a better
argument for keeping the debug signing key stable than any of the ones in T14.
Item 1, the barcode against a real label, is still open. The branch is merged to
`main` as PR #1.

**[[92-Mechanics-Plan]] is the new backlog**, and writing it found a fifth dead
path: `withAdrenaline` has no callers either. Adrenaline is computed from the
last week's logging, shown on The Path every day, and multiplies nothing — so
the reward chain is disconnected at both joints, not one. That is worse than the
mutagen gap it was found beside, because it is on a daily screen rather than a
weekly one, and it is now folded into the same task.

**Verified:** `flutter analyze` clean, 803 tests green — both unchanged, as they
should be for a documentation commit.

---

## T24 — Perks that are actually spent
**Date:** 2026-09-16

Mutagens have been earned, stored and displayed since T12b and spent nowhere.
Fixing that turned up a second, worse version of the same fault and a
contradiction in the rules. 803 → 816 tests.

**The reward chain was disconnected at both joints.** `MutagenBonus.applyToXp`
had no callers, which was the known gap — and `withAdrenaline` had none either,
which was not. Adrenaline is computed from the last seven days, drawn on The
Path every single day as a ×1.43, and multiplied precisely nothing: `awardXp`
was used raw at the seal. So the app had been quoting a daily reward it never
paid, which is worse than the perk gap it was found beside, because a week's
mutagen is seen once and Adrenaline is seen every time the character sheet
opens.

Three functions could award XP and none of them was called. That is not a
coincidence — it is *why* nobody noticed. There is now exactly one,
`withMultipliers`, and the other two are deleted.

**The rules contradicted themselves, and the code and the UI were on opposite
sides.** `mutagens.dart` says at the top that a mutagen "is earned at one reveal
and modifies the *following* week". The panel on The Path said "Carried into the
week ahead". And `earnedMutagensProvider` read `allAchievements()` and folded
every perk ever unlocked into one set. Two documents describing a weekly perk,
one implementation of a permanent upgrade.

The perk reading won, for a reason that only shows up when you follow the other
one forward: a bonus summed over all history climbs to the `maxStackedBonus` cap
after about four good weeks and then never moves again. The mechanic would go
silent exactly when the user had been most consistent — the worst possible
moment for a reward to stop responding. And a perk that cannot be lost is not a
perk, it is a difficulty setting.

So `WeeksDao.mutagensForWeek(weekStart)` reads one week, and the providers split
in two: `earnedMutagensProvider` is the trophy case The Path lists, and
`activeMutagensProvider` is last week's, which is what the maths reads. The
panel now lists everything earned and dims what is not in force, because a perk
that was earned was still earned — hiding it would read as confiscation.

> [!warning] The regression that would undo this silently
> Sealing a fully logged week **grants Green Blood for that same week**. Under
> the all-time reading the bonus would find the perk the seal had just written
> and pay it immediately — a week rewarding itself. There is now a test that
> seals, deletes the week row, seals again, and asserts the XP is identical.

**Reading by week is also the only stable version.** `earnedBy` deliberately
takes the *frozen* summary so re-running it on an archived week always gives the
same answer. A bonus read from "whatever is in the table now" gives a different
answer every week, so a re-seal would quietly re-price an old week. Same reason,
one layer up. The seal reads the DAO directly rather than going through
`activeMutagenBonusProvider`, because that provider answers for *today* and a
week can be sealed days late.

**One multiplication, one rounding.** Adrenaline and the experience bonus act on
the same figure from different places, and applying them in two rounded steps
loses up to half a point each time *and* makes the answer depend on which went
first. A hundred XP at six days logged with a 20% perk is 171 rounded once and
172 rounded twice. A point of XP is nothing; a reward that depends on the order
of two multiplications is the kind of thing nobody can reason about a year
later. Pinned by a test with those exact figures.

**Where each effect landed.** `experience` at the seal. `adrenaline` raises the
`maxAdrenaline` *ceiling* rather than the figure — so at zero days logged the
multiplier is still 1.0 however many mutagens are in force, and a perk can never
pay for a week that was not lived. `purge` scales `Toxicity.dailyRetention`,
which meant turning three `const`-reading statics into functions that take a
retention.

**Alchemy reads the perk in force on the day it is showing, not today's.** The
toxicity meter can page backwards, and using the current bonus there would
rewrite what a past day looked like every time a new perk was earned. A day's
carry-over should read the same in a month as it does now — the same instinct
that makes `earnedBy` take a frozen summary.

**The providers moved out of the Bestiary.** T12b put them beside the creature
list because that task built both. Alchemy and the Reckoning both read them now,
and neither should have to import a screen about food to compute toxicity. They
live in `../lib/features/path/mutagen_providers.dart`.

**§1 check.** Nothing here is a verdict value: every mutagen condition is
behaviour rather than outcome (there is a test asserting none reads weight), and
XP, Adrenaline and Toxicity are all on the always-visible side of the table. The
bonus cannot carry the verdict onto a daily screen because it cannot see it.

**Verified:** `flutter analyze` clean, 816 tests green, `path_sheet.png`
regenerated and inspected — Green Blood gold and in force, White Honey dimmed,
the footnote naming only the active effect. It was the one golden that changed,
which is the check that nothing else moved.

---

## T25 — The level-up
**Date:** 2026-09-16

Planned in T11, dropped. Planned again in T12a, dropped. Ruled out of scope in
T21, whose animation budget went to day transitions. Fourth time scheduled and
the first time built. 816 → 826 tests.

**It needed no new state, which is why it kept looking harder than it was.**
The obvious design is a "has this level-up been seen" column, and that is a
schema version for a cosmetic. It is unnecessary: XP moves *only* when a week
seals, so both sides of the boundary are arithmetic over rows that are already
frozen. `levelUpFrom(xpBefore:, xpGained:)` is the whole mechanism.

**It belongs on the reveal, not the character sheet.** A level can only change
when a week seals, so animating it on The Path would mean animating a number
that did not move on the screen where it did not move.

**It reads the weeks *before* the one on screen, not the running total.** The
Reckoning pages backwards, and `totalXpProvider` answers for today. Building the
before-figure from `history()` filtered to earlier weeks means an old week
reports the level-up *it* caused rather than one it did not, or none when it did.
Same instinct as T24's read-by-week, and as `earnedBy` taking a frozen summary:
a screen that can look at the past has to compute the past.

**It renders nothing on an ordinary week.** Most weeks cross no boundary, and a
panel saying "no level this time" would make the ordinary case read as a
failure.

> [!bug] The arrow was a tofu box, and only the golden could see it
> The first draft rendered `3 → 4`. Both bundled fonts are *text* faces —
> Cinzel and EB Garamond carry no glyph in the arrows block, so it painted an
> empty rectangle. Every assertion passed: `contains('3')`, `contains('4')`,
> the blackout scan, all of them. `visibleText` reads `Text.data`, which is
> the string that *was asked for*, not the glyphs that came out.
>
> It is now the app's own diamond, painted rather than typed, with the old
> level small and dim and the new one large and gold. The size difference
> carries the direction better than an arrow did. There is a regression test
> rejecting any character in the arrows or geometric-shapes blocks, because
> the next person to reach for one will have the same idea.
>
> The general lesson: a widget test can only see text as data. **Anything about
> how text is *drawn* is a golden's job**, which is the argument for the golden
> carrying a level-up at all rather than the state nobody looks at.

**Motion.** A one-shot `TweenAnimationBuilder`, fade plus a 12px rise, over a
new `Motion.reveal` of 520ms — longer than a page turn because it happens at
most once a week on a screen the user came to deliberately, and still under a
heartbeat. Deliberately not a controller: this runs once, ends, and leaves
nothing animating. T21 spent a whole debugging round on a zero-opacity spinner
that never stopped and hung `pumpAndSettle` on every test that mounted the
screen; there is now an explicit `hasRunningAnimations` assertion so that
failure mode is named rather than merely avoided.

**It replays if the week is reopened**, and that is a choice. The reveal is a
once-a-week destination; suppressing a replay costs the stored flag this task
was built to avoid.

**The fifth time a screen gaining a provider broke that screen's tests**, as in
T10, T11, T12b and T17 — though only *nearly* this time. `levelUpProvider`
returns before touching the database when there is no archived week, which is
what every existing `reckoning_screen_test` case passes, so they went on
passing. The golden was the one that would have reached a database it has not
got. Both now override it, and the revealed golden carries a real crossing so
the mark is reviewable without a device, per §5.

**Verified:** `flutter analyze` clean, 826 tests green, `reckoning_revealed.png`
regenerated and inspected — twice, which is how the tofu was caught.

---

## T26 — The Bestiary plate
**Date:** 2026-09-16

`imagePath` has been carried from Open Food Facts into `Creature` since T12b and
rendered by nothing. 826 → 839 tests.

**It is a URL, and that is the whole difficulty.** `Foods.imagePath` holds a
remote address, so "render the image" means network I/O on a screen
`../CLAUDE.md` §4 requires to work with no key and no network. The answer is the
one the food library already uses for everything else: resolve once, write it
down, never fetch again. `CreatureImageStore` downloads to
`<documents>/creatures/<foodId>`, and **the file existing is the cache hit** —
no index, no schema change, and a cache that can be deleted at any time without
losing anything that is not re-fetchable.

**No new dependency.** `cached_network_image` would have pulled in
`flutter_cache_manager` and with it `sqflite` — a second SQLite in an app with
strong opinions about the first one (§3) — to do less than a hundred lines does.
`dio` was already here for OpenRouter and `path_provider` for the database.

**Every failure is silent.** Offline, a 404, an empty body, a redirect to an
HTML error page, no writable documents directory: all of them return null and
the sheet renders without a plate. The picture is decoration; the entry is the
content, and nothing on this path is the user's to act on. The terminal
`catch (e)` is the same reasoning as T16's widened guard — upstream is
crowd-sourced and its failure modes are not ours to enumerate.

> [!warning] The one failure a cache cannot recover from
> A half-written file that merely *exists* would be served as a hit for the life
> of the install — one interrupted download and that food's plate is broken
> forever, with no way for the app to know. So the bytes are written to
> `<name>.part` and renamed, which is atomic, and the partial file is deleted on
> the way out. Tested by failing a download and asserting the cache directory is
> empty afterwards.

**The widget takes an `ImageProvider`, and that seam is the reason any of this
is testable.** `FileImage` and `MemoryImage` both decode through
`instantiateImageCodec`, which needs a real event loop — and a widget test body
runs in fake async that never turns one. The same trap as drift queries in
`testWidgets` (§2), reached from a completely different direction, and it fails
the same way: the image never arrives, the frame renders empty, and a golden
records the wrong thing *while passing*. `PaintedTestImage` rasterises with
`toImageSync` and is ready on the first frame. `creaturePlateProvider` hands back
an `ImageProvider` rather than a `File` precisely so a test can substitute one.

**The Bestiary had no golden at all**, which is how a field could be carried into
a domain object and rendered by nothing for four tasks with nothing noticing. It
has one now. That is also the only way to review the *treatment*, which is the
part that mattered: a supermarket photograph on void black fights every other
surface in the app, so the plate is desaturated to 45%, dimmed, sunk behind a
gradient scrim that fades into the panel, and framed in the creature's own
rarity colour. Whether that works is not something an assertion can read — which
is the argument §5 is making when it asks for a golden rather than a test.

**`remote_food.dart` was documenting something that never happened.** Its comment
said "T9 writes local capture paths into the same column". Nothing has ever
written a local path to `Foods.imagePath`; T9 writes entries, not foods. Left
alone it would have made the column ambiguous exactly when this task needed it
not to be. Corrected rather than deleted, because the wrong claim is worth
recording next to the right one.

**Not done here:** the list row still has no thumbnail. T12b's note that "the
card has no room for it as drawn" is still true of the row and was never true of
the sheet, which has the width.

**Verified:** `flutter analyze` clean, 839 tests green, `design_gallery.png` and
the new `bestiary_creature.png` generated and inspected. `flutter build apk
--release --target-platform android-arm64` succeeds and
`python tools/check_apk_libs.py` passes — the first run of the build command the
README gained in T23.

---

## T27 — Asking what the key is worth
**Date:** 2026-09-16

Reported from use: *"my key is 10 bucks prepaid so it has a 1000 request limit,
but the app says 50."* 839 → 848 tests.

**The seventh instance of this project's one recurring fault.** Everything was
built. `AiCallsDao.paidDailyLimit` is 1,000 and has been since T8. `budget()`
takes a `hasPurchasedCredit` flag and picks between the two caps.
`AiKeyStore.setPurchasedCredit` exists with a secure-storage slot behind it, and
`OpenRouterClient.budget()` reads it on every call. **`setPurchasedCredit` had
zero callers.** The flag could only ever be false, so the app told a funded key
it had fifty requests a day and refused, at request fifty-one, to read a meal
OpenRouter would have answered.

Same shape as `upsertWater` (T17), `estimatePortion` (T20), `applyToXp` and
`withAdrenaline` (T24), and `imagePath` (T26). The mechanism, the storage, the
constant and the branch — everything except the twenty lines that reach them.

**Asked rather than toggled.** A switch in Settings would have closed the gap in
a fraction of the code, and it would have been a question the app makes the user
answer about an account the app can see. `GET /api/v1/key` reports
`is_free_tier`, so binding a key now asks, and the answer is written to the flag
that was already there.

> [!note] Not a fifth AI purpose
> `../CLAUDE.md` §4 caps *inference* at four purposes and requires a deliberate
> decision to add a fifth. This asks no model anything — it reads account
> metadata, the way checking a balance is not a purchase. It is deliberately
> **not** written to `ai_calls`: that table is the generation budget, and
> recording a metadata read there would make the app spend a request to find out
> how many requests it has. There is a test asserting `usedToday` stays at zero.

**Unknown is not the same as free, and that distinction is the whole safety of
it.** Unreachable, a 401, a 500, a body with no `is_free_tier`, a field of the
wrong type, a reply that is not the shape at all — every one returns null and
leaves whatever is stored alone. Returning "free" on a failure would drop a
paying user to fifty requests because their train went into a tunnel. Six tests
cover exactly that, all asserting the paid cap survives.

Only one field is read. `usage` and `limit` describe money and move with
spending; the tier is what the request cap follows, and trusting one number
rather than three leaves less to be wrong about in somebody else's JSON.

**There is a "check the allowance again" button**, because the answer can change
without the key changing. Buying credit raises the cap on a key that is already
bound, and making someone delete and retype a credential to tell the app about
it would be absurd.

**The shared fake could not answer a GET.** `FakeOpenRouterAdapter` did
`Map.from(options.data as Map)`, and a GET has no body, so the cast threw a
`TypeError` — which the client's terminal catch swallowed into "unanswerable".
The first run of the new test failed for a reason that had nothing to do with
the code under test. Fixed at the fake, not worked around at the call site: it
is the only description of what the wire looks like, and it now describes both
endpoints.

**Verified:** `flutter analyze` clean, 848 tests green, `settings_bound.png` and
`settings_no_key.png` regenerated and inspected. Whether OpenRouter's reply
really carries `is_free_tier` is the one thing no test here can settle — the
fake is our description of the wire, not theirs. It fails safe either way: an
unrecognised reply leaves the cap where it was.

---

## T28 — The build command T23 got wrong
**Date:** 2026-09-16

T23 changed the README to `flutter build apk --release --target-platform
android-arm64`, on the reasoning that arm64 is the only target so there is
nothing to gain from building the other two. The reasoning was right and the
command does not do it.

T26 ran that command for the first time and the APK came out at 41.3 MB —
essentially the same as the three-ABI build it replaced. Opening it:

| ABI folder | `libapp.so` | libraries |
|---|---|---|
| `arm64-v8a` | yes | 8 |
| `armeabi-v7a` | **no** | 6 |
| `x86_64` | **no** | 6 |

**`--target-platform` decides what Dart is compiled for, not what is packaged.**
Only arm64 carries `libapp.so`, so the app genuinely runs on one ABI — but the
plugin libraries for the other two are still in the file, because they arrive
from AARs and nothing asked Gradle to drop them. `check_apk_libs.py` has said
this all along, in the comment explaining why it keys on `libflutter.so` rather
than on plugin `.so` files: *"they arrive from AARs that ship ABIs the app
itself was never built for."* The evidence for this mistake was written down in
T22, four commits before the mistake was made.

`--split-per-abi --target-platform android-arm64` builds **one** APK containing
only arm64, at 28.9 MB — 12 MB smaller, and what T23 meant to say. Both figures
measured, not estimated.

**`check_apk_libs.py` would have quietly stopped checking anything.** Its
default was the single path `app-release.apk`, which `--split-per-abi` never
writes; it reports a missing file as a failure, so the corrected command would
have failed the check on a file that was never supposed to exist. It now looks
for every release APK a documented command can produce, checks the ones that are
there, and fails only when none is.

**The lesson worth keeping.** T23's own entry is about a README that described a
build sequence nobody had run. The fix asserted a different sequence — also
without running it. A build command in a document is a claim about a binary, and
the only way to check a claim about a binary is to open the binary.

**Verified:** both commands run, both APKs opened and their ABI folders listed.
`python tools/check_apk_libs.py` passes on all four release APKs present. No app
code changed; `flutter analyze` clean and 848 tests green, unchanged.

---

## T29 — The photograph, kept
**Date:** 2026-09-16

`Entries.photoPath` was declared in T9 and written by nothing. The photo path
compressed a picture, sent it to a vision model, logged the items it came back
with, and dropped the picture on the floor. 848 → 862 tests. This closes
[[92-Mechanics-Plan]].

**The bytes kept are the bytes sent.** `ImagePrep.prepare` had already
compressed, re-encoded and — importantly — **stripped EXIF**, which is where a
camera photograph carries the GPS coordinates of the user's kitchen. It then
returned only the data URI and discarded the JPEG. It now returns both. So the
copy on disk is the smallest version that still shows the meal, it cannot carry
a location, and there is no second compression to disagree with the first.

**Every entry from one photograph carries the same path.** A dish breaks into
its components and they are all separate rows; each of them genuinely did come
out of that picture. The precedent is one line away — `rawText` already writes
the same note onto every row from the same photo.

**It is written on logging, not on reading.** A picture that was read and then
discarded leaves no file: a souvenir of a meal that was never logged is just
litter.

> [!important] The column holds a *relative* path
> An absolute path is a fact about where the app happened to be installed, and
> it stops being true the moment that changes — which is exactly the situation a
> restored backup is in. `meals/<stamp>.jpg`, resolved against wherever the app
> lives now, cannot go stale that way. The stamp's colons are replaced, because
> they are legal in an Android path and not in a Windows one, and the tests run
> on Windows.

**A missing photograph is an ordinary answer.** The mirror holds table rows and
`Journal.md` — no binaries — so after a restore *every* `photoPath` names a file
that is not there. The entry is still true; only its souvenir is gone, and an
error where a picture used to be would be a worse answer than silence. That is
the correct trade rather than a gap: photographs in the JSON mirror would bloat
a file whose whole point is that it can be opened in Obsidian and read.

**Orphans are swept, and that needed thinking about.** One picture belongs to
several entries, so deleting an entry cannot delete the file — no single
deletion knows whether the others are gone too. Without a sweep the orphans stay
for the life of the install, which is the difference between a feature and a
leak. `JournalDao.photoPathsInUse` gives the whole answer in one distinct query
and `MealPhotoStore.prune` deletes what is not in it, at the same moment the
backup mirror is written: the user has finished changing things and the process
is still alive. The store takes the set rather than querying itself, because a
file store that knew how to read entries would be two things at once.

**A widget that renders nothing still answers a finder.** `MealThumb` returns
`SizedBox.shrink()` on a null image, and the first version built it
unconditionally — so `find.byType(MealThumb)` found it on a typed entry and the
test asserting the opposite failed. Guarded at the call site now, the way
`_Plate` already does it, so **being in the tree means there is a picture**.
Worth recording beside T25's tofu box: both are a test seeing what was *asked
for* rather than what was *drawn*.

**The treatment moved into the theme.** T26's desaturation matrix was private to
`CreaturePlate`; the thumbnail needed the same one. It is `Filters.weathered` in
`tokens.dart` now, for exactly the reason §5 gives for colour: a photograph is
the one thing in this app that does not come from the palette, so it is pulled
towards it in one place rather than two. Both primitives sit in the design
gallery, one above the other, so they can be compared rather than remembered.

**Out of scope, deliberately:** attaching a photograph on the manual and barcode
paths. The column allows it; the picker flow for it is separate UI, and this
task was about the picture the app already took and threw away.

**Verified:** `flutter analyze` clean, 862 tests green. **No golden changed
except the gallery**, which is the check that the claim holds: the Journal
golden's entries were typed, so nothing on it should have moved, and nothing
did.

---

## T30 — The digits the scan threw away
**Date:** 2026-09-16

Two products scanned off a Moldovan shelf came back with nothing: Banzai salted
almonds and a Monster Energy Ultra. The sheet said so — T21 already made sure a
miss was visible rather than painted behind the sheet — and then discarded the
one thing the user could act on. 862 → 868 tests.

**A barcode miss is a claim, and the user could not check it.** Open Food Facts
answers to the number, not to the packet. Without the digits on screen there was
no way to see whether the code was genuinely absent, to look it up on another
device, or to file it upstream later. `_ScannedSigil` shows it, selectably, with
a copy button — and the copy button acknowledges itself, because a clipboard
write is invisible and an unacknowledged one looks broken.

**The digits outlive the offer to write the food down.** `_scannedCode` is held
apart from `_offerToWrite` for the `BarcodeOffline` branch: there is no food to
name, so there is nothing to offer, and there is still a barcode worth keeping.
`_say` now takes the code and **clears it when absent**, so a notice from the
model or a failed write-back cannot inherit the number from the last scan.

**Searching for the name upstream did give.** A `ProductUnusable` carrying a
name now offers `SEEK "<name>"`, which fills the search box and runs the normal
order — library first, then the wider ledger. The barcode is one packet and
upstream has failed it; the name reaches the rest of the brand, where somebody
may well have filled a sibling code in. Offered **only** where there is a name:
a nameless product gets no button, because one searching for `""` would be a
dead end wearing a way out.

**What the two products actually are, checked against the live API:**

- `4840811001867` (Banzai almonds) — `product_not_found`. A clean miss. The
  brand *is* in Open Food Facts on the Moldovan `484` prefix, but seeds, not
  almonds.
- `5060947547162` (Monster Ultra) — **found**, and holds `countries_tags:
  ["en:moldova"]` and nothing else. No name, no brands, no nutriments. It takes
  the `UnusableReason.noName` branch, not the unknown one.

So the two failures were never the same failure, and the second one is an empty
row upstream waiting for exactly what the manual sheet already collects. That is
the argument for the contribute-back task, and the reason these two barcodes are
written down here.

**Country tags were considered and rejected as a fix.** Binding a country to a
product cannot find a product that is not there — filtering only ever shrinks a
result set, and this one is empty. The GS1 prefix already carries the signal
(`484` is Moldova; it is how the Banzai rows were found). A country field earns
its place in *ranking name search*, which is a different feature from the one
that failed, and it is never bound to a shop: where the user buys food is
personal location data and §6 keeps that out of this repo.

**Verified:** `flutter analyze` clean, 868 tests green. No golden changed — the
notice only exists after a scan, and no golden scans.

---

## T31 — Reading the packet
**Date:** 2026-09-16

T30 made a failed scan legible. This makes it recoverable: photograph the
nutrition table and the manual form fills itself. 868 → 891 tests. The fifth
permitted AI use, taken deliberately — see [[05-AI-Layer]] for the budget
argument and CLAUDE.md §4 for the rule it changes.

**The cost is bounded by the write-back, not by discipline.** A reading saves a
`FoodSource.manual` row, which outranks every other source in
`FoodsDao.upsert`, so nothing later replaces it. One call per new product for
the life of the install, falling to zero for a pantry that stops changing. That
is what made a fifth use arguable at fifty requests a day; a per-log cost would
not have been.

**The prompt is written against invention, not against refusal.** A model that
declines to read a blurry panel costs a call and nothing else. A model that
reads half of one and completes the rest from what that product usually
contains produces a row the user will never think to doubt — and it is
permanently authoritative. So `labelSystem` says *transcribe*, says *do not
recall*, and gives `readable: false` as an explicit way out, and
`AiDecode.label` believes it. `labelUser` passes the barcode as identification
while telling the model to read the printed table regardless of what it knows
of that code.

**Nothing is saved by the reading.** It fills fields; the user presses
INSCRIBE. The panel above the form says the figures came off a photograph and
asks to have them checked, because a form that filled itself silently would be
indistinguishable from one that was typed — and what is saved here outranks
everything.

**Three fields the form should always have had.** Sugars, saturates and sodium
are on every EU nutrition table beside the four that were there, and all three
feed Toxicity and Vitality. A food written by hand scored as though it
contained none of any of them, which is not a missing figure but a wrong one.
Folded into this task rather than split out: a label reader that transcribed a
panel and then discarded half of it would be half a feature. NOVA and glycemic
index have no field and are held in state — saved only when a reading produced
them, so a hand-typed food still claims nothing it was not told.

**`photoPickerProvider`, and why the picker moved behind a function.**
[ImagePicker] reaches a platform channel that does not exist in a widget test,
so both photo screens were testable only up to the line where they ask for a
picture — which is one line before everything worth testing. Injecting the
whole step is the same answer `barcodeScannerProvider` gave in T21, and it also
removed the duplicate pick-then-read-bytes block from `PhotoMealSheet`. The
quality argument rides along: a meal is read for what is on a plate and can
afford 85, a nutrition table is read for small print, where JPEG artefacts land
hardest on the thin strokes that separate a 3 from an 8.

**Two test traps, both about ListViews.** `food_search_sheet_test`'s manual-entry
test anchored `scrollUntilVisible` on a heading inside the sheet; the longer
form scrolled that heading out of the viewport, it was unmounted mid-scroll,
and the finder resolved to nothing. Anchored on `ManualFoodSheet` now, which is
there for the whole journey. The new suite hit the same thing from the other
side: the reader panel grows once it has filled the form, pushing the name
field off-screen, so those tests run in a view tall enough to hold the form and
stay about filling rather than about scrolling.

**Not done here:** contributing a reading back to Open Food Facts. That empty
Monster row from T30 is still empty, and filling it needs an account, opt-in and
credentials in secure storage. It is the next task.

**Verified:** `flutter analyze` clean, 891 tests green. No plugin was added, so
no APK check was required under §3 — `image_picker` was already a dependency.

---

## T32 — Giving it back to the ledger
**Date:** 2026-09-16

T30 made a failed scan legible, T31 made it recoverable. This closes the loop:
what the user writes down for a barcode Open Food Facts has never held is
offered back to Open Food Facts. 891 → 905 tests.

**The app does not submit, and that is the design rather than a shortcut.** The
ledger's write endpoint — `saveProduct(User, Product)` — authenticates with an
account **username and password**, sent on every call. There is no scoped token
to revoke. Submitting from inside the app would mean holding the user's whole
Open Food Facts credential on the device, next to the OpenRouter key but
materially worse: a key can be revoked alone, an account password cannot. The
data is worth contributing; the password is not worth keeping. So the app opens
the ledger's own add-product form and hands over a transcript to paste, and the
account stays where it belongs. This is now a rule in CLAUDE.md §2 rather than
a decision that could be quietly reversed later.

**It is offered at the only moment it can be.** The hand-off replaces the form
once INSCRIBE has written the row, rather than waiting for some later screen.
The person has the packet in their hand and the figures in front of them
exactly once; asking tomorrow is asking them to go and find the bag again. The
row exists before the offer, so declining costs nothing and NOT NOW still hands
the food back for logging.

**The transcript is shown in full, not summarised.** It is about to be pasted
into a public record and the moment to notice a wrong figure is before that.
`OffSubmission` is pure Dart in `domain/` so both the URL and the text are
tested without a device.

**Salt, and the one place a rounding rule mattered.** The form asks for salt,
every pack here states salt, the app stores sodium. Converting in code rather
than in someone's head is the difference between a contribution and a wrong
one — and salt alone prints at **two** decimals, because 0.05 g is an ordinary
pack figure and at one decimal it becomes 0.1, which is double. The first
version of this printed 0.95 g as `0.9`; that is the kind of error that is
invisible in an app and permanent in a database.

**A second hand-rolled channel, for the reason §3 already gives.**
`url_launcher` is a plugin, and §3 is a record of what a plugin that resolves
in pub but does not build on Android costs. Opening a web page is one intent,
so it is one intent in `MainActivity.kt` beside the storage one. It **refuses
any scheme but http(s) on both sides** — the handler is reachable by anything
that can talk to the engine, and an `ACTION_VIEW` that takes any scheme is a
wider door than it looks, since `file://` and `content://` intents read as the
app. It returns false rather than throwing when nothing takes the intent: a
phone with no browser is a thing to mention beside the transcript the user can
still copy, not a reason to unwind the sheet.

**One thing to watch:** `_readFailure` now carries both the label reader's
failures and the link opener's. It is cleared on entering the hand-off, because
a message about an unreadable photograph has nothing to say about filing a row
that was then typed by hand. Two fields would be cleaner if a third use appears.

**Verified:** `flutter analyze` clean, 905 tests green. Native Kotlin changed,
so `flutter build apk --debug` was run and `python tools/check_apk_libs.py
build/app/outputs/flutter-apk/app-debug.apk` passed — worth noting that the
checker's default list is release APKs only, so a debug build must be passed by
path or it silently checks stale artefacts instead.

## T33 — A version to ship under
**Date:** 2026-09-16

The app had `version: 1.0.0+1` in `pubspec.yaml` since T0 and had never moved
it, across thirty-three tasks and a release APK. That is not a version, it is a
default. This declares **1.0.0+1 "First Contract"** as the first stable release
and writes down the rule that keeps it moving. 905 → 910 tests.

**The scheme is in CLAUDE.md §9, not in someone's memory.** PATCH on every
commit, MINOR on a large change — a new mechanic, screen or data source, a
schema migration — MAJOR on a remaster, which is not expected soon and is
written down precisely because it will be improvised otherwise. BUILD rises by
one on every version change and never resets: Play refuses a `versionCode` it
has already accepted, and a reset after a MINOR bump would be exactly that
mistake.

**Three files carry the version, so a test holds them together.** `pubspec.yaml`
is what Gradle reads. `lib/version.dart` is what Settings prints. `CHANGELOG.md`
is what a person reads. Nothing at runtime notices when they disagree — the APK
would carry one number and display another, which is the worst possible state
for the one figure a bug report rests on. `test/version_test.dart` reads all
three and fails on a mismatch, so a forgotten bump cannot reach a commit.

**The constant is mirrored by hand rather than read with `package_info_plus`.**
The version is known at compile time; a plugin for it would buy nothing and
§3 is a standing record of what a plugin that resolves in pub and does not
build on Android costs. The mirror is safe because the test enforces it — this
is the same trade the project already makes for the storage and links channels.

**"The edition" sits last on Settings**, being the thing a person looks for
exactly once: when something is wrong and they need to say *which* app
misbehaved. It falls below the golden's viewport, which is acceptable — it is
not a new primitive, so the design gallery has nothing to add.

**Verified:** `flutter analyze` clean, 910 tests green. The settings goldens
were regenerated for the added panel (`flutter test --update-goldens --tags
golden`); no plugin was added, so no APK build was needed.

## T34 — Name what the count hides
**Date:** 2026-09-16

First task of the weekly-report series (see the plan). The Alchemy screen has
been reporting "Alchemical residue — 7 additives" since T6 and there has never
been a way to learn which seven. The E-numbers were on disk the whole time.
910 → 915 tests.

**The data was never missing, only discarded.** `foods.additives_json` stores
`["en:e150d","en:e338"]`, written from Open Food Facts since T5.
`nutrition_adapter.dart` called `jsonDecode(...).length` and passed an `int`
into `FoodPanel`, so by the time anything in `domain/` could see it there was
nothing left but a number. No schema change was needed for any of this — only
a wider pure type.

**`additiveCount` is now derived, not stored.** `FoodPanel.additives` is the
list; `additiveCount` is `additives.length`. Keeping both as fields was the
obvious alternative and is the wrong one: two fields that must agree
eventually disagree, and "7 additives listed" beside six names is exactly the
class of quiet nonsense this change exists to remove. Every *consumer*
compiled untouched because the getter kept its name; only the two producers
changed.

**The double-count, which is the real bug.** `NutrientTotals.of` did
`additives += s.food.additiveCount` — a sum across servings — although
`HarmLimits.additiveCount` has documented itself as "Distinct additives in a
day" since T6. The same food logged twice counted its additives twice; two
foods both listing E330 counted it twice. It is a `Set` union now.
`test/nutrition_test.dart` asserted the old behaviour outright (`expect(totals.
additiveCount, 12)` for one drink logged twice) — that test now asserts 6, and
a second one covers two foods sharing a code.

**What moved, and what deliberately did not.** Additives weigh 8 of the ~110
point pool in `_load`, which halves the clamped severity, so the daily
Toxicity figure falls by at most ~4 points and only on a day that repeats an
additive-bearing food. **Already-sealed weeks are unaffected** — `WeekArchive.
seal` early-returns on an existing row and `read` never recomputes, so history
does not edit itself. `alchemy_day.png` did not move at all, which was worth
checking rather than assuming: its fixture happens not to repeat such a food.

**Normalisation happens once, at the boundary.** `additiveCode` turns
`en:e330-citric-acid` into `E330` in `harm.dart`, and both adapters call it, so
nothing downstream ever has two spellings of one additive to reconcile. A tag
that is not an E-number comes back trimmed and otherwise untouched rather than
dropped — the column is crowd-sourced, and discarding an unrecognised tag
would under-report the one thing the user asked to see.

**One layout fault found by the change.** `_Stat` on the creature sheet put
its value in a fixed-width `Text`, which was fine for "45 kcal" and overflowed
by 229 px on six additive codes. It now uses the same `Flexible` 4/5 split
`_Weakness` twenty lines below it has always used — the duplication is worth
noting, because that is now three copies of this row shape in the app and the
weekly report will want a fourth.

**Verified:** `flutter analyze` clean, 915 tests green, `bestiary_creature.png`
regenerated. No plugin added, so no APK build.

## T35 — Read the week without opening the seal
**Date:** 2026-09-16

The descriptive half of the weekly report, as pure Dart. No UI, no provider,
nothing visible yet — `domain/week_pattern.dart` and its tests only.
915 → 944 tests.

**The seal is enforced by absence, not by a gate.** `WeekPattern` has no field
for an energy balance, an expenditure, a weight, a trend or a projection, and
the file imports neither `reckoning.dart`, `energy.dart` nor `sealed_value.
dart`. A widget cannot render a verdict from this type because there is
nowhere in it for one to be. That is strictly stronger than wrapping the
values in `SealedValue` and trusting the screen, because a screen can be got
wrong and a missing field cannot. A source-text test asserts the three
forbidden imports stay absent — crude, but it is the only thing that stops the
obvious future edit: *"just pass the DayEnergys in too, it's convenient."*

**Every guideline in `HarmLimits` is a daily one, and that shaped the whole
file.** A week's sodium measured against 2,000 mg reads as 700% severity, so a
perfectly ordinary week would be reported as a catastrophe. Curses are
therefore computed per day and then folded — `daysNotable`, `daysPastGuideline`,
`peakSeverity`, `meanSeverity` over *logged* days — and the only week-wide
`NutrientTotals` in the file is used for composition alone, with a comment
saying so at both ends. There is a test that eats 1,500 mg of salt seven days
running and asserts the week reports zero days past the guideline.

**Attribution is by the portion, never per 100 g.** `readFoodToxins` scores a
food at 100 g because a Bestiary entry is about what a thing *is*. A weekly
report is about what the week *was*, so 1 kg of porridge must outrank 5 g of
crisps on sodium even though the crisps are forty times saltier. Both
directions are tested, and the second one is the regression that matters.

**One definition changed under test.** "Clean days" first meant days with no
*notable* curse, and the count came back zero for a week of porridge:
`notableSeverity` is 0.05, a twentieth of the guideline, and a bowl of oats
trips "thick blood" at 38% of the saturated-fat limit. Notability exists to
keep trace readings off the Alchemy panel, not to define restraint. A clean
day is now one that passed no guideline at all — which is both earnable and
worth earning.

**Axii, and why its weekly mean is not a double-count.** Its consistency term
is `loggedDaysInWeek / 7`, which is identical on every day of a given week, so
the mean varies only by the glycemic steadiness term. Coherent rather than
wrong, and written down so nobody "fixes" it.

**`MealSlot` stayed in `data/`.** Yrden needs how many meal slots a day used;
the enum lives in `data/tables.dart`, and importing it would drag drift into
`domain/` for a count. `DayMovement.mealSlotsUsed` is a plain `int` and the
adapter will do the counting.

**Verified:** `flutter analyze` clean, 944 tests green. No goldens touched —
nothing renders yet.

## T36 — Tendencies, goods and bads
**Date:** 2026-09-16

The second pure file: `domain/week_findings.dart` turns a `WeekPattern` into
statements a person can read. Twenty-one of them, in two tones. 944 → 963
tests.

**Both tones, and the cap is per tone rather than overall.** A single sorted
list would let warnings take every slot in a bad week, and the report would
become a scolding — which §7 rules out in substance, not only in wording. So
`topFindings` takes a `Tone` and caps at three, and a week of nothing but
crisps still has its boons read out. There is a test for exactly that.

**The guideline travels with the accusation.** Every warning resting on a
published figure carries it in `Finding.basis`, verbatim from `HarmKind.basis`
— the rule `_Curse` has followed on Alchemy since T6. A test enumerates which
codes rest on a guideline and fails if one of them accuses without stating the
figure.

**`FindingCode` exists so the tests outlive the prose.** The wording will be
revised; assertions on strings would have to be revised with it. Tests assert
on the code and on the *rules* the wording must obey.

**Two wording rules, and the second one found something real.** The first
forbids *should / try to / aim for / next week / healthy / unhealthy / risk of
/ diagnos*. The second forbids stating a direction — and it failed twice, both
times on a unit rather than a leak: "14 g of fibre **per 1000 kcal**" and
"1.6 g of protein **per kg**".

That is worth writing down, because the easy move was to ban the tokens and
reword around them. **A density is not a quantity.** "14 g per 1000 kcal" says
how the food was composed and contains no amount of anything; "1,850 kcal a
day" is an amount, and a reader who knows their own expenditure subtracts it
into a verdict in their head. "81.4 kg" is the verdict outright. So the test
now strips the two density units the nutrition engine actually uses and then
asserts neither token survives — the unit is allowed, the amount is not, and
the distinction is written down rather than left to whoever adds the next
finding.

**One threshold is asymmetric on purpose.** Salt needs to pass the guideline on
*half* the logged days before it is called a tendency; sugar and saturated fat
need two days. Sodium is over the WHO figure in most western diets on most
days, so a lower bar would fire every week for everyone and stop meaning
anything.

**Verified:** `flutter analyze` clean, 963 tests green. No goldens — still
nothing rendered.

## T37 — The tale the app can tell itself
**Date:** 2026-09-16

The third pure file: `domain/weekly_tale.dart`, the week as prose. Still no UI
and still no AI — this is the shape both writers will fill. 963 → 978 tests.

**Two sources, one document.** `TaleSource.written` is a model, once, at the
seal. `TaleSource.told` is the app, from its own figures, for a user with no
key, no network or no allowance left. They share the section titles
deliberately, so the reader is looking at the same document either way and the
provenance line is the only difference. §4 demands the app stay fully usable
without AI; an empty second mode would have failed that in spirit while
passing it in letter.

**The seal is kept in two places, and they are different places on purpose.**
`tellPattern` takes only a `WeekPattern` and its findings, neither of which
has a verdict field, so it is safe on any day. `tellVerdict` takes
`NarrativeFacts`, which cannot be constructed from a week that has not closed.
The app's own prose and the model's prose are therefore locked by **one** rule
rather than two that could drift apart — which is the whole reason the
fallback takes the same guard type rather than reading the `Reckoning`
directly.

**Decode accepts three shapes, and the middle one is why there is no
migration.** Structured JSON is what this version writes. A **plain
paragraph** is what every week sealed under 1.0.x holds, and it comes back as
a single section rather than as nothing. Null or unreadable comes back null.
Malformed JSON falls through to being shown as prose rather than discarded: a
stored account is worth showing imperfectly, and there is exactly one of them
per week and no way to get it again.

**The same density-versus-quantity rule as T36**, now applied to prose. The
Tale's pattern half is rendered mid-week, so its test strips the two density
units and then asserts that neither `kcal` nor `kg` survives.

**Verified:** `flutter analyze` clean, 978 tests green. No goldens.

## T38 — The week, live
**Date:** 2026-09-16

`weekPatternProvider` wires the three pure files to the database. Still no UI.
978 → 990 tests.

**It watches neither of the providers you would expect it to.** Not
`weekReckoningProvider`, because the open half must not be able to reach a type
full of sealed values — the moment it can, something eventually reads one. It
derives its own week boundaries from the gate instead. And not
`archivedWeekProvider`, which returns null until the week closes and would
make the whole report vanish six days out of seven, which is the exact gap
this feature exists to close.

**It recomputes from the journal every time, and that is a deliberate
departure from "a sealed week is history".** The freeze in `WeekArchive`
exists so a later change to the *scoring maths* cannot rewrite a verdict the
user was already told, and so XP and mutagens cannot be re-awarded. A
description of what was eaten is neither. Nothing in `WeekPattern` feeds
`awardXp` or `earnedBy`, and the doc says that has to stay true — if it ever
changes, this must be frozen with the rest.

It is also the only way an old week shows anything at all. Every week sealed
before today holds a `summary_json` that predates all of these fields and would
decode to zeros forever. There is a test that shifts back three weeks and
reads a full pattern out of a sealed one.

**`MealSlot` stayed in `data/`, as T35 said it would.** `mealSlotsByDay` counts
the distinct slots in the adapter and hands `domain/` an `int`.

**One new query.** `waterFor(Day)` existed; `waterInRange` did not, and reading
a week of water a day at a time would have been seven round trips for one
panel.

**The seal is now asserted at the provider, across all seven weekdays.** A
frozen clock, a real database, a week of salt pork, and the concatenation of
every finding and every Tale section checked for *kcal, kg, losing, gaining,
deficit, surplus, expenditure, burned, tdee, projected, falling, rising* —
after stripping the two density units, per the rule T36 established.

**Verified:** `flutter analyze` clean, 990 tests green.

## T39 — A switch that belongs to this world
**Date:** 2026-09-16

Two shared primitives, so T41 has something to build the two modes out of.
990 → 996 tests.

**`RunicTabs` is the app's first segmented control**, because there was no tab
bar, no segmented button, no toggle and no bottom nav anywhere in `lib/` — a
grep for all of them finds one `PageView`, in onboarding. The app navigates by
drawer and full route pushes, so a switch between two *readings of the same
screen* had nothing to reuse.

It is deliberately not a Material `TabBar`: no controller, no page view, no
sliding indicator. The caller owns the selection, exactly as `ChoiceList`
does, so the mode can live in a provider and a golden can be taken of either
state without driving an animation to settle first. Nothing in it animates —
engraved, not animated, and an implicit animation would be one more thing
`pumpAndSettle` has to outlive on every screen that uses it, which is the
lesson `_LevelUpMark` already carries from T21.

The chosen segment is drawn as a small panel lifted out of the strip: raised
fill, a lit bottom edge (the `_ChoiceRow` idiom turned through ninety degrees)
and half-length corner brackets on its two top corners. Unselected segments
get a short centre hairline between them so two of them do not read as one
wide button.

**`CurseLine` is an extraction, not a new design.** `_Curse` in
`alchemy_screen.dart` and `_Weakness` in `creature_sheet.dart` were
byte-for-byte identical, down to the comment explaining the 4/5 flex split and
the one about `bloodRed` being unreadable as text. The weekly report needed a
third copy, and three is where a shape stops being a coincidence.

**The proof it was faithful is in the goldens.** Only `design_gallery.png`
moved. `alchemy_day.png` and `bestiary_creature.png` are pixel-identical after
both screens were rewired through the shared widget, which is a stronger check
than reading the diff.

The gallery's viewport grew from 5400 to 6400 physical pixels for the two new
sections.

**Verified:** `flutter analyze` clean, 996 tests green, `design_gallery.png`
regenerated and inspected.

## T40 — Give the account something to account for
**Date:** 2026-09-16

The weekly narrative has been writing about five numbers since T8. It now sees
what was actually eaten. 996 → 1003 tests.

**`NarrativeFacts` is still the guard, and widening it did not weaken it.**
The null-check is on the `Reckoning`, not on anything new — and a
`WeekPattern` contains no verdict, so nothing about the descriptive half can
forge a revealed week. The existing test that walks all six sealed weekdays
and asserts `from` returns null is unchanged and still green.

**The pattern comes from the provider rather than being folded again.**
`archivedWeekProvider` already had the week's rows in hand and could have
computed it inline, but then The Tally and the account would each have their
own idea of the same week. One source, one answer.

**Four sections, and the absent fifth is deliberate.** `opening`, `the_table`,
`the_curses`, `the_boons`. No `closing`: that is precisely where a model
reaches for "next week, try…", which §7 forbids — and the app already supplies
its own closing, which is the disclaimer. Four rather than more, because
`_structured` records *every* attempt against the 50/day budget and each extra
required string is another chance a free model trips `strict`. If they start
failing in practice the note in `ai_schemas.dart` says to collapse to two
rather than retry.

**No migration, again.** The tale is `jsonEncode`d into the existing
`weeks.narrative` column, and `WeeklyTale.decode` already reads a 1.0.x plain
paragraph as a single section (T37). `AiDecode.narrative` also still reads the
old single `text` field, so an older *model reply* survives as well as an
older stored row.

**The prompt is capped at every turn** — five curses, ten additive codes, three
findings per tone — because a block that grows with the food library would
send a prompt several times larger for a heavy week than a light one, for no
extra insight. There is a test that logs 280 entries and asserts the prompt
stays under forty lines.

**The system prompt gained two rules that the new material requires.** It may
describe food but never call it healthy or unhealthy and never advise a
change; and it must use only the figures given, never naming an additive, a
food or a day that is not in them. It is now handed real food names and real
E-numbers, which is exactly the material a model embellishes if it is not told
not to.

**Still one call per week.** `WeekArchive.seal` early-returns on an existing
row, still swallows `AiFailure` to null, still never retries. The
`week_archive_test.dart` assertion that three seals produce one call is
untouched and green.

**Verified:** `flutter analyze` clean, 1003 tests green.

## T41 — The Reckoning remade: The Tally and The Tale
**Date:** 2026-09-16
**Version:** 1.1.0+9 — the first MINOR release.

The eighth and last task of the series. Week's End is a weekly report now.
1003 → 1017 tests.

**The spine never moves.** Week bar, then the verdict panel, then the switch.
Only what hangs below the switch changes. A mode that could hide *whether* the
week is sealed would be a far worse failure than showing the wrong tab, so the
seal is above the switch and not inside either view.

**The file split was not optional.** `reckoning_screen.dart` was 535 lines and
would have passed 1,500. It is now the shell (~140), `verdict_panels.dart`
(~350, everything that waits for the week to close), `tally_view.dart` (~500)
and `tale_view.dart` (~180).

**The narrowed test is the most important edit in this task, so it is written
down twice — here and in the test.** `reckoning_screen_test.dart` asserted
that no `Text` anywhere in the sealed tree matched
`[+-]?\d+([.,]\d+)?\s*(kcal|kg|%)`. The Tally prints `34%` macro shares and
`14 g per 1000 kcal`, so that assertion could not survive the feature — and
the tempting response was to delete it.

It was narrowed in two directions instead, and both are strictly enforced:

1. The `%` regex is **scoped to `VerdictPanel`**, the widget that actually owns
   the verdict. A macro share is a composition of the week's own energy and
   cannot be rearranged into a balance.
2. The whole-tree sweep is **kept** in the form that still holds: no *signed*
   kcal figure and no weight in kilograms, anywhere, in **either** mode.
3. The word-level loop is kept whole, with the two density units stripped
   first — the rule T36 established. `kcal` and `kg` are still forbidden
   across the entire screen everywhere they are not a unit of density.

The net guard is stronger than before, because it now runs in both modes.

**One attack test.** The Tale is handed an archived week containing the word
"kcal" on a Tuesday, through a deliberate provider override, and must still
show nothing. A screen that gates on whether its provider happened to return
something is one bad override away from printing a verdict mid-week; this one
gates on `reckoning.isRevealed`.

**Three faults the goldens caught that no test would have.**

1. The curse name was printed twice — once as a `StatBar` label and once as
   the `CurseLine` title. The bar moved into the line's trailing slot.
2. `13614 mg` — five digits with no separators, which a person has to count
   the columns of. `formatAmount` now groups thousands.
3. **`Carried by Salt pork (3,024 )`** — an unlabelled number that was
   *kilocalories* of ultra-processed food. It slipped past every leak test
   precisely because the empty unit meant the string never contained "kcal".
   Ultra-processed and additive carriers now name the food and stop. This is
   the best argument in the whole series for rendering the goldens and
   actually looking at them.

**A spinner nearly cost an afternoon.** The first loading state was a
`CircularProgressIndicator`, which animates for ever, so `pumpAndSettle` never
settled and every widget test on the screen timed out with no useful error —
the same fault CLAUDE.md §2 records from T21, reached by a different road. It
is a static line of lore now.

**Mode is not persisted.** A stored view preference is a schema version for a
cosmetic, which is the call `LevelUpMark` already makes about its replay flag.

**Verified:** `flutter analyze` clean, 1017 tests green. Four reckoning
goldens: `reckoning_sealed`, `reckoning_revealed`, `reckoning_tale` and
`reckoning_tale_sealed` — the last because it is the state nobody will look at
on a device and the one most likely to read as broken rather than as
deliberately locked. No plugin added, so no APK build.

---

## T42 — The meal parser had never worked
**Date:** 2026-09-18
**Version:** 1.1.1+10

Reported as "I tried describing my full meal into the ai module, but it errors
all the time." It was not the phrasing. Free-text parsing failed on almost
every attempt, for three independent reasons, and the flow was wrong in two
smaller places besides. 1020 → 1024 tests.

**Everything here was measured against the live API**, one request at a time,
with the app's own schema and prompts. None of it could have been found by
reading the code, and none of it can be regression-tested without a key — so
the numbers are written down here, and the behaviours they justify are pinned
by tests against the fake.

### 1. A model in the chain could never have answered

`inclusionai/ling-3.0-flash-vl:free` sat second in `defaultModels` from T8.
Its only provider is Novita, and `/api/v1/models/<id>/endpoints` does not list
`response_format` among its supported parameters. Every call:

```
HTTP 400 — {"reason":"INVALID_REQUEST_BODY",
            "message":"model features structured outputs not support"}
```

Recorded as a spent request, then fell through. For four releases. The app had
no way to tell that apart from a busy afternoon, which is the real lesson: a
permanent fault and a transient one looked identical from inside.

Replaced with `nex-agi/nex-n2.5-mini:free`. A search of the whole free catalogue
found only three models that are both vision-capable and schema-constrainable,
and all three are now the chain — there is no fourth to fall back on.

`provider: {require_parameters: true}` now goes on every request, which moves
the decision to OpenRouter's router. A provider that cannot hold the schema is
not routed to, rather than being routed to and then refusing.

### 2. The models were thinking rather than answering

The finding that actually fixed the feature. All three are reasoning models,
and each spent thousands of tokens deliberating before writing JSON whose shape
the schema had already fixed. One five-food line, same prompt, same schema:

| Model | Thinking | Time | Foods found |
|---|---|---|---|
| pro | on | cut off at 120 s, twice | none |
| pro | **off** | **17 s** | all six |
| mini | on | 60 s, 8,573 thinking tokens | four of six |
| mini | **off** | **4 s** | all six |
| dots-3 | on | 93 s, 7,227 thinking tokens | all six |
| dots-3 | **off** | **11 s** | all six |

`reasoning: {enabled: false}` costs nothing in quality — the reasoning-off
answers were the *more* complete ones. That is not a surprise. Nothing this app
asks is a problem to be solved; it is extraction against a schema that already
states the answer's shape. And thinking is billed as completion tokens, so a
runaway trace can crowd the reply out of the context entirely, which is exactly
how the mini returned four foods out of six after a minute of thought.

**The chain order was not the problem and is unchanged.** The pro reads a line
most accurately and, with thinking off, does it in seventeen seconds. It only
looked like the wrong thing to lead with while it was also the slowest.

### 3. The timeout was shorter than the models

45 s per model, against models then taking 60–120 s. Nothing in the chain could
finish inside it. Now 90 s per model, 180 s for the whole chain, with a model
skipped rather than started once less than a quarter of an attempt is left.

90 s looks absurd for a phone and is not. A working call is 4–17 s; the
allowance is for congestion, which is real — the same request measured at 4 s
once ran past two minutes on a busy afternoon, and one live verification line
took 85 s. Cutting a call short throws away an answer that was on its way
**and** spends the request, because OpenRouter bills the attempt, not the
result.

> [!note] The timeout must be wall-clock
> OpenRouter pads a long non-streaming generation with whitespace to hold the
> connection open. An idle-based timeout never fires against it — a probe using
> one hung for over ten minutes on a request `curl --max-time` killed at 120 s.
> `Future.timeout` is correct here and `receiveTimeout` would not be.

### 4. The failure message was an exception's toString

Every sheet prints `AiFailure.message` verbatim, so a user standing in a
kitchen was shown `TimeoutException after 0:00:45.000000: Future not
completed`. The two failures worth telling apart are *slow* and *refused* —
one is worth trying again in a minute and the other is not — so
`AiUnreachable` now switches on what the chain actually died of.

### 5. Two things the live runs exposed that no test would have

- **Nonsense units.** "a large coke" came back as *one slice*, a black coffee
  as *one bowl*, honey as *one slice*. The grams were right, so the entry was
  right and the journal still read like gibberish. The prompt now says the unit
  must be one a person would use for that food, and to fall back to grams with
  a figure when none fits. Re-measured after the change: coke → cup, butter →
  tablespoon, honey → teaspoon, coffee → cup, olive oil → tablespoon.
- **A one-gram wrap.** "chicken shawarma wrap" resolved to 1 piece weighing
  1 gram — the quantity written into the grams field. Four kilocalories, logged
  as though it were real. `MealResolver` now ignores a gram figure too small to
  be the portion it claims and uses the unit table instead. The floor is per
  unit and deliberately generous: a bowl or a piece is at least five grams, a
  teaspoon only has to be above nothing, because a teaspoon of yeast really is
  three grams.

**Verified:** `flutter analyze` clean, 1024 tests green. Five live meal lines
parsed end to end through the real client — plain, brand-named, vague
("idk just a big bowl of cereal"), non-English ("борщ со сметаной и кусок
хлеба") and hedged ("maybe half a plate of lasagna") — five calls, five
answers, no failures. No plugin added, so no APK build.

**The dev-machine `.env` was used for the live runs and nothing was committed
from it.** The key is still entered in-app into secure storage; nothing in
`lib/` reads `.env`, and the temporary probe that did was deleted. See
CLAUDE.md §2.
