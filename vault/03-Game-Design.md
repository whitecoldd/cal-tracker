---
tags: [design, game]
---

# Game Design

The Witcher 3 frame is not decoration — it is how harsh feedback arrives as
lore instead of judgement. See [[01-Vision]].

## Screens

| Screen | Role |
|---|---|
| **Journal** | Today. Quest-log scroll of meals. FAB → type / photo / barcode |
| **Alchemy** | Macro vials, micronutrient decoctions, the Toxicity bar |
| **The Path** | Character sheet: level, XP, streak, Signs. Weight node sits chained |
| **Bestiary** | Every food ever logged, as a creature entry with stats and weaknesses |
| **Week's End** | *The Reckoning.* The reveal, unlocked on the chosen weekday |
| **Settings** | Profile, week-end day, OpenRouter key + budget, backup folder, Health Connect |

## Derived stats

The "little arbitrary values that improve or ruin the process". All computed in
pure Dart in `domain/`, all visible daily (none of them leak the verdict).

**Vitality** `0–100` — diet quality. Four weighted components, all of them the
day measured against itself or against body mass, so none can be solved back
into an energy balance (T6):

| Component | Weight | Measured against |
|---|---|---|
| Fibre density | 30% | 14 g per 1000 kcal |
| Whole food | 30% | share of energy from NOVA 1–2 |
| Protein | 25% | 1.6 g per kg of body mass |
| Sugar restraint | 15% | WHO free-sugar limit of 10% of energy |

> [!warning] An unlogged day scores zero, not full marks
> This is the trap the scoring is arranged around. A day with nothing logged
> has no sugar, no sodium and no ultra-processed food, so every *restraint*
> component would read perfect — making "don't log" the highest-scoring
> strategy in the app. The one thing the app asks of the user is that they log
> honestly, and the scoring must not quietly punish them for it.

**Toxicity** `0–100` — accumulated harm. Additives / E-numbers, NOVA-4 share,
trans and saturated fat, free sugar vs the WHO limit, sodium vs 2000 mg,
alcohol units. Drains slowly across days, like decoction toxicity, so a bad
Friday still colours Saturday.

Carry-over retains **55%** of yesterday's figure before today's load is added —
a half-life of a little over a day. A single indulgent evening should not be
erased by the calendar turning over six hours later, but nor should it haunt a
week, or the meter stops responding to what was actually eaten. History is
folded over a 7-day window; beyond that the retained fraction is under a
percent and invisible on the meter.

Each reading contributes its weight scaled by severity, **capped at twice the
guideline**. Without the cap one catastrophic figure — a 6,000 mg sodium day —
saturates the meter alone and hides everything else; without allowing severity
past 1.0 at all, three times the sodium guideline would read the same as
reaching it.

**Stamina** — steps against the user's own step goal, as a percentage (T10).

Safe on the daily side because a step goal is **not** a verdict target: it is
chosen in character creation and has nothing to do with energy balance, so
steps-against-goal cannot be solved back into a deficit. Active energy, which
*can*, is stored but never rendered — see the movement section of
[[02-Architecture]].

**Adrenaline** — logging-streak multiplier applied to XP.

**XP** — awarded at the reveal, and **for behaviour, never outcome** (T11):
days logged, diet quality, days at the step goal. Nothing reads which way the
scale went.

Two reasons, and the second is load-bearing. Paying for weight lost would pay
for a number that moves on water and gut contents, and would punish an honest
week that went sideways. And XP that depended on weight would be a *verdict in
disguise* — it could not appear on a daily screen without leaking the answer,
and a score seen once a week is a far weaker motivator. The reveal says so out
loud: *"Never for which way the scale went."*

### Levels and the streak (T12a)

Levels come from total XP, which comes from sealed weeks. Costs rise by 25 XP a
level from a base of 150, so the first level lands after roughly one good week
and later ones take longer. Ranks change in **bands** — Novice, Wanderer,
Path-walker, Witcher, Master of the Path — so a new title means something.

> [!warning] A streak is good to *show* and bad to *pay*
> An all-or-nothing streak that one missed day destroys gives the user a reason
> to **invent a meal** to keep it alive. The app's only demand is honest
> logging, and a mechanic that pays for dishonesty corrupts the one dataset it
> has.
>
> So the streak is display, and **Adrenaline** — the XP multiplier, 1.0 to 1.5
> — is driven by days-logged-in-the-last-seven instead. A missed day costs a
> seventh, never everything. The character sheet says so out loud, because a
> mercy the user cannot see does not change their behaviour.

### Signs

Five buffs, each tied to a real behaviour, each charged 0–1 (T12a):

| Sign | Fuels | Charged from |
|---|---|---|
| **Igni** | Protein adequacy / thermic effect | the Vitality protein component, directly |
| **Quen** | Fibre + micronutrient coverage | fibre density 60%, whole-food share 40% |
| **Aard** | Activity — steps and distance | steps 75%, distance 25%, against the step goal |
| **Axii** | Consistency + glycemic stability | days logged 70%, glycemic load 30% |
| **Yrden** | Hydration and meal-timing | water vs 2 L 60%, meal slots used 40% |

Igni reads the Vitality component rather than recomputing protein adequacy:
two rules for the same thing eventually disagree, and a day that scores well on
protein in Alchemy must not leave Igni dark on The Path.

Axii scores a day with **no** carbohydrate as neutral rather than perfect — an
absent glycemic load is not evidence of an even day.

Yrden's meal term counts *distinct slots used*, not clock times. The app does
not police when someone eats; spreading across the day is the only claim being
made, and it is a weak one.

### Food rarity

Each food gets a Gwent-style card. Rarity from NOVA group + nutrient density:
Common → Rare → Epic. Lentils are Epic; a NOVA-4 energy drink is Common and
carries visible toxicity.

### Mutagens (T12b)

Weekly perks, granted at the reveal. The only mechanic that carries forward.

| Mutagen | Earned for | Effect |
|---|---|---|
| **Green Blood** | all 7 days logged | +10% experience |
| **Red Vitriol** | average Vitality ≥ 70 | +10% experience |
| **Blue Essence** | 5+ days at the step goal | +10% adrenaline |
| **White Honey** | average Toxicity ≤ 25 | toxicity fades 15% faster |

> [!warning] Every condition is behaviour, never outcome
> No mutagen may read weight, weight change, or energy balance. A perk that
> depended on the verdict would **be** the verdict — it would arrive on the
> character sheet the Monday after and answer the question the app exists to
> defer. There is a test running an identical week with a 1.4 kg loss, no
> change, and a 1.4 kg gain, asserting the perks come out the same.

Decided from the **frozen** `WeekSummary`, so re-running the grant on an
archived week always gives the same answer. Stacking is capped at +50% per
effect, so a long run of good weeks cannot compound into a figure that makes
the earlier ones look worthless.

A week with nothing logged earns nothing — the same trap as Vitality in T6,
where an empty day passes every *restraint* condition on an absence of
evidence.

### The Bestiary (T12b)

Every food ever logged, as a creature entry: rarity, stats per 100 g, and its
**weaknesses** — the harm flags, each stating the public guideline it is
measured against rather than making a bare accusation.

Shows what has been **eaten**, not what is known. The seed table is in the
library from first launch, so "caught" and "known" are separate counts and a
collection claiming 132 creatures on day one would mean nothing.

Rarity and weaknesses come from `rankFood` and `readFoodToxins` — the same two
calls the food picker makes. A food must not read Epic in the picker and Rare
in the collection. Sorting is done in Dart rather than SQL because both are
*derived*: storing them as columns would mean keeping a score the engine could
later disagree with.

## Harm model

Drawn from Open Food Facts fields plus the nutrition engine:

- Additives / E-numbers, with plain-language notes
- NOVA-4 ultra-processed count
- Added sugar vs WHO free-sugar limit
- Sodium vs 2000mg/day
- Saturated fat, trans fat
- Alcohol units

Rendered as "curses" and "toxins" with an explanation on tap.

### The weekly report (T34–T41, v1.1.0)

Week's End has two readings, chosen with `RunicTabs`:

- **The Tally** — the week in figures: composition, the week's curses with the
  foods that carried them, the E-numbers themselves, tendencies in both tones,
  and the days.
- **The Tale** — the week in words, in four sections. Written by a model once
  at the seal, or by the app from the same figures when there is no key.

**The split that matters.** The descriptive half is readable on *any* day,
because none of it says which way the scale went — it is the same material
Alchemy already shows daily, aggregated. The verdict half is unchanged.

The open half states **no quantity of energy and no weight**: shares,
densities and counts of days. A weekly intake in kcal, read by someone who
knows their own expenditure, is the verdict with the subtraction done in their
head. Enforced by `WeekPattern` having no field for one — see
`../lib/domain/week_pattern.dart`.

> [!warning] Standing disclaimer
> Every harm surface must display: **lore, not a physician — not medical advice.**
> No harm flag may be phrased as a diagnosis, and the AI system prompt says so
> explicitly.

## Visual language

| Token | Value |
|---|---|
| Void black (bg) | `#0D0B0A` |
| Aged parchment (text) | `#E8D9B0` |
| Blood red (danger) | `#8B1A1A` |
| Gold (accent / XP) | `#C9A227` |
| Steel (borders) | `#4A4540` |

- **Cinzel** for engraved caps, **EB Garamond** for body and lore italics
- Ornate corner brackets on panels; diamond skill nodes
- Sealed values render as a **chained, locked** node — visibly present,
  deliberately unreadable. The seal is part of the aesthetic, not an error state.
