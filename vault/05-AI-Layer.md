---
tags: [ai]
---

# AI Layer

## The budget is the design constraint

OpenRouter free tier: **20 requests/minute, 50/day** at $0 balance. A one-time
$10 purchase raises it to 1,000/day. Everything is designed assuming **50**.

## Model chain

All three are vision-capable with structured JSON output:

1. `nex-agi/nex-n2.5-pro:free` — 262k context
2. `inclusionai/ling-3.0-flash-vl:free` — 262k context
3. `dots-studio/dots-3-note-preview:free` — 512k context

Fall through on error, rate-limit, or timeout.

## Resolution order — AI is always last

1. **User's food library** (`foods`) — anything resolved before, forever
2. **Bundled seed table** (`assets/data/`) — common foods with GI and NOVA
3. **Open Food Facts** — free, no key, has brands / barcodes / additives
4. **AI**

Every AI resolution is written back to `foods`, so a food costs at most one
call in its lifetime. This is what makes 50/day workable.

Steps 1–2 shipped in T4, step 3 in T5 — see the remote-lookup section of
[[02-Architecture]]. Step 3 writes back on the same terms as step 4, so by the
time the model is reachable at all (T8), the common foods are already local and
the budget is spent only on what genuinely needs it.

> [!note] The write-back is enforced by a type, not by discipline
> A food fetched upstream arrives as `RemoteFood`, which has no row id and
> therefore cannot be logged. Turning it into something loggable *is* the write
> to `foods`. There is no code path that shows an upstream result and then
> forgets it.

Two numbers guard the budget on the search path: nothing is fetched below three
characters, and the query is debounced 250 ms, so typing a food name costs one
request rather than one per keystroke.

## Rules

- All calls use `response_format: {type: "json_schema"}` with a strict schema.
  **Never parse prose.**
- Every call is logged in `ai_calls`; Settings shows today's usage against the cap.
- The app stays fully usable with no key and no network — manual entry, seed
  table and the cached library all work offline.
- Key lives in `flutter_secure_storage`. Never in the repo, never in a fixture.

## What shipped in T8

```
lib/data/ai/
  ai_key_store.dart      the keystore, behind an interface
  prompts.dart           every prompt, as pure functions
  ai_schemas.dart        the strict JSON schemas
  ai_decode.dart         reply -> the app's own types
  openrouter_client.dart the chain, the budget, the recording
  meal_resolver.dart     parsed items -> rows, with write-back
lib/features/settings/
  settings_screen.dart   key entry and today's allowance
lib/features/journal/
  speak_meal_sheet.dart  type a meal, confirm, log
```

Two of the four permitted uses landed here: **free-text meal parsing** and
**vague-portion estimation**. Photo→items followed in T9 (below); the weekly
narrative is T11.

### The prompts are pure functions

So the two rules that matter can be *tested* rather than merely intended.
`test/ai_prompts_test.dart` asserts that no daily prompt contains `tdee`,
`deficit`, `surplus`, `weight trend`, `bmr` — or even `kg`. A model cannot leak
a figure it was never told, which is a stronger guarantee than asking it not to.

The same test asserts every system prompt carries the "never diagnose" clause.
It lives in one shared preamble precisely so a fifth use cannot be added
without it.

`test/openrouter_client_test.dart` then re-asserts the blackout **on the wire**:
it serialises every request the fake adapter saw and scans that. A prompt
builder that is clean but a call site that appends body data would pass the
first test and fail the second.

### One call per meal, not per food

"two eggs, a slice of rye and a coffee" is a single request however many foods
it names. That is the only thing that makes this affordable at fifty a day.

### The resolution order is applied to the model's own output

A parsed item is looked up in the library first. If it is there, the model's
nutrients are **thrown away** and only its reading of the name and the portion
survive — the device's own figures are better. If it is not there, the food is
written with `FoodSource.ai`, the weakest source, so a later barcode scan or
hand correction is allowed to overwrite it.

Matching is by **exact search key**, not the `LIKE` search the food picker
uses. A fuzzy match is right in a search box, where the user is looking at the
results and picking one; here nothing would notice "rye bread" silently
resolving to "rye bread crackers".

> [!note] Open Food Facts is deliberately skipped on this path
> It is a brand and barcode database, and a typed meal is almost entirely
> generic foods, which the seed table already covers. A search per item would
> add a round trip each for answers usually worse than the seed's. The barcode
> path is where Open Food Facts earns its place.

### The device beats the model on portions

A food with a known piece weight resolves "2 eggs" more reliably than a
language model does, and `portion.dart`'s unit table was written for exactly
this. The model's gram figure is used **only** when the device has nothing
better, and then capped below the exact units' confidence.

### The budget is checked before the request

Fifty a day is low enough that hitting the limit has to be something the app
sees coming, not a surprise failure mid-meal. Every attempt is recorded
including the failures, because OpenRouter charges the rate limit against the
request and not the result.

### Decoding is distrustful

The schema is strict, but a model can return a number where the schema says
number and have it be nonsense. So energy is clamped to 900 kcal/100 g (pure
fat), a NOVA group outside 1–4 is *dropped* rather than clamped — clamping
would assert a processing level the model never claimed — and a missing
confidence reads as 0.5 rather than as certainty. A portion estimate is capped
at 0.85 confidence whatever the model says: nobody weighed it.

Two deliberate leniencies, both because a decode failure costs a call: a fenced
```` ```json ```` block is unwrapped, and a numeric string is accepted. Past
that, a malformed reply is a failure and the next model in the chain is tried.

### The key

Typed in Settings, straight into the Android keystore. Never rendered again —
not even masked with a few characters showing, because there is nothing to
check by eye and every rendering is a chance to put it in a screenshot. There
is a test asserting the key does not appear in the widget tree.

Validation is a **shape check** (`sk-or-` and a plausible length), not a
network check: verifying against OpenRouter would spend one of fifty daily
requests to learn what a prefix reveals.

## Vision (T9)

```
lib/data/ai/image_prep.dart           policy, compression, data URI
lib/features/journal/photo_meal_sheet.dart
lib/features/journal/meal_confirm.dart  shared by the typed and photo paths
```

Three of the four permitted uses are now live. Only the weekly narrative is
left, and it belongs with [[02-Architecture]]'s reveal machinery in T11.

**A photograph is one request, however many foods are on the plate** — the
same bargain as the typed path, and the same schema, chain, budget and
recording. `parsePhoto` differs from `parseMeal` only in the shape of the
message content: a list of `{type: text}` and `{type: image_url}` parts rather
than a string.

### The picture is shrunk, and stripped

| Setting | Value | Why |
|---|---|---|
| Long edge | 1024 px | Above what a model resolves a meal at, far below what a camera produces |
| Quality | 70 | Food survives it; text would not |
| Hard cap | 1500 KB | A backstop — a real meal lands at 100–200 KB |

> [!warning] `keepExif: false` is a privacy decision, not an inherited default
> A camera photo carries EXIF, and EXIF carries GPS. This app keeps everything
> on the device; sending the location of the user's kitchen to a third party
> along with a picture of dinner would quietly undo that. Re-encoding drops it,
> and the flag is set explicitly so nobody later "tidies it away" as redundant.

The cap is enforced **after** compression, so a compressor that misbehaves
cannot push a huge upload through. There is a test for exactly that.

`image_picker` also does a first pass at 2048 px before the real compression —
cheaper than handing twelve megapixels to a platform channel.

### The prompt guards against invented food

The failure mode that matters is not misidentifying a food; it is *inventing*
one. A model that infers a side dish out of frame adds food nobody ate to the
day's total, and the user is unlikely to notice a plausible extra line. So the
prompt says to name only what is actually visible, to put anything seen but
unidentifiable into `unrecognised` in plain words, and to return no items at
all if the picture is not of food.

### The confirm step is shared, not copied

`MealConfirm` serves both sheets. It is the only thing standing between a
model's mistake and the day's totals, and two copies of it would eventually
disagree about what they show.

## The weekly narrative (T11)

The fourth and last permitted use, and the **only** call given verdict data.
All four are now live.

### `NarrativeFacts` is the guard

`weeklyNarrative` takes `NarrativeFacts`, and `NarrativeFacts.from` returns
null unless the `Reckoning` it is built from is actually revealed. There is no
other constructor. So the one exception to the blackout has no syntax for
misuse — you cannot write code that asks a model to describe a week still in
progress, whatever a comment says.

Same shape as `RevealGate.gate` taking a callback: the wrong thing is made
unwriteable rather than discouraged.

### One call, once, per week

| Situation | What happens |
|---|---|
| Week seals | One call |
| Screen re-opened | Nothing — the week is already sealed |
| App restarted | Nothing — read from `weeks.narrative` |
| **The call failed** | **Nothing.** The week keeps its null |

The last row is the one worth stating. Retrying a failed narrative on every
visit is exactly how fifty requests a day disappear, so a week that did not get
an account never asks again.

A failure never blocks the seal. No key, no network, no budget — the week
freezes with every figure it has. The account is flavour on top of the numbers,
and refusing to seal because a model was unreachable would lose the numbers to
save the prose.

### Sealing is triggered by opening the screen

There is no background job in a serverless app, so a week closes when the user
comes to read it. `WeekArchive.seal` is idempotent, which is what makes calling
it on every open safe.

## The four permitted uses

1. **Free-text meal parsing** — "two eggs and a slice of rye" → structured items
2. **Vague-portion estimation** — "a handful", "a plate of" → grams + confidence
3. **Photo → items** — compressed image, vision model, confirm/edit before saving
4. **Weekly narrative** — exactly one call, on reveal day

Adding a fifth use requires a deliberate decision about the budget.

## Prompt constraints

> [!danger] The blackout applies to prompts too
> Daily prompts are **never** given TDEE, weight, or energy-balance data. A model
> cannot leak a verdict it was never told. The weekly narrative prompt is the only
> one that receives verdict data, and it runs only on the reveal day.

The system prompt also forbids diagnostic phrasing — harm flags are lore, not
medicine. See [[03-Game-Design]].
