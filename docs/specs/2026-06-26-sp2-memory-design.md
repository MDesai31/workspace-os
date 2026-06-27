# SP2 — Repo-canonical shared memory + personal-memory bridge

- **Status:** approved (design); ready for implementation planning
- **Date:** 2026-06-26
- **Slice:** SP2 of workspace-os (follows SP1 project-tracking)
- **Supersedes:** the SP2 sketch in `docs/project-tracking/ideas.md` (3 skills + guard hooks, auto-memory-as-source). That sketch is replaced by this design — see "How this differs from the original sketch."

## 1. Purpose

Give each repo a **canonical, shared, version-controlled knowledge base** — durable facts about *that codebase* (architecture, domain model, non-obvious rationale) that travel with the repo to every collaborator and every machine via git, and are readable by Claude in that project's sessions.

Two pains this solves, both real:
- **Collaboration.** klapp is built with a collaborator (Thomas). Shared, PR-reviewable project knowledge belongs *with the repo*, not in one person's machine-local store.
- **Travel.** Repo knowledge in machine-local `~/.claude` auto-memory does not follow you to another machine; in git it does.

## 2. Design principle: general plugin, not a bespoke fit

`workspace-os` is a **general standalone plugin** meant to serve many setups — solo or team, one machine or many, with or without harness auto-memory, public or private repos. Therefore the canonical store cannot be assumed to be a personal `~/.claude` memory. The thing that is **universal** is the repo itself.

This inverts the colleague's direction (his model: personal memory → curated mirror in repo, because his knowledge originates in private exploration and the repo copy exists to share a safe subset). Here:

> **The in-repo `docs/memory/` is the canonical, shared store.** Personal auto-memory is an *optional bridge* for individuals who keep one — never the source of truth.

We take the colleague's *pattern* (typed memory dir + index + on-demand retrieval + capture/lint skills), not his scale machinery.

## 3. The boundary rule — "reconcile, don't duplicate"

This is the requirement everything else rests on. Three in-repo stores already exist or are introduced; each fact has exactly one home, decided by an operational test — not a vibe.

**Decision test for every durable fact:**

> *"If the model didn't see this until it went looking, would it make a costly mistake first?"*
> - **Yes → `CLAUDE.md`** (always-loaded, imperative "how to work here").
> - **No — it just needs to be found when the topic comes up → `docs/memory/`** (on-demand reference knowledge).

**Hard rules:**
- **SP2 does NOT migrate existing CLAUDE.md content.** `docs/memory/` is a larger consultable body *alongside* CLAUDE.md. Existing CLAUDE.md notes stay put unless they fail the test.
- **Decisions are not memory.** The chronological record of decisions lives in `docs/project-tracking/decisions-log.md` (SP1). A memory fact may `[[wikilink]]` to a `D-` record but never restates it.

**Worked example — klapp's real CLAUDE.md (run through the test):**

| Existing CLAUDE.md content | Costly-first if unseen? | Home |
|---|---|---|
| Prisma 6: import client from `@/generated/prisma/client` (NOT `@prisma/client`) | Yes — model mis-imports before checking | **stays in CLAUDE.md** |
| `searchParams` is a `Promise` — always `await` | Yes — wrong code on first write | **stays in CLAUDE.md** |
| Docker DB start command / test DB URL | Yes — needed to run anything | **stays in CLAUDE.md** |
| *Why* Auth.js v5 beta was chosen over alternatives | No — reference rationale, consult if revisiting auth | **`docs/memory/`** (new) |
| Domain glossary (job lifecycle states, who Thomas/Klaus are) | No — consult when the topic arises | **`docs/memory/`** (new) |

The takeaway: under the test, **none of klapp's current CLAUDE.md content moves**. `docs/memory/` is populated by *new* reference-grade facts going forward. "Don't duplicate" is now checkable, not aspirational.

## 4. The store (data layer)

Location: **`<repo>/docs/memory/`** (sits beside `docs/project-tracking/` from SP1).

```
docs/memory/
  MEMORY.md          # one-line-per-fact index, grouped by type
  <slug>.md          # one fact per file
```

**Fact file schema** (same shape as `~/.claude` auto-memory, so the bridge is trivial):

```markdown
---
name: <kebab-slug>
description: <one-line summary — used for relevance at recall>
type: domain | convention | reference
---

<the fact. Link related facts and decisions with [[wikilink]].>
```

- **Types:** `domain` (architecture / codebase / domain knowledge), `convention` (how-we-do-it-in-this-repo), `reference` (pointers to external resources). **No `decision` type** — those live in `decisions-log.md`.
- **No secrets, ever** (these repos include public klapp).
- Start flat (type in frontmatter, index groups by type). Add subdirs only if a repo's memory grows enough to warrant it.

## 5. Retrieval (how facts reach context)

`/project-init` adds **one** line to the repo's `CLAUDE.md`:

```
@import docs/memory/MEMORY.md
```

- We `@import` the **index only** — one line per fact. The model always *knows what knowledge exists*, then reads the full fact file on demand.
- **Never `@import` fact files.** Only the index is always-loaded.
- **Deliberate deviation from the colleague**, who uses a pure prose pointer ("see memory/MEMORY.md") because at 100+ files even the index is heavy. For small/medium repos, @import-ing the index buys *reliability* (the model cannot consult knowledge it doesn't know exists) at a per-session cost that grows with the index.
- **Scale ceiling (documented, not enforced):** when a repo's index grows large, switch the `@import` to a prose pointer. This keeps the "general plugin" claim honest for a Zach-sized repo.

## 6. Skills — division of labor

The division is what keeps memory upkeep from becoming a chore.

- **`/remember`** — author a *new* project fact **straight into `docs/memory/`** + update `MEMORY.md`. The primary capture path. Project/domain facts are captured here directly, so they never need promoting later.
- **`/sync-memory`** — the **bridge**: migrate an *existing* fact from `~/.claude` auto-memory into a repo's `docs/memory/` (manual, one fact at a time, with confirmation). Narrow by design: git already handles travel, so this is occasional cleanup for facts that landed in the wrong store — including ones Claude auto-saves to `~/.claude` mid-session.
- **`/memory-lint`** — verify `MEMORY.md` index ↔ files consistency and `[[wikilink]]` integrity, so on-demand retrieval doesn't rot.

**The promotion-treadmill decision:** the harness auto-saves project facts to `~/.claude`, which would otherwise create a constant promote chore. We do not (cannot) change the harness. Instead the convention is explicit: **project/domain facts → `/remember` straight into repo memory; `~/.claude` stays for user/feedback/cross-project facts.** `/sync-memory` is the safety valve for the wrong-store cases, expected to be occasional.

**Warn-only secret-scan hook** on writes to `docs/memory/`: scans for obvious secret patterns (keys, `.env`-style values) and warns. **Honest caveat:** it only fires for whoever runs Claude Code — a collaborator's manual commit bypasses it — so it is a *nicety*, not the protection. The real guard for public klapp is review + the no-secrets convention.

`/project-init` is extended to scaffold `docs/memory/` (MEMORY.md + a README/seed) and add the `@import` line to CLAUDE.md.

## 7. Sequencing

B′ is the largest slice so far (3 skills + hook + init change + schema). Ship a working core, dogfood, then finish.

- **SP2a (core):** store schema + `/project-init` extension + `/remember` + retrieval (`@import` index). → **dogfood on klapp** before building more.
- **SP2b (round-out):** `/memory-lint` + `/sync-memory` + warn-only secret hook.

## 8. Non-goals (YAGNI / deliberately not the colleague's machinery)

- No manifest-driven bulk mirror (`.sync-manifest.json` + regen script). `docs/memory/` is canonical, not a derived mirror.
- No HTML memory-graph rendering, no intake ledger / proposals workflow.
- No per-agent or per-team memory trees.
- No blocking write-guard (warn only).
- No migration of existing CLAUDE.md content.

## 9. How this differs from the original `ideas.md` sketch

| Original sketch | This design |
|---|---|
| Auto-memory is the source; repo gets a curated mirror | **Repo `docs/memory/` is canonical**; auto-memory is an optional bridge |
| `/ingest`, `/memory-lint`, `/sync-memory` + guard hooks | `/remember`, `/memory-lint`, `/sync-memory` + **warn-only** hook |
| Memory home undecided (in-repo vs auto-memory) | **`docs/memory/`**, decided |
| "Reconcile" left abstract | Operational **decision test** + worked klapp example |

## 10. Success criteria

- `/project-init` on a fresh repo scaffolds `docs/memory/` and wires the `@import`.
- `/remember "<fact>"` writes a schema-valid fact file and a matching `MEMORY.md` index line.
- The `@import`-ed index appears in a new session's context; a full fact is readable on demand.
- `/memory-lint` flags an index/file mismatch and a broken wikilink.
- `/sync-memory` moves a named `~/.claude` fact into a repo's `docs/memory/` with confirmation, refusing on detected secrets (warn).
- The boundary rule + klapp worked example are documented in the plugin so the convention is reusable.
