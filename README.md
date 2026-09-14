# The Witcher's Diet

A gamified food, activity and body tracker for Android that **refuses to tell you
whether you are losing or gaining weight until the week is over.**

Personal, serverless, offline-first. All data lives on the phone.

---

## Why

Body weight swings 1–2kg a day on water, sodium and glycogen — more than any real
weekly fat change. A daily weigh-in mostly measures yesterday's salt, and reacting
to it drives the wrong behaviour.

So this app collects everything and reveals nothing directional until week's end.

- **Mon–Sat** — calories, macros, glycemic load, toxicity, steps, streak.
  Enough to make decisions, useless for guessing the trend.
- **Week's End** — energy balance, weight delta, projection, body-composition
  estimate, and a written account of the week.

Weight is still logged every day. Only its *interpretation* is sealed, and that
seal is enforced by the type system, not by UI discipline.

## The Witcher 3 frame

Harsh feedback lands better as lore than as judgement.

**Journal** (today) · **Alchemy** (macros, toxicity) · **The Path** (character
sheet) · **Bestiary** (every food you've logged) · **Week's End** (the reveal)

Derived stats: **Vitality** (diet quality), **Toxicity** (additives, NOVA-4,
added sugar, sodium, trans fat, alcohol), **Stamina** (activity), and five
**Signs** mapped to real behaviours.

> Harm flags are public food data dressed as game lore.
> **Not medical advice.**

## Stack

Flutter 3.41.6 · drift/SQLite · Riverpod · Open Food Facts (free, no key) ·
Health Connect for step history · OpenRouter free models for meal parsing and
photo recognition.

AI is always the *last* resort behind your own food library, a bundled seed
table and Open Food Facts — every resolution is cached permanently, so a food
costs at most one API call in its lifetime.

## Setup

1. `flutter pub get`
2. Add an [OpenRouter](https://openrouter.ai) API key in Settings (free, no card).
   Optional — the app works offline without it.
3. Install **Health Connect** from the Play Store for step history. Optional —
   steps can be entered manually.
4. `flutter run` with a device attached, or
   `flutter build apk --release --split-per-abi` and sideload.

## Data durability

Two layers, because Android Auto Backup alone fails silently:

1. Auto Backup of the database, prefs and photos
2. A continuous JSON + Markdown mirror in `Documents/WitchersDiet/`, outside the
   app sandbox — an uninstall cannot touch it, and the app offers to restore
   from it on first launch

## Development

See [`CLAUDE.md`](CLAUDE.md) for the rules, especially the blackout invariant and
the pinned-toolchain constraints. Design notes live in the Obsidian vault in
[`vault/`](vault/) — open that folder as the vault root in Obsidian, or just
read the Markdown on GitHub. [`00-Index`](vault/00-Index.md) is the way in;
[`90-Progress-Log`](vault/90-Progress-Log.md) is the build history.

```
flutter analyze && flutter test
```
