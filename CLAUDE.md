# CLAUDE.md — The Witcher's Diet

Personal, serverless Android calorie/body tracker. Flutter. All data on-device.
Read this before touching anything.

---

## 1. The one invariant that defines this app

**Between week-start and the configured week-end day, the app must never reveal
whether the user is losing or gaining weight.**

This is not a UI preference. It is the product. The user logs honestly all week
precisely because the app cannot talk back, and the whole story lands in one
reveal at week's end.

Enforcement is in the type system, not in widget code:

```dart
sealed class SealedValue<T> { const SealedValue(); }
final class Sealed<T>   extends SealedValue<T> { const Sealed(); }
final class Revealed<T> extends SealedValue<T> { final T value; const Revealed(this.value); }
```

Every verdict-bearing value crosses the UI boundary as `SealedValue<T>`. A widget
cannot render a number it cannot unwrap. `non_exhaustive_switch_*` is an analyzer
**error**, so a new branch cannot be silently forgotten.

| Always visible, daily | Sealed until week's end |
|---|---|
| kcal eaten, macros, fiber | TDEE comparison, deficit/surplus |
| Glycemic index / load | Weight trend, weight delta |
| Toxicity, Vitality, Stamina, Signs | Projected weight change |
| Steps, distance, streak, XP | Body-composition estimate |
| Per-food harm flags | Any "losing"/"gaining" statement |

Rules that follow from this:

- Weight is **logged** every day. Only its *interpretation* is sealed.
- Never add a widget that takes a raw `double` for a verdict value. Take
  `SealedValue<double>`.
- Never let AI-generated text leak the verdict. Weekly narrative prompts run
  **only** on the reveal day; daily prompts are never given TDEE or weight data.
- Every new verdict value needs a test that freezes the clock to each weekday
  and asserts `Sealed` on all non-reveal days.

If a change would make the daily screens answer "am I losing weight?", the change
is wrong, however convenient.

---

## 2. Workflow rules

- **One task per commit, and push each one separately.** Never batch tasks.
  Task list lives in the vault (`90-Progress-Log.md`) and the plan file.
- Before every commit: `flutter analyze` clean **and** `flutter test` green.
- After every task: append an entry to the Obsidian vault progress log
  (see §6) in the same commit as the code.
- Commit messages: `T<n>: <imperative summary>`, then a short body explaining
  *why*. End with the Co-Authored-By trailer.
- Never commit secrets. The OpenRouter key lives in `flutter_secure_storage`
  and is entered in-app. There is no `.env` in this repo and no key in any
  Dart source, test or fixture.

---

## 3. Toolchain constraints (do not "helpfully" upgrade)

Flutter **3.41.6** / Dart **3.11.4** is the pinned local toolchain.

Flutter pins `meta` to 1.17.0, which caps `analyzer`, which caps `drift_dev`
at **2.34.x**. Therefore:

- `drift` and `drift_dev` are both held at `>=2.34.0 <2.35.0`. They must move together.
- `flutter_riverpod` stays on **2.6.1**. 3.4.1+ needs Dart 3.12.
- `sqlite3` 3.5.2 self-builds via native assets. **Do not** add
  `sqlite3_flutter_libs` — it is end-of-life and only existed for sqlite3 2.x.

If you genuinely need a newer package, the fix is upgrading Flutter — which is
the user's call, because the same SDK serves their other projects. Ask first.

Android: `minSdk 26` (floor for Health Connect). `MainActivity` extends
`FlutterFragmentActivity` — the health plugin needs a FragmentActivity to run
its permission contract. Do not revert either.

**`permission_handler` is deliberately absent.** Its Android module (14.1.0)
fails to compile against this project's Gradle/KGP combination — its build
script uses the `kotlin { compilerOptions { } }` DSL and hits `srcDirs`
deprecation-as-error. We do not need it:

- Camera → requested by `image_picker` / `mobile_scanner` themselves
- `ACTIVITY_RECOGNITION` + Health Connect → requested by the `health` plugin
- `MANAGE_EXTERNAL_STORAGE` (the backup mirror) → a ~20-line platform channel
  in `MainActivity.kt` firing `Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`,
  added in T13

Do not re-add `permission_handler` to solve a permission problem without first
checking it actually builds.

---

## 4. AI budget — the real constraint

OpenRouter free tier: **20 requests/minute, 50/day** at $0 balance (1,000/day
after a one-time $10 purchase). Design every feature assuming 50.

Model chain, in order, all vision + structured-output capable:
1. `nex-agi/nex-n2.5-pro:free` (262k ctx)
2. `inclusionai/ling-3.0-flash-vl:free`
3. `dots-studio/dots-3-note-preview:free`

Food resolution order — **AI is always last**:
1. User's own food library (anything resolved before, forever)
2. Bundled seed table (`assets/data/`)
3. Open Food Facts (free, no key)
4. AI

Non-negotiables:
- Every AI resolution is written back into the food library. A given food costs
  at most one call, ever.
- All calls use `response_format: {type: "json_schema"}`. Never parse prose.
- Log every call in `ai_calls`; Settings shows today's usage against the cap.
- The app must stay fully usable with no key and no network.
- AI is used for exactly four things: free-text meal parsing, vague-portion
  estimation, photo→items, and one weekly narrative. Adding a fifth needs a
  deliberate decision about the budget.

---

## 5. Design language — Witcher 3

Dark, engraved, weathered. Never Material-default.

| Token | Value |
|---|---|
| Void black (bg) | `#0D0B0A` |
| Aged parchment (text) | `#E8D9B0` |
| Blood red (danger/toxicity) | `#8B1A1A` |
| Gold (accent/XP) | `#C9A227` |
| Steel (borders/disabled) | `#4A4540` |

- Headings: **Cinzel** (engraved caps). Body: **EB Garamond**.
  Both are bundled *variable* fonts — set weight with
  `fontVariations: [FontVariation('wght', n)]`, not `fontWeight` alone.
- Ornate corner brackets on panels, diamond skill nodes, chained/locked
  treatment for sealed values.
- Domain vocabulary is consistent and load-bearing:
  Journal (today) · Alchemy (nutrition) · The Path (character sheet) ·
  Bestiary (foods) · Week's End / The Reckoning (reveal) · Signs (buffs) ·
  Toxicity (harm) · Vitality (quality) · Mutagens (perks).
- Never use a raw colour literal in a widget. Pull from the theme tokens.

---

## 6. Obsidian vault

`C:\dev\cal-tracker-vault\cal-tracker\` (outside the repo, matching the user's
`proovia-vault` / `gravescan-vault` convention).

`00-Index` · `01-Vision` · `02-Architecture` · `03-Game-Design` ·
`04-Data-Model` · `05-AI-Layer` · `90-Progress-Log`

Update the relevant note whenever the thing it documents changes, and always
append to `90-Progress-Log.md` when finishing a task. Use `[[wikilinks]]`.

---

## 7. Health & safety framing

The app surfaces "possible damages to the human body" (additives, NOVA 4,
added sugar, sodium, saturated/trans fat, alcohol). This is drawn from public
food data and shown as game flavour.

Every harm surface carries a plain, visible disclaimer: **lore, not a
physician — not medical advice.** Never phrase a harm flag as a diagnosis, and
never let the AI do so either — say it in the system prompt.

---

## 8. Code conventions

- `flutter_riverpod` with hand-written providers. No codegen for providers.
- Layering: `data/` (drift, DAOs, remote clients) → `domain/` (pure Dart:
  nutrition engine, scoring, reveal gate) → `features/<name>/` (UI + providers)
  → `theme/`, `widgets/` (shared).
- **`domain/` must not import Flutter.** It is pure Dart so it is trivially
  testable, and the nutrition/scoring maths is tested directly against fixtures.
- Prefer `final`, single quotes, trailing commas (the analyzer enforces all three).
- Use `package:clock` for all "now" reads so tests can freeze time. Never call
  `DateTime.now()` directly outside of `clock.now()`.
