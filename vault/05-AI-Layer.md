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

## Rules

- All calls use `response_format: {type: "json_schema"}` with a strict schema.
  **Never parse prose.**
- Every call is logged in `ai_calls`; Settings shows today's usage against the cap.
- The app stays fully usable with no key and no network — manual entry, seed
  table and the cached library all work offline.
- Key lives in `flutter_secure_storage`. Never in the repo, never in a fixture.

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
