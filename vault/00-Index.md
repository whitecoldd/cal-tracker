---
tags: [index]
---

# The Witcher's Diet — Vault Index

Personal gamified food / activity / body tracker. Flutter, Android, serverless,
all data on device.

> [!quote] The premise
> Most trackers let you weigh in daily, see "up 0.4kg", and react to noise.
> This one refuses to answer *"am I losing or gaining?"* until the week is done.

## Notes

- [[01-Vision]] — what this is and why the blackout exists
- [[02-Architecture]] — stack, layering, toolchain constraints
- [[03-Game-Design]] — Witcher 3 skin, screens, derived stats, harm model
- [[04-Data-Model]] — drift tables and relationships
- [[05-AI-Layer]] — OpenRouter, models, budget, prompts
- [[90-Progress-Log]] — one entry per shipped task
- [[91-Improvement-Plan]] — open issues and the tasks that close them

## Where this lives

This vault **is** `vault/` inside the app repo — open
`C:\dev\cal-tracker\vault` as the vault root in Obsidian. It used to sit
outside the repo at `C:\dev\cal-tracker-vault\cal-tracker`; it was moved in
so a task's code and its [[90-Progress-Log]] entry ship in the same commit.

- Repo: `C:\dev\cal-tracker` → `https://github.com/whitecoldd/cal-tracker`
- Rules for the agent: `../CLAUDE.md` (one level up from this folder)
- Attachments: `attachments/`

> [!warning] Wikilinks stop at the vault boundary
> `[[wikilinks]]` resolve only between notes in this folder. To point at
> source, write a plain relative path such as `../lib/domain/portion.dart`.
> Obsidian will not follow it; GitHub will.
