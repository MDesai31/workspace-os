# Memory Conventions

Single source of truth for the workspace-os memory skills (`/ingest`, `/memory-lint`,
`/memory-sync`) and the memory scaffolding in `/project-init`. Those skills follow these rules;
they do not restate them.

## What memory is

`<repo>/docs/memory/` is the repo's **canonical, shared, version-controlled** knowledge base:
durable *reference* facts about THIS codebase — architecture rationale, domain model, and
non-obvious facts looked up when a topic arises. It travels with the repo (every collaborator,
every machine) via git, **alongside** CLAUDE.md, not replacing it.

## The boundary rule — where a fact belongs

Each durable fact has exactly ONE home. Decide with this test:

> "If the model didn't see this until it went looking, would it make a costly mistake first?"
> - **YES → AGENTS.md** (always-loaded, imperative "how to work here").
> - **NO — only needed when the topic comes up → `docs/memory/`** (on-demand reference).

- A **decision** (a choice + when + why) → `docs/project-tracking/decisions-log.md` (a `D-`
  record). A memory fact may `[[wikilink]]` a `D-` record but never restates it.
- **Passive default — never bulk-migrate CLAUDE.md content** into memory via `/project-init` or
  day-to-day work; memory grows from new facts going forward. The one exception is the explicit,
  opt-in `/memory-adopt` skill, which may extract non-costly *reference* lines out of an instruction
  file (`CLAUDE.md`, `AGENTS.md`, or a resolved `@import` target) and trim them **only with
  confirmation** — see "Adopting existing docs" below.

Generic worked example: a framework's non-obvious import path — where the wrong guess silently
compiles to a broken state - is *costly-first* → **AGENTS.md**. The *rationale* for choosing that
framework is *consult-when-relevant* → **docs/memory/**.

## Two-tier memory in sidecar workspaces

In a marked workspace (`conventions/data-root.md`), memory has two tiers:

- **Repo tier** — `_meta/<repo>/memory/`: facts specific to one repo.
- **Workspace tier** — `_meta/memory/`: facts true across the whole project — shared domain
  vocabulary, the data contract between the repos, environment/infra facts, team conventions.

Each tier keeps its own `MEMORY.md` index. Retrieval surfaces the workspace tier first, then
the repo tier (general before specific), via the plugin's SessionStart hook.

**The tier test** (applied by `/ingest` after the boundary rule): *would this fact be just as
true and useful in every repo of this workspace?* → workspace tier. Otherwise → repo tier.
`/ingest` defaults to the repo tier and proposes the workspace tier when the test clearly
passes; an explicit user scope request always wins.

**Cross-tier wikilinks are allowed** (a repo fact may link `[[shared-data-contract]]` in the
workspace tier). `/memory-lint` passes the workspace tier as `--link-root` to
`scripts/memory_graph.py` so these resolve. In-repo mode has exactly one tier; nothing changes.

## Files (per target repo)

Created by `/project-init` under `<repo>/docs/memory/`:

| File | Holds | Written by |
|---|---|---|
| `MEMORY.md` | one-line-per-fact index, grouped by type | `/ingest`, `/memory-sync`, manual |
| `<slug>.md` | one fact per file | `/ingest`, `/memory-sync` |

## Fact schema

Same shape as `~/.claude` auto-memory, so `/memory-sync` can translate 1:1.

```
---
name: <kebab-slug>            # matches the filename stem
description: <one-line summary used for relevance at recall>
type: domain | convention | reference
verified-against: <sha> <YYYY-MM-DD>     # optional
applies-to: branch:<name> | repo:<name>  # optional
---

<the fact. Link related facts/decisions with [[wikilink]].>
```

Types:
- `domain` — architecture, codebase structure, domain model/knowledge.
- `convention` — how-we-do-it-in-this-repo (process/style specific to the repo).
- `reference` — pointers to external resources (URLs, dashboards, docs).

Two optional provenance fields, both absent by default:

- `verified-against: <sha> <YYYY-MM-DD>` — the commit this fact's claims were last confirmed
  against, plus the date. The sha is the **source repo being cited**, NOT the memory repo — in
  sidecar mode those are different git repos. `/memory-lint` uses it to report UNVERIFIED-SINCE:
  the citation still resolves, but the cited code has moved since anyone confirmed the claim.
  Advisory only; it never fails the lint.
- `applies-to: branch:<name>` or `applies-to: repo:<name>` — scopes a fact that is true only on one
  branch or in one repo. The `branch:`/`repo:` prefix is required (a bare `main` is ambiguous
  between a branch and a repo name). **Absent means the fact applies to the whole repo, all
  branches**, which is the normal case. Prefer naming a split inside one shared fact over two
  divergent copies; reach for this field only for the residue.

No `decision` type — decisions live in `decisions-log.md`. **Never write secrets** (keys,
tokens, `.env` values) into memory — repos may be public.

Cite evidence with a `` `path::symbol` `` anchor (preferred - it survives line-number drift) or
`path:NNN` with the symbol named in backticks nearby, and prefer a full relative path over a bare
filename so the check can resolve it. `/memory-lint` verifies citations against the source
(`memory_graph.py --check-citations`) and flags one whose symbol moved or vanished; it also guards
the memory/tracking boundary (`--check-tracking`, see `conventions/project-tracking.md`).

The canonical vendor-neutral statement of this schema and its maintenance procedure is the
portable operator's manual template (`templates/memory/README.md`), stamped into each base by
`/project-init` and `/make-portable`; this convention file is the plugin-internal source and
should stay consistent with that template.

### Typed wikilinks (optional)

A wikilink may carry a predicate — `[[supersedes::old-fact]]`, `[[blocked_by::other-fact]]` —
kept in plain markdown so the substrate stays portable while the link gains meaning. Plain
`[[target]]` stays valid (edge type "related"). Aliases compose: `[[type::target|label]]`.
Suggested vocabulary (not enforced): `supersedes`, `superseded_by`, `blocked_by`, `depends_on`,
`derived_from`, `verifies`, `contradicts`, `part_of`. Targets may be fact slugs or `A-`/`D-`
tracking records. `scripts/memory_graph.py` (the deterministic pass of `/memory-lint`) lints
resolution and reports typed-edge coverage.

### Recurring flavors

Some facts recur in a shape worth capturing consistently. Each flavor names a body shape and the
home it routes to (the boundary test above still decides the home).

**stale-prior / gotcha** - "your training prior says X; in this repo it is actually Y."
- Captured with `/ingest gotcha: <prior-vs-reality>` (or `stale-prior:`).
- Routing is the boundary test: a pure stale-prior (the model will confidently do the wrong thing)
  is usually costly-first; a "we chose differently, and why" prior is usually consult-when-relevant.
- **Costly-first -> AGENTS.md** as an imperative bullet under the managed section
  `## Stale priors (training vs reality)`:
  `- <topic>: use <Y>, NOT <X> (training prior is wrong here). <one-clause why or [[link]]>`
  The bullet is written by `/ingest` via `scripts/claude-md-upsert.sh` (idempotent, add-only) after
  an explicit confirm. **In-repo mode only:** in a sidecar workspace the repo's AGENTS.md is never
  touched, so `/ingest` tells you and stops for this case.
- **Consult-when-relevant -> `docs/memory/`** as a fact (`type: convention` unless clearly `domain`),
  body shape:
  `Training prior says <X>. In this repo it is actually <Y>. Why: <reason>. See [[<related>]].`
  with `description: training prior wrong for <topic>`.

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

## Importing from auto-memory (`/memory-sync`)

`~/.claude` auto-memory uses a different taxonomy (`user | feedback | project | reference`) than
repo memory (`domain | convention | reference`), and its types are heterogeneous — so the
auto-memory type is a **hint, not a rule**. Decide by the fact's **content**, running these gates
in order:

1. **Codebase-knowledge gate.** Is this durable knowledge *about this codebase*? If it's about the
   person (preferences, role) → **stop, leave it in `~/.claude`**.
2. **Knowledge-vs-state gate.** Is it stable *knowledge*, or *work state* (a goal, status, intent,
   TODO)? Work state → it belongs in tracking (`ideas.md` / `action-items.md`), not memory → **stop**.
3. **AGENTS.md gate** (the boundary test above): costly-if-unseen → **AGENTS.md, stop**; otherwise
   it's genuine reference knowledge → migrate, then pick the type.

Type hints (the gates decide; this only nudges the target type):

| auto-memory `type` | hint | when |
|---|---|---|
| `reference` | `reference` | almost always migrates as-is |
| `project` | `domain` | only if it's codebase/domain knowledge; a goal/status/intent → tracking, stop |
| `feedback` | `convention` | only if it's a repo-specific shared "how we work here" rule; personal/global → stop; always-apply → AGENTS.md |
| `user` | — | never migrate |

**Slug rule:** re-slug to clean kebab — strip the `project_`/`feedback_` prefix, convert `_`→`-`,
and set `name:` to match the new filename stem (e.g. `project-klapp-mvp` → `klapp-overview`).

## Adopting existing docs (`/memory-adopt`)

`/memory-adopt` bulk-applies the gates above to a repo's pre-existing docs (opt-in; the passive
default never auto-touches them). Route each chunk:

- durable codebase knowledge → a `docs/memory/` fact (`domain|convention|reference`);
- costly-if-unseen imperative → **stays put** (in the instruction file it lives in — see below);
- work-state (goal/status/TODO) → **skip** (belongs in tracking: `ideas.md`/`action-items.md`);
- about the person → **skip**.

**Candidate sources — two classes:**
- **Instruction files (always-loaded, trimmable):** `CLAUDE.md`, `AGENTS.md`, and any file reached
  by resolving `@import`s (below).
- **Free-form docs (read-only, extract-only):** `README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`,
  `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md`.

Always **exclude** `docs/memory/` and `docs/project-tracking/`. An optional path/glob argument
limits the scan to the given paths.

**Resolving `@import`s.** When scanning an instruction file, follow its bare `@path` import lines
(Claude Code import syntax) and scan the targets as further instruction files — **recursively**,
with a cycle guard (each path scanned once) and a **depth cap of 5**. **Repo-relative paths only:**
skip `@~/...`, absolute paths, and any path resolving outside the repo (note them in the report;
don't pull them in). Never follow `@docs/memory/MEMORY.md` or anything under `docs/memory/` /
`docs/project-tracking/`. Instruction-file membership is **sticky**: a file reached via `@import`
is trimmable even if it would otherwise be free-form.

**Trim rule.** Only lines that pass *as memory* (NOT costly-if-unseen) may be removed, only on
explicit confirmation, structure-preserving; imperatives are never trimmed. The trim acts on the
**instruction file the line lives in** — an `@import` target is trimmed in that target, not in
`CLAUDE.md`. **Free-form source docs are read-only** — never modified; adoption never *adds* lines
to an instruction file. **Idempotent:** before proposing, skip any fact whose slug or content is
already in `docs/memory/`. **Never write secrets.**

## Adopting a foreign memory store (`/memory-adopt foreign`)

A repo may already run a *different memory system* — a top-level `memory/` or `notes/` dir, an
Obsidian-style vault, another tool's store. Converting one is store-level, explicit
(`/memory-adopt foreign <path>`), and the source store is **read-only**: conversion copies,
never moves or deletes.

**Detection (default-scan courtesy).** The default `/memory-adopt` scan checks likely roots
(`memory/`, `notes/`, `docs/notes/`, `wiki/`, `kb/`, a dir holding `.obsidian/`) — excluding
`docs/memory/` itself — for a dir that looks like a store: **≥3 `.md` files, most short**, plus
at least one signal: YAML frontmatter, `[[wikilinks]]`, or an index/MOC file (`MEMORY.md`,
`INDEX.md`, `MOC*`, `_index*`, `00-*`). On detection: name the store, point at `foreign` mode,
and exclude its files from the normal scan. Never convert on detection alone.

**Conversion mapping (per source note):**

- **slug** — kebab-normalized filename; a frontmatter `title` wins. Collisions get a
  disambiguating suffix, called out in the proposal.
- **description** — frontmatter description/summary, else the first substantive line, condensed.
- **type** — the content gates above decide `domain|convention|reference`; foreign taxonomy
  fields are hints, never mapped 1:1 (the `/memory-sync` rule).
- **body** — preserved, not rewritten; append `Source: <original path> (adopted YYYY-MM-DD)`.
  One-fact-per-file holds: a note bundling unrelated facts is proposed as a split; a large
  procedure-shaped note routes to `/playbook adopt`; work-state routes to `/tracking-adopt` or
  skips — the deciding gate named each time.
- **links** — `[[Foo Bar]]` → `[[foo-bar]]` only when the target is adopted in the same batch;
  otherwise flatten to plain text and report it. Never write a knowingly-broken wikilink.
- **foreign frontmatter** — dropped except what maps; never copied verbatim.

Dedup, secret-scan, batch proposal, and the index update follow the normal adoption steps.
Non-markdown stores (databases, org-mode, exports) are out of scope — say so. After apply,
remind the user to retire the foreign store themselves: two live stores is the
second-store hazard; retiring is their call, never the skill's.

## Concurrency

`MEMORY.md` is append-heavy; `/project-init` declares `docs/memory/MEMORY.md merge=union` in the
repo's `.gitattributes`. Fact files are one-per-file, so they rarely conflict.
