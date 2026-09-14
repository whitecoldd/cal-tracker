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

**Vitality** `0–100` — diet quality. Nutrient density, fibre, whole-food ratio,
protein adequacy. The closest thing to a single "how well did I eat" score.

**Toxicity** `0–100` — accumulated harm. Additives / E-numbers, NOVA-4 count,
trans and saturated fat, added sugar vs the WHO free-sugar limit, sodium vs
2000mg, alcohol units. Drains slowly across days, like decoction toxicity, so a
bad Friday still colours Saturday.

**Stamina** — activity against goal, from steps and distance.

**Adrenaline** — logging-streak multiplier applied to XP.

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
