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
  Task list lives in the vault (`vault/90-Progress-Log.md`) and the plan file.
- Before every commit: `flutter analyze` clean **and** `flutter test` green.
  **The analyzer is not sufficient on its own.** It has twice passed on code
  that could not compile: `database.g.dart` is a *part* of `database.dart`, so
  it sees only that file's imports, not the ones `tables.dart` makes. Any domain
  type used in a column — `Day`, and every enum behind `textEnum` — must be
  imported in `database.dart` as well. Only the compiler catches it, so run the
  tests.
- Any task that adds a plugin also runs `flutter build apk --debug`. A plugin
  that resolves in pub can still fail to build on Android (this is how the
  `permission_handler` problem surfaced).
- **Database work inside `testWidgets` must go through `tester.runAsync`.** A
  widget-test body runs in fake async, which never turns the real event loop, so
  an awaited drift query never completes — the test simply hangs until its
  timeout with no useful error. Prefer handing widgets a settled snapshot
  (override the stream provider with `Stream.value(...)`) over subscribing them
  to a live drift stream in a test: a live stream also schedules a
  zero-duration timer on cancel, which the binding reports as a leak.
- Do not kill a `flutter test` run mid-flight. It can leave a half-copied
  `sqlite3.dll` in `build/native_assets/windows/`, and the next run dies with a
  `PathExistsException`. If that happens, delete **only that file** —
  `rm -f build/native_assets/windows/sqlite3.dll`. Never `rm -rf
  build/native_assets`: that also takes `android/jniLibs/`, and §3 explains why
  the next APK then ships without SQLite.
- After every task: append an entry to `vault/90-Progress-Log.md` (see §6) in
  the same commit as the code. The vault lives in this repo, so this is one
  commit, not two — never commit code and leave the log entry for later.
- Commit messages: `T<n>: <imperative summary>`, then a short body explaining
  *why*. End with the Co-Authored-By trailer.
- **Every commit bumps the version** and adds its line to `CHANGELOG.md`, in
  that same commit. See §9 for which number moves.
- **No Open Food Facts credential is ever stored.** Its write endpoint
  authenticates with an account username *and password* sent on every call —
  there is no scoped token to revoke. So the app does not submit on the user's
  behalf: it opens the ledger's own add-product form and hands over a
  transcript to paste (T32). If a scoped token ever exists, revisit; until
  then, do not add a "log in to Open Food Facts" screen.
- Never commit secrets. The OpenRouter key lives in `flutter_secure_storage`
  and is entered in-app. No key belongs in any Dart source, test or fixture.
  `.env` is gitignored and untracked — only `.env.example`, which holds a
  placeholder, is committed. A local `.env` may exist on a dev machine; it is
  not an input to the app. **Nothing in `lib/` reads `.env`, and nothing reads
  a `--dart-define`.** Keep it that way: `--dart-define-from-file=.env` would
  bake the key into the APK, which is exactly what secure storage avoids.

---

## 3. Toolchain constraints (do not "helpfully" upgrade)

Flutter **3.41.6** / Dart **3.11.4** is the pinned local toolchain.

Flutter pins `meta` to 1.17.0, which caps `analyzer`, which caps `drift_dev`
at **2.34.x**. Therefore:

- `drift` and `drift_dev` are both held at `>=2.34.0 <2.35.0`. They must move together.
- `flutter_riverpod` stays on **2.6.1**. 3.4.1+ needs Dart 3.12.
- `sqlite3` 3.5.2 ships SQLite itself via native assets. **Do not** add
  `sqlite3_flutter_libs` — it is end-of-life and only existed for sqlite3 2.x.

If you genuinely need a newer package, the fix is upgrading Flutter — which is
the user's call, because the same SDK serves their other projects. Ask first.

### The native asset that can silently go missing

`sqlite3` has no Android module. Its build hook downloads a prebuilt
`libsqlite3.so` per ABI, and `flutter assemble` copies them into
`build/native_assets/android/jniLibs/lib/<abi>/`, which the Flutter Gradle
plugin registers as a `jniLibs` source directory. If that directory is empty
when Gradle runs, **the build still succeeds**: Gradle has no idea a library was
supposed to be there. The APK installs, then dies at the first query with
`Failed to load dynamic library 'libsqlite3.so'` — which the user sees as
"The Path is blocked" and nothing more.

It goes empty because `flutter assemble`'s `install_code_assets` step declares
only `native_assets.json` as its output (`InstallCodeAssets.outputs` in
`flutter_tools/lib/src/build_system/targets/native_assets.dart`). Delete
`build/native_assets/` and that stamp still looks valid, so the step is skipped
on every subsequent build and the libraries are never copied back. This is how
`app-release.apk` shipped without SQLite on 2026-09-15.

So:

- Never wipe `build/native_assets/` wholesale (see §2).
- If it has been wiped, `rm -f .dart_tool/flutter_build/*/install_code_assets.stamp`
  before rebuilding. `flutter clean` also works and is slower.
- **After every `flutter build apk`, run `python tools/check_apk_libs.py`.** It
  opens the APK and fails if an ABI carrying `libflutter.so` has no
  `libsqlite3.so`. This is the only check that catches the failure before the
  phone does — the analyzer, the tests and Gradle all pass on a broken APK.

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

`url_launcher` is absent for the same reason, and opening a web page is a
second hand-rolled channel in `MainActivity.kt` (`/links`, T32). It fires
`ACTION_VIEW` and **refuses any scheme but http(s)**, on both sides of the
channel — a launcher that takes `file://` or `content://` reads as the app.

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
- AI is used for exactly five things: free-text meal parsing, vague-portion
  estimation, photo→items, one weekly narrative, and reading a nutrition table
  off a photograph of a package. A sixth needs a deliberate decision about the
  budget, as the fifth got in T31: Open Food Facts is thin outside western
  Europe, so a barcode it has never held left the user typing eight figures off
  small print. The write-back rule caps the cost at one call per new product
  for the life of the install.

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
- The design gallery (`lib/features/design_gallery/`) shows every primitive on
  one page. Add new primitives to it, and regenerate the golden with
  `flutter test --update-goldens --tags golden` so the skin stays reviewable
  without a device. The golden also runs in the normal suite, so an accidental
  visual regression fails the build.

---

## 6. Obsidian vault

`vault/` **inside this repo**. Open `C:\dev\cal-tracker\vault` as the vault
root in Obsidian — `.obsidian/` sits there and is committed, so the theme,
accent colour and enabled plugins travel with the repo. (`workspace*.json` is
per-machine UI state and is gitignored.)

It used to live at `C:\dev\cal-tracker-vault\cal-tracker\`, outside the repo,
matching the user's `proovia-vault` / `gravescan-vault` convention. It was moved
in so that a task's code and its progress-log entry land in **one commit** — the
rule in §2 was impossible to honour across two repos.

`00-Index` · `01-Vision` · `02-Architecture` · `03-Game-Design` ·
`04-Data-Model` · `05-AI-Layer` · `90-Progress-Log`

Update the relevant note whenever the thing it documents changes, and always
append to `vault/90-Progress-Log.md` when finishing a task. Use `[[wikilinks]]`
between notes — Obsidian resolves them within `vault/`, so never write a
wikilink to a source file; link those by relative path from the repo root.

Attachments go in `vault/attachments/` (set as the attachment folder in
`.obsidian/app.json`).

The repo is public, so the vault is too. It holds design reasoning only —
**no personal measurements, no weights, nothing resembling a credential.**

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

---

## 9. Versioning

`MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`. **1.0.0+1 is the first stable
release**, shipped 2026-09-16 as "First Contract"; everything before it was
pre-release and has no version of its own.

| Part | Moves when |
|---|---|
| PATCH | **every commit**, without exception |
| MINOR | a large change: a new mechanic, screen or data source, a schema migration — anything that changes what the app is for a day |
| MAJOR | a total makeover or remaster: the design language replaced, the seal reworked, the data model rebuilt. Not expected soon; documented so it is not improvised when it happens |
| BUILD | +1 on every version change. Never reused, never decreasing — Play refuses a `versionCode` it has already accepted |

Bumping a higher part resets the lower ones (`1.1.0`, then `1.1.1`). **BUILD
never resets.**

Three files carry the version and must agree:

- `pubspec.yaml` — the source of truth; Gradle reads `versionName`/`versionCode`
  straight from it
- `lib/version.dart` — the constant the Settings screen prints. Mirrored by hand
  rather than read with `package_info_plus`, for the reason §3 gives about
  plugins
- `CHANGELOG.md` — the newest `##` section must be the current version

`test/version_test.dart` fails if they disagree, so a forgotten bump does not
reach a commit. Nothing at runtime would notice otherwise: the APK would carry
one number and display another.

So the per-task sequence in §2 gains one step — bump the version and add the
commit's line to the changelog's newest section, in the same commit as the code
and the progress-log entry. A version bump is never its own commit.
