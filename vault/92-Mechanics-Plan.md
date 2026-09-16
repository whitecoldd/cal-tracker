---
tags: [plan, backlog]
---

# Mechanics Plan — the gaps that outlived the first round

Four things the app computes, stores or carries and then does nothing with.
Each has been recorded at least once in [[90-Progress-Log]] and scheduled zero
times; [[91-Improvement-Plan]] listed them at its foot and closed without them.
They are scheduled here, in the order asked for.

One entry per task; each lands as its own commit with its own
[[90-Progress-Log]] entry, per `../CLAUDE.md` §2.

> [!quote] What these four have in common
> None of them is a missing feature. In every case the hard half — the maths,
> the schema column, the remote field, the frozen summary — was built and
> tested, and the last twenty lines that would make it visible were never
> written. That is the same shape as T17 (`upsertWater`, zero callers) and T20
> (`estimatePortion`, dead since T8), and it is worth naming as a pattern
> rather than meeting it a fifth time: **this project reliably builds the
> mechanism and forgets the wire.**

---

## A fifth dead path, found while planning

`withAdrenaline` in [progression.dart:154](../lib/domain/progression.dart#L154)
**has no callers.** Adrenaline is computed from the last week's logging,
displayed on The Path, and multiplies nothing. `awardXp` at
[reckoning_providers.dart:213](../lib/features/reckoning/reckoning_providers.dart#L213)
is used raw.

So the reward chain is disconnected at *both* joints — Adrenaline and mutagens —
and a user who logs seven days out of seven is told they have earned a ×1.5
multiplier that does not exist. That is worse than the mutagen gap, because
Adrenaline is on a screen the user opens every day.

It is folded into T24 rather than given its own task: both faults are one
missing multiplication at one call site, and fixing one without the other means
touching that line twice and regenerating `path_sheet.png` twice.

---

## Tasks

### T24 — Perks that are actually spent

> [!success] Shipped
> The decision went to **the previous week only**. See [[90-Progress-Log]]
> T24 for what it found, including the regression where a week that earns
> Green Blood would have immediately paid itself with it.

**What exists.** `MutagenBonus.applyToXp`
([mutagens.dart:149](../lib/domain/mutagens.dart#L149)), `withAdrenaline`,
`bonusOf`, `earnedBy`, the `achievements` table with a `weekStart` on every
row, and a Path panel that displays the bonus. All tested. Nothing spends any
of it.

**Which weeks count — the decision.** `mutagens.dart`'s own library doc says a
mutagen "is earned at one reveal and modifies the *following* week".
`earnedMutagensProvider`
([bestiary_providers.dart:98](../lib/features/bestiary/bestiary_providers.dart#L98))
reads `allAchievements()` and folds every perk ever earned into one `Set`. Those
are different mechanics, and only one of them can be right.

| | The previous week only | Every week ever (what the code does) |
|---|---|---|
| Matches the documented contract | yes | no |
| A perk can be lost | yes | no |
| Behaviour after ~4 good weeks | still moves | pinned at the `maxStackedBonus` cap, permanently |
| What it *is* | a perk | a difficulty setting |

**Recommended: the previous week only.** The cap argument is the decisive one —
under the all-time reading the mechanic goes silent exactly when the user has
been most consistent, which is the worst possible moment for a reward to stop
responding. It also restores the thing that makes a weekly loop a loop: last
week has to be paid for again.

This needs `WeeksDao.achievementsForWeek(Day weekStart)` beside the existing
`allAchievements`, and `earnedMutagensProvider` splits in two — the Path's
"perks you have collected" (all-time, a trophy case) and the active bonus (last
week, a live modifier). **The Path panel must then say which of the two it is
showing**, or it goes on quietly lying in the other direction.

**Where each effect lands.**

- `experience` → at the seal, wrapping `awardXp` in `reckoning_providers.dart`.
- `adrenaline` → raises the `maxAdrenaline` ceiling, today a bare `const 1.5`
  at [progression.dart:151](../lib/domain/progression.dart#L151). Becomes a
  parameter with that value as its default.
- `purge` → scales `Toxicity.dailyRetention`, today a bare `const 0.55` at
  [scoring.dart:120](../lib/domain/scoring.dart#L120). `next`, `across` and
  `residueAfter` all read it, and `residueAfter` is what the Alchemy screen
  uses to *explain* the carry-over — so if the retention moves, the explanation
  has to move with it or the screen starts describing someone else's decay.

> [!warning] Round once, not twice
> Adrenaline and the mutagen bonus both multiply the same XP. Applying them as
> two separate rounded steps loses up to a point per step and makes the result
> depend on the order. Combine into one multiplier and round at the end.

> [!warning] A sealed week must stay sealed
> `earnedBy` deliberately takes the *frozen* `WeekSummary` so re-running it on
> an archived week always gives the same answer
> ([week_archive.dart:126](../lib/data/week_archive.dart#L126)). The bonus has
> to be equally deterministic, which is a second reason to read achievements
> **by `weekStart`** rather than "whatever is in the table now": the all-time
> query returns a different answer every week, so a re-seal would silently
> re-price an old week.

**§1 check.** Nothing here is a verdict value. Every mutagen condition is
behaviour, never outcome — `mutagens.dart` says so at the top and there is
already a test asserting no condition reads weight. XP, Adrenaline and Toxicity
are all on the always-visible side of the table in `../CLAUDE.md` §1. Extend the
existing test to the *bonus* path anyway, so the guarantee covers the new call
sites rather than only the old conditions.

**Regenerates** `path_sheet.png`.

---

### T25 — The level-up

Planned and dropped in T11 ("levels are a character-sheet concept, and the
curve belongs in T12a"), dropped again in T12a, and ruled out of scope in T21,
whose animation budget went to day transitions. Third time scheduled.

> [!success] Shipped
> See [[90-Progress-Log]] T25. The arrow between the two levels was a tofu box
> that every widget assertion passed straight through; only the golden showed
> it.

> [!tip] It needs no new state, and that is not obvious
> `totalXp` is the sum of `week.xpAwarded`
> ([path_providers.dart:24](../lib/features/path/path_providers.dart#L24)), and
> XP moves **only** when a week seals. So at the moment of the reveal both
> figures are already in hand: the level after is `levelFor(totalXp)`, and the
> level before is `levelFor(totalXp - thisWeek.xp)`. A "did you just level up"
> flag would be a schema column for something arithmetic already answers.

**It belongs on the reveal, not The Path.** A level-up can only happen once a
week and only at Week's End, so animating it on the character sheet would mean
animating it on a screen where the number did not change. The XP panel on the
Reckoning is where the figure lands.

**Should it replay?** Opening Week's End again for the same week would play it
again. Recommended: **let it.** The reveal is a once-a-week destination the user
goes to deliberately, and suppressing a replay costs a stored flag — a schema
version for a cosmetic. Worth stating in the log as a choice rather than an
oversight.

> [!bug] Two animation traps this project has already paid for
> A `CircularProgressIndicator` left in the tree at zero opacity never stops,
> so `pumpAndSettle` never settles and **every** widget test on that screen
> times out at once (T21). Anything that animates here must actually end.
>
> And `reckoning_revealed.png` is a golden of the screen this animation runs
> on. T21's goldens survived only because `AnimatedSwitcher` does not animate
> its first child; this animation is *triggered by* the first build, so it will
> be mid-flight when the golden pumps. The golden must pump past the duration
> and assert the settled state — and if it still differs, regenerate it.

Timing comes from the T21 motion tokens in `theme/tokens.dart`, not a duration
picked here. A level-up earns longer than a page turn, but §5 is engraved and
weathered, not celebratory: no confetti, no bounce.

**Depends on T24** — landing it second is right, because T24 changes the XP
figure this reads.

---

### T26 — The Bestiary plate

`imagePath` is carried from Open Food Facts into `Creature`
([bestiary_providers.dart:70](../lib/features/bestiary/bestiary_providers.dart#L70))
and rendered by nothing.

> [!success] Shipped
> Fetch-once-into-app-documents, no new dependency. See [[90-Progress-Log]] T26.
> The Bestiary now has a golden, which is the thing that had been missing all
> along: a screen with no picture of itself is a screen nobody reviews.

> [!warning] It is a URL, not a file
> [remote_food.dart:72](../lib/data/remote/remote_food.dart#L72) says so in as
> many words. So "render the image" means network I/O on a screen that
> `../CLAUDE.md` §4 requires to work with no key and no network.

**Recommended: fetch once, keep it, never fetch again.** Download on first view
into `<documents>/creatures/<foodId>.jpg`; the file existing *is* the cache hit.
This is the food library's own rule — resolve once, keep forever — applied to
the picture, and it means:

- no schema change; the column keeps holding the URL, and the local path is
  derived from the food id
- offline works from the second view onward
- **no new dependency**: `dio` is already in `pubspec.yaml` and `path_provider`
  is already used by the backup service. `cached_network_image` would drag in
  `flutter_cache_manager` → `sqflite`, a second SQLite in an app that has
  strong opinions about the first one (§3), and would need a
  `flutter build apk --debug` to prove it even builds
- the cache is derived, so it stays **out** of the backup mirror, which holds
  table rows and a Markdown journal and should not grow a binary appendix

**A bare `Image.network` is the option to avoid**, and not only for offline: in
a widget test Flutter's HTTP client returns 400 for every request, so the moment
this primitive reaches the design gallery — which §5 requires — `design_gallery.png`
starts failing. Whatever lands must take an `ImageProvider` the gallery and the
tests can substitute.

**On the skin.** A bright supermarket photograph on void black will fight
everything else on the screen. It wants the treatment the rest of §5 gets:
inside the ornate frame, desaturated and darkened toward the palette, so it
reads as a plate in a bestiary rather than a shop listing.

**It goes on `CreatureSheet._Header`**, not the list row — T12b's note that "the
card has no room for it as drawn" still holds, and the sheet has the space.

**There is no Bestiary golden today.** Adding one is the cheap way to make this
reviewable without a device, and is probably worth its own moment in the task.

---

### T27 — The photograph, kept

`Entries.photoPath` is declared at
[tables.dart:158](../lib/data/tables.dart#L158) and is referenced by **nothing
else** outside generated code. T20 made the photo path findable and finished the
portion estimator without ever storing the picture.

Today `_pick` reads the file to bytes, `_read` hands them to `ImagePrep.prepare`
for the data URI, and both are dropped when the sheet closes
([photo_meal_sheet.dart:81](../lib/features/journal/photo_meal_sheet.dart#L81)).

**Three decisions.**

1. **Which bytes.** Store the *prepared* image, not the original.
   `ImagePrep.prepare` has already compressed it for the request, it is the
   smallest artifact that still shows the meal, and it costs nothing extra
   because it is already computed. The original is a 2048px 85%-quality JPEG
   that nobody will ever look at closely enough to justify the disk.
2. **Which entry.** One photograph produces *many* entries, one per component.
   All of them get the same path. That is honest — each row did come from that
   picture — and there is precedent one line away: `rawText` already writes the
   same note onto every row from the same photo.
3. **Where on disk.** `image_picker` hands back a file in a cache directory
   Android may delete at will, so it must be copied into app documents:
   `<documents>/meals/<stamp>.jpg`.

> [!warning] A restore brings back rows whose photos are gone
> The mirror is table rows plus `Journal.md`
> ([backup_service.dart:52](../lib/data/backup/backup_service.dart#L52)) — no
> binaries. After a restore every `photoPath` points at a file that does not
> exist. **A missing file must render as "no photo", never as an error**, and
> that is the correct trade rather than a gap to close later: photographs in the
> JSON mirror would bloat a file whose whole point is that the user can open it
> in Obsidian and read it.

Shown on the journal entry — a photo is not a verdict value, so §1 leaves it
alone on a daily screen.

**Out of scope, deliberately:** attaching a photo on the manual and barcode
paths. The column would allow it; the picker flow for it is a separate piece of
UI, and this task is about the picture the app already takes and throws away.

---

## Order

```
T24 perks spent         the decision task; also fixes Adrenaline
T25 level-up            needs T24: it reads the XP figure T24 changes
T26 bestiary plate      self-contained; wants a new golden
T27 photo kept          self-contained; touches the backup story
```

T24 and T25 both touch the reveal, so they run together and the reckoning
goldens regenerate once. T26 and T27 touch nothing either of them touches.

---

## Verification

`flutter analyze` clean **and** `flutter test` green before every commit — the
analyzer alone is not sufficient, for the reason in `../CLAUDE.md` §2. Baseline
at the time of writing: **803 tests, clean.**

T26 downloads a file and T27 writes one, so both want a
`flutter build apk --release --target-platform android-arm64` followed by
`python tools/check_apk_libs.py`, per §3.

Questions only a phone answers:

1. A creature photographed by Open Food Facts shows its plate, and still shows
   it in aeroplane mode the second time.
2. A logged photo meal still shows its picture after the app is killed — and
   after a restore, shows the entry with no picture and no error.
3. Seven days logged, then a seal: the XP awarded is visibly larger than the
   sum of its parts, and the Path's Adrenaline figure explains why.
