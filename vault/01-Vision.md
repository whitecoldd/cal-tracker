---
tags: [vision]
---

# Vision

## The problem

Daily weigh-ins produce a feedback loop dominated by noise. Water, sodium, glycogen
and gut contents swing body weight by 1–2kg day to day, which is larger than any
real weekly fat change. So the daily number mostly measures *yesterday's salt*, and
reacting to it produces exactly the wrong behaviour: cutting harder after a bad
reading, coasting after a good one.

## The answer: deliberate blindness

The app collects everything and reveals nothing directional until the week closes.

- **Mon–Sat** you see *inputs and quality*: calories, macros, glycemic load,
  toxicity, steps, streak. Rich enough to make decisions, useless for guessing
  the trend.
- **Week's End** unlocks *the verdict*: energy balance, weight delta, projection,
  body-composition estimate, and a written account of the week.

Weight is still logged daily — only its interpretation is sealed. See
[[02-Architecture]] for how `SealedValue<T>` makes this a compile-time property
rather than a UI habit.

## Why gamified, why Witcher

A number going up or down is a weak motivator. A character sheet you are building
is a strong one. The Witcher 3 frame maps unusually cleanly onto nutrition:

- Alchemy → macros and micronutrients
- **Toxicity** → the real cost of ultra-processed food, additives, sugar, sodium
- **Signs** → five buffs tied to actual behaviours
- **Bestiary** → every food you have ever logged, with its stats and weaknesses
- Level-up → the weekly reveal

It also means the harsh feedback arrives as lore rather than as judgement.

## Scope

Personal use, one user, sideloaded. No accounts, no server, no telemetry.
Data must survive app reinstall — see [[02-Architecture]] §Durability.

## Non-goals

- Not a medical device. Harm flags are public food data dressed as lore, with a
  standing "not medical advice" disclaimer.
- No social features, no sharing, no cloud sync beyond the user's own backup folder.
