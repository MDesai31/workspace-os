# Memory base - operator's manual

This directory is a durable, version-controlled knowledge base about this codebase. It is plain
markdown: one fact per file, plus a hand-curated index (`MEMORY.md`). No database, no vector store,
no proprietary index. Any agent or human can read and maintain it with basic file operations.

The Claude Code plugin `workspace-os` provides shortcuts (`/ingest`, `/memory-lint`, `/memory-search`)
that automate the steps below. You do not need them. This manual is the whole procedure.

## The fact schema

Each fact is one file, `<slug>.md`, where `<slug>` is short-kebab-case:

```
---
name: <slug>            # MUST equal the filename stem
description: <one-line summary used to judge relevance at recall>
type: domain | convention | reference
---

<the fact. Cite evidence (file:line). Link related facts/records with [[wikilink]].>
```

Types: `domain` (architecture, structure, domain model), `convention` (how-we-do-it-here),
`reference` (pointers to external resources). Decisions (a choice + why) do NOT go here; they belong
in the project-tracking decisions log.

## Where a fact belongs (the boundary rule)

> "If an agent would make a costly mistake before it went looking, the fact must be seen up front."

- **Costly-if-unseen -> your always-loaded instruction file.** That is `AGENTS.md` (read by most
  agents) or, for Claude Code, `CLAUDE.md`. In this repo `CLAUDE.md` imports `AGENTS.md`, so
  `AGENTS.md` is the single canonical home. Put such facts there as imperative bullets.
- **Only needed when the topic comes up -> this base**, read on demand.

## How to add a fact (what `/ingest` automates)

1. Apply the boundary rule. If costly-first, write an imperative bullet in `AGENTS.md` instead and stop.
2. Otherwise write `docs/memory/<slug>.md` with the frontmatter above; `name:` must match the stem.
3. Add one line to `MEMORY.md` under the matching type section:
   `- [<name>](<slug>.md) - <hook from the description>`
4. Never write secrets (keys, tokens, `.env` values).

## The wikilink grammar

- Plain `[[target]]` - a "related" edge.
- Typed predicate `[[supersedes::target]]`, `[[blocked_by::target]]`, `[[depends_on::target]]`, etc.
- Aliased `[[type::target|label]]`.
- Targets may be fact slugs or tracking records (`A-...`, `D-...`).

## Checking integrity (what `/memory-lint` automates)

Run the vendored validator (stdlib Python, no dependencies), which lives in a sibling `docs/tools/`
folder (a sibling of the memory base `docs/memory/`, kept separate from the fact files):

`python docs/tools/memory_graph.py --check`

run from the repo root (its default `--root` is `docs/memory`). In a sidecar `_meta` layout run
`python _meta/tools/memory_graph.py --check --root _meta/memory` and `--root _meta/<repo>/memory`
(`<repo>` is the repo-folder name under `_meta/`), with `--link-root <path>` for cross-tier links,
which tells the validator where to resolve wikilink targets when facts and the index live in
different tiers. It reports and exits non-zero
on any of these, which you can also verify by hand:

- **broken wikilink** - a `[[target]]` whose target has no fact file and is not a known tracking record.
- **index parity** - every fact file has exactly one `MEMORY.md` line, and every line has a file.
- **orphans** - facts nothing links to (informational).
- **typed-edge coverage** - how many links carry a predicate (informational).

## Provenance

Two trust tiers, marked in the fact body:
- **source-verified** - distilled from something an agent actually read (code, a CLI, a captured file).
- **attested** - from a person or a console the agent could not reach; include a re-verify command if
  one exists and a dated stamp.

## Deferred (not yet portable)

Project-tracking records (`action-items`, `decisions-log`) are maintained the same plain-markdown way
but their schema is not yet documented here. Enforcement hooks (guardrails, auto-lint) are Claude Code
runtime features and do not travel; a successor agent has the data and this procedure, not the automation.
