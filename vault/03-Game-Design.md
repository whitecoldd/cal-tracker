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

### Signs

Five buffs, each tied to a real behaviour:

| Sign | Fuels |
|---|---|
| **Igni** | Protein adequacy / thermic effect |
| **Quen** | Fibre + micronutrient coverage |
| **Aard** | Activity — steps and distance |
| **Axii** | Consistency — logging streak + glycemic stability |
| **Yrden** | Hydration and meal-timing discipline |

### Food rarity

Each food gets a Gwent-style card. Rarity from NOVA group + nutrient density:
Common → Rare → Epic. Lentils are Epic; a NOVA-4 energy drink is Common and
carries visible toxicity.

### Mutagens

Weekly perks, granted at the reveal for hitting targets. They persist and
modify the following week's scoring — the only mechanic that carries forward.

## Harm model

Drawn from Open Food Facts fields plus the nutrition engine:

- Additives / E-numbers, with plain-language notes
- NOVA-4 ultra-processed count
- Added sugar vs WHO free-sugar limit
- Sodium vs 2000mg/day
- Saturated fat, trans fat
- Alcohol units

Rendered as "curses" and "toxins" with an explanation on tap.

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
