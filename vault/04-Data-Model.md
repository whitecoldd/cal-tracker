---
tags: [data]
---

# Data Model

Drift / SQLite, on device. See [[02-Architecture]] for durability.

| Table | Holds |
|---|---|
| `profiles` | Sex, birth year, height, weight goal, activity level, **week-end weekday**, stride length |
| `foods` | Canonical food library: name, brand, barcode, per-100g nutrients, GI, NOVA, additives JSON, source (`seed`/`off`/`ai`/`manual`), image path |
| `entries` | A logged item: food, date, meal slot, qty + unit, resolved grams, confidence, photo, original raw text |
| `activity_days` | Date, steps, distance, active kcal, source (`healthconnect`/`manual`) |
| `weights` | Date, kg. **Always written; interpretation sealed** |
| `water` | Date, ml — feeds Yrden |
| `weeks` | Week start, revealed flag, computed summary JSON, AI narrative, XP awarded |
| `ai_calls` | Timestamp, model, purpose, tokens — the daily budget counter |
| `achievements` | Unlocked mutagens and perks |

## Implementation notes (T2)

**Days are `yyyymmdd` integers.** `Day` is a value type with a drift
`TypeConverter`. A `DateTime` would let a timezone shift move a log across
midnight and therefore into a different week — corrupting the only number that
matters. Week arithmetic (`startOfWeek`, `endOfWeek`, `weekDays`) lives on `Day`,
and the week-end day closes its own week rather than opening the next.

**The four day-keyed tables are `WITHOUT ROWID`.** Otherwise SQLite treats their
lone `INTEGER PRIMARY KEY` as a rowid alias, drift makes it optional in inserts,
and a row written without a day gets silently assigned one.

**Source precedence on `foods`:** `manual` > `openFoodFacts` > `seed` > `ai`.
`FoodsDao.upsert` refuses to let a worse source overwrite a better one, and
recomputes the search key itself rather than trusting the caller. Bulk seed
loads dedupe on that key explicitly — `insertOrIgnore` cannot help, because the
only unique constraint is `barcode` and SQLite does not treat two NULL barcodes
as a conflict.

## Notes

**`foods` is the cache that makes the AI budget work.** Anything resolved from
Open Food Facts or AI is written here permanently, so a given food costs at most
one network call ever. `source` records where it came from so a low-confidence
AI estimate can later be upgraded by a barcode scan. See [[05-AI-Layer]].

**`entries` keeps `raw_text`** — the original phrasing ("a handful of almonds")
alongside the resolved grams. Needed to re-resolve an entry if the parse was
wrong, and it is what makes the Journal read like a journal.

**`weeks` is append-only history.** Once a week is revealed its summary is
frozen, so past weeks stay readable without recomputation and a later change to
the scoring maths cannot rewrite history.

**`weights` has no "trend" column by design.** Trend is derived at read time and
returned as `SealedValue`, so there is nowhere for a leaked verdict to be stored.
