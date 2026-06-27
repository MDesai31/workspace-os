# Memory Conventions

Single source of truth for the workspace-os memory skills (`/ingest`, `/memory-lint`,
`/sync-memory`) and the memory scaffolding in `/project-init`. Those skills follow these rules;
they do not restate them.

## What memory is

`<repo>/docs/memory/` is the repo's **canonical, shared, version-controlled** knowledge base:
durable *reference* facts about THIS codebase — architecture rationale, domain model, and
non-obvious facts looked up when a topic arises. It travels with the repo (every collaborator,
every machine) via git, **alongside** CLAUDE.md, not replacing it.

## The boundary rule — where a fact belongs

Each durable fact has exactly ONE home. Decide with this test:

> "If the model didn't see this until it went looking, would it make a costly mistake first?"
> - **YES → CLAUDE.md** (always-loaded, imperative "how to work here").
> - **NO — only needed when the topic comes up → `docs/memory/`** (on-demand reference).

- A **decision** (a choice + when + why) → `docs/project-tracking/decisions-log.md` (a `D-`
  record). A memory fact may `[[wikilink]]` a `D-` record but never restates it.
- **Never migrate existing CLAUDE.md content** into memory when adopting this. Memory grows from
  new facts going forward.

Generic worked example: a framework's non-obvious import path — where the wrong guess silently
compiles to a broken state — is *costly-first* → **CLAUDE.md**. The *rationale* for choosing that
framework is *consult-when-relevant* → **docs/memory/**.

## Files (per target repo)

Created by `/project-init` under `<repo>/docs/memory/`:

| File | Holds | Written by |
|---|---|---|
| `MEMORY.md` | one-line-per-fact index, grouped by type | `/ingest`, `/sync-memory`, manual |
| `<slug>.md` | one fact per file | `/ingest`, `/sync-memory` |

## Fact schema

Same shape as `~/.claude` auto-memory, so `/sync-memory` can translate 1:1.

```
---
name: <kebab-slug>            # matches the filename stem
description: <one-line summary used for relevance at recall>
type: domain | convention | reference
---

<the fact. Link related facts/decisions with [[wikilink]].>
```

Types:
- `domain` — architecture, codebase structure, domain model/knowledge.
- `convention` — how-we-do-it-in-this-repo (process/style specific to the repo).
- `reference` — pointers to external resources (URLs, dashboards, docs).

No `decision` type — decisions live in `decisions-log.md`. **Never write secrets** (keys,
tokens, `.env` values) into memory — repos may be public.

## Index format (`MEMORY.md`)

Grouped by type; one line per fact:
`- [<name>](<slug>.md) — <hook from description>`

## Retrieval

`/project-init` adds ONE line to the repo's CLAUDE.md: `@docs/memory/MEMORY.md`. This is Claude
Code's import syntax — a **bare `@` followed by a repo-relative path** (like CLAUDE.md's other
`@file` imports), **not** an `@import` keyword. `@import …` imports nothing.
- Only the **index** is imported (always-loaded, so the model knows what exists). Full fact
  files are read **on demand**. NEVER import fact files.
- **Scale ceiling:** when the index grows large (well past a few dozen facts), switch the
  CLAUDE.md line from import to a prose pointer ("see `docs/memory/MEMORY.md`") to bound
  per-session cost. Documented, not enforced.

## Concurrency

`MEMORY.md` is append-heavy; `/project-init` declares `docs/memory/MEMORY.md merge=union` in the
repo's `.gitattributes`. Fact files are one-per-file, so they rarely conflict.
