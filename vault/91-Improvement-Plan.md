---
tags: [plan, backlog]
---

# Improvement Plan — first-use feedback round

> [!success] All six tasks shipped, T16 to T21
> See [[90-Progress-Log]] for what each one found. Three of the five reports
> turned out to be about things that already existed and could not be reached;
> the other two were single causes with wide blast radii. Six further issues
> found while reading were closed along the way.
>
> **Closed since:** the branch is merged to `main` (PR #1), and the
> update-survival pass came back clean — see the Verification section.
> **Still open:** the barcode check on a real label, and the four vault gaps
> listed at the foot of this note, now scheduled in [[92-Mechanics-Plan]].

Scheduled work after the first real-device shakedown of the T14 release build.
One entry per issue; each task lands as its own commit with its own
[[90-Progress-Log]] entry, per `../CLAUDE.md` §2.

> [!quote] What came back from use
> "Overall design is on point, I love the stats, I love the colour palette." The
> core holds. What broke were the edges — every path that crosses a network, a
> camera, or a search box.

Where an item was already recorded as a deliberate gap, the progress-log line is
cited. Issues 6–11 had never been written down anywhere but as prose inside a
1,100-line log, which is why this note exists at all.

---

## Three of the five reports were narrower than they looked

> [!important] Read this before picking up a task
> Two of the "missing features" are built and unreachable, and the barcode bug is
> not in the scanner.

**Photo → dish breakdown already ships.** `PhotoMealSheet` has done
camera/gallery → compress → base64 → vision model → `MealResolver` → logged
entries since T9. Its button renders **only when an OpenRouter key is saved**, so
on a keyless install both AI buttons are invisible. The work is discoverability,
not capability. See [[05-AI-Layer]].

**Water is half-built.** `WaterLogs`, `TrackingDao.waterFor` / `watchWater` /
`upsertWater`, and the Yrden sign all exist and are tested. `upsertWater` has
**zero callers**. No migration is needed — see [[04-Data-Model]].

**The barcode scan is not a camera fault.** The scan succeeds and returns the
code. The failure message is posted through the root `ScaffoldMessenger`, which
paints into the `JournalScreen` scaffold — *underneath* the opaque bottom sheet.
Both error strings are completely covered by void black. The user sees the
scanner close and nothing happen, which is exactly what was reported.

---

## The issues

### Reported from use

| # | Issue | Task |
|---|---|---|
| 1 | No animation anywhere. Day changes snap. | T21 |
| 2 | No way to log water or a drink. Yrden sits permanently low. | T17 |
| 3 | Search barely matches — see below. | T18 |
| 4 | A barcode scan resolves to nothing, silently. | T16 |
| 5 | Photo → dish exists but cannot be found, and its prompt is wrong for cooked food. | T20 |

**On (3).** `FoodsDao.search` is a single `WHERE search_key LIKE '%<whole
query>%'`. There is no tokenisation, so `white monster` cannot reach
`monster energy ultra white`; no quantity stripping, so `5 fried eggs` searches
for the literal string; and no plural handling, so `eggs` misses `Egg, whole`.
Three separate absences with one symptom.

### Found while reading

6. **`foodSearchProvider` is not `autoDispose` and never invalidates.** A
   repeated query serves a stale cached list, so a food just written by a barcode
   scan or a remote pick does not appear. Its sibling `remoteFoodSearchProvider`
   carries a comment explaining precisely why this is wrong. → T18
7. **`FoodsDao.search`'s doc comment promises ordering by `FoodSource`, and there
   is no ordering term on it.** An AI row at confidence 0.95 outranks a seed row
   at 0.9 — the exact inversion the comment says cannot happen. A good reminder
   that an SQL `ORDER BY` can stop expressing its own comment in silence. → T18
8. **`FoodSource.manual` is unreachable.** The strongest source in `upsert`'s
   precedence ladder has no UI that writes it, and there is no "add a food by
   hand" anywhere. A food Open Food Facts does not know is a dead end. → T19
9. **`estimatePortion` is dead code.** Client, schema, decoder, prompt and tests
   all exist; nothing calls it. `ResolvedPortion.worthRefining` is the hook it
   was built for and is unused, while Settings still advertises the feature.
   The vault records it as shipped in T8 — the wiring is the missing half. → T20
10. **Clearing the search box can be undone** by a debounce timer scheduled a
    moment earlier, because the clear button does not cancel it. → T18
11. **Yrden reads water with a one-shot query**, so the glyph would go stale the
    instant water was written. Latent until T17 gives water a writer. → T17

### Logged, still open, not scheduled here

Recorded so they are not lost a second time:

- Mutagen bonuses are computed and displayed but spent nowhere
  ([[90-Progress-Log]] T12b). Needs a design decision, not code.
- The Bestiary carries `imagePath` from Open Food Facts and never renders it.
- `Entries.photoPath` is declared and never written.
- The level-up animation, planned and dropped in both T11 and T12a. Out of scope
  by choice — this round's animation budget goes to day transitions.
- Device-only verification of the T13 backup/restore round trip.

---

## Tasks

### T16 — barcode: make the failure visible, then stop causing it

Three faults compound; fixing any one alone leaves it broken.

**The message is painted under the sheet.** Replaced with a notice rendered
*inside* the search sheet, matching the existing quiet-footnote idiom.

**A real product maps to null.** The mapper rejects a product whose English
`product_name` is empty, while the request pins the language to English and
narrows the requested fields. A product carrying only `product_name_ro` or
`_fr` arrives nameless — the likely fate of the salted almonds that prompted
this. The `openfoodfacts` package already ships `getBestProductName`, which
walks name-in-language → name → generic name → abbreviated name.

The no-energy rejection **stays**. Mapping a product with no energy figure to
`kcal: 0` adds a silent zero to the day's total, and the user would believe they
had logged their lunch. Refusing is the honest answer.

**Every failure looks the same, and half of them escape.** The lookup returns a
nullable food, which collapses four different outcomes into one `null`. It
becomes a sealed result — found, unknown upstream, found-but-unusable, offline —
so the sheet can say which happened. Sealed for the same reason the reveal gate
is: `non_exhaustive_switch_*` is an analyzer error, so a new outcome cannot be
silently forgotten. See [[02-Architecture]].

Two catches also widen. The remote guard catches only `Exception`, so a type
error from crowd-sourced JSON sails straight past it; the caller catches only
`RemoteUnavailable`, so a database error from the write-back escapes. In a
release build, with minification on, that is a failure with no output at all.

**Scanner feedback.** Haptic on detect, a mounted guard before popping, and the
barcode-decode error callback actually supplied — its default is a documented
no-op, so decode errors currently vanish. Without a haptic the user cannot tell
"never scanned" from "scanned, found nothing".

### T17 — water: the waterskin

No schema change. A quick-tap panel on the Journal, and one new rule.

**A food counts as a drink because of how it was logged** — its unit is
millilitres — since nothing on a food row marks it a liquid. Volume credits 1:1,
which is not a fudge: the millilitre unit already declares one gram per
millilitre, so the stored grams *are* the millilitres.

**Only alcohol discounts, and it discounts to zero.** No caffeine figure is
stored anywhere, so a coffee discount would be a number with no source. Alcohol
is stored, is a genuine diuretic, and crediting nothing is the simplification
that can never *overstate* hydration. One rule, computable from what is on the
row, and it keeps the §7 framing: lore, not a physician.

**No double counting.** The manual tap lives in `WaterLogs`; the drink credit
derives from `Entries`. Disjoint sources. One provider computes the total and
both the panel and the sign read it, so the glyph and the panel cannot disagree.

> [!warning] Two traps
> `WaterLogs` stores one total per day, so there is no log to undo — the minus
> button is a *decrement*, and should read as one. Anything better needs a
> per-sip table, which is not worth a schema version.
>
> A Journal test asserts that no text on the screen contains `/`, plus a banned
> word list including *target* and *goal*. A default progress bar renders
> `1500 / 2000` and **will fail it** — correctly, because an `x / y` ring is the
> progress framing this app refuses. Phrase it as "1,500 of 2,000 ml" and honour
> the test. Do not edit it.

Water is not a verdict value, so showing it plainly is safe. See [[01-Vision]].

### T18 — search: tokens, quantities, plurals

Match on tokens rather than one contiguous substring: every token must appear,
in any order. Strip a leading quantity and carry it into the portion sheet.
Normalise plurals.

> [!tip] Why no migration is needed
> The match is *containment*, not equality, so the plural rule does **not** have
> to be symmetric. Stem the **query only**, never the stored key, using a purely
> *truncating* stem — then `eggs → egg` matches both a stored `egg whole` and a
> stored `scrambled eggs`. The stored key's contract is untouched, and there is
> no re-key pass and no schema bump.

Matching lives in `domain/` as pure Dart so the rules are testable without drift
and without Flutter, with the DAO building its SQL from them. The tier ranking is
done in Dart rather than SQL for the same reason — and because issue 7 is proof
of how quietly an SQL ordering stops meaning what its comment claims.

The leading-quantity parser stays deliberately small: digits, an optional glued
or following unit word, and a short fixed vocabulary of number words. Number
words are not indulgence — since *every* token must match, an unrecognised
leading `dozen` would block the whole query and return nothing, which is strictly
worse than today. Anything richer already has a home in the free-text path, and
turning the search box into a second parser duplicates it.

One guard worth stating: a bare number means "5 of them", not "5 grams". Trust
the parsed quantity only when the query named a unit or the food has a piece
weight, or `5 fried eggs` prefills five *grams*, which is worse than the
current default.

### T19 — add a food by hand

Closes issue 8, and gives T16's found-but-unusable outcome somewhere to go:
offer to record it yourself, prefilled with whatever name and barcode came back.

`upsert` already refuses to let a weaker source overwrite a stronger one, so a
hand-entered row is permanently authoritative. That ladder has been in place
since T2 with nothing able to reach its top rung.

Reachable from two places: the unusable-barcode notice, and the search sheet's
empty state — which is currently a dead end whenever there is no key and no
network.

### T20 — the photograph, made findable

**The AI buttons render always.** With no key, tapping one explains what the
model would do and offers a route to Settings.

The existing rule — *"a button that always fails is worse than no button"* — is
sound reasoning that produced the wrong outcome here. A capability nobody can
discover is worse than one that explains itself, and a disabled-with-a-reason
button is neither of the two cases that rule was weighing.

**The photo prompt is wrong for cooked food.** It currently forbids inferring
anything not visible, which is right for a plated meal and wrong for a stew,
where the components are by definition not individually visible. A composite
clause: name the dish, break it into its ordinary components, and lower the
confidence for anything inferred rather than seen. The note field already exists
and is where the cook says what they made — worth surfacing, since their own
description outweighs anything the model can infer from pixels.

**Portion estimation gets wired** (issue 9), offered on an entry the user has
already flagged as vague.

> [!note] No fifth AI use case
> `../CLAUDE.md` §4 caps AI at four purposes and requires a deliberate decision
> to add a fifth. None is added here. Photo → items already ships; this completes
> the second purpose, which Settings has been advertising since T8. The budget
> maths is unchanged. See [[05-AI-Layer]].

### T21 — motion

Slide and fade on a day change, direction following the arrow, plus four small
polish points. Restrained on purpose: a short duration and a very small slide is
a page being turned, not a Material route. See [[03-Game-Design]].

**Not a swipeable `PageView`, and the reason is not the index arithmetic.** Six
providers read the *global* day cursor rather than a page's day. A page view
builds the adjacent page before the cursor moves, so the incoming page would
render the current day's numbers and then flicker to the right ones. Making it
honest means re-keying all six providers by day and touching every one of their
tests — its own task, and the right one to do first if swipe-to-change-day is
ever wanted.

> [!bug] The blank frame is worse than a loading flash
> When the cursor moves the entries provider is recreated, and in Riverpod 2
> `whenData` on a loading state yields a plain loading state — previous data is
> **not** carried through. The body falls to its empty arm and blanks. Worse, the
> totals are a separate provider with their own empty fallback, so a partial fix
> shows the old day's rows beside zeroed totals.
>
> The fix is to make a rendered page one atomic value, hold the last settled one,
> and ignore loading frames. The body then lags the date header by one query,
> which is deliberate: a page that slides in late beats one that slides in empty
> and then fills. Comment it, or someone will "fix" it back into a flicker.

Motion goes in the theme tokens, so timing is as centralised as colour.

---

## Order

```
T16 barcode             the reported breakage; highest user cost
T17 water               self-contained; regenerates the Journal golden once
T18 search              self-contained; largest test surface
T19 add by hand         needs T16's unusable outcome and T18's empty state
T20 photo + portion AI  needs T19 for its "record it yourself" fallback
T21 motion              last: invisible at rest, so it touches no golden
```

T17 before T21 keeps the Journal golden regenerating once rather than twice, and
keeps the animation commit free of layout diffs.

---

## Verification

`flutter analyze` clean **and** `flutter test` green before every commit — the
analyzer alone is not sufficient, for the reason in `../CLAUDE.md` §2.

Five things only a phone can answer, and they are the five that were reported:

1. Scan the salted almonds again. Expect the food added, or a **visible** notice
   naming which outcome occurred. Then scan in aeroplane mode: expect the offline
   notice, not silence.
2. Type `5 fried eggs`, `white monster`, and `eggs`. All three currently return
   nothing useful.
3. Tap `+500` twice; confirm it survives an app restart and that Yrden has risen.
4. With no key saved, confirm the camera button is visible and explains itself.
   With a key, photograph a cooked dish and confirm it breaks into components.
5. Page back and forward through several days; confirm no blank frame and that
   the direction follows the arrow.

The update-survival check — install over the previous build, confirm the database
and the backup mirror survive — is a separate pass, best run after T17, since
that is the only task in this round that writes a table nothing wrote before.

> [!success] Answered on the phone, 2026-09-16
> **The update survives, and so does the backup.** Installed over the previous
> build — including over the SQLite-less one from 09-15 — and the database came
> through intact. The backup mirror was exercised as well and round-trips. That
> closes both the update-survival pass and T13's device-only verification, the
> two largest unknowns this note carried.
>
> Worth keeping: the broken build was recoverable by installing over it. A
> missing native library is a *runtime* failure, so nothing on disk was harmed
> and no data was lost — which is the reason to keep the debug signing key
> stable more than any other.
>
> **Still unanswered: item 1.** The barcode fix has not met a real label yet.
> Items 2–5 have not been reported back on individually.
