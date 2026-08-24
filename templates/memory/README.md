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
verified-against: <sha> <YYYY-MM-DD>     # optional
applies-to: branch:<name> | repo:<name>  # optional
---

<the fact. Cite evidence (file:line). Link related facts/records with [[wikilink]].>
```

Types: `domain` (architecture, structure, domain model), `convention` (how-we-do-it-here),
`reference` (pointers to external resources). Decisions (a choice + why) do NOT go here; they belong
in the project-tracking decisions log.

Optional provenance fields:

- `verified-against: <sha> <YYYY-MM-DD>`: the commit of the **code repository this fact cites**
  (not this memory repo) at which the fact was last confirmed, plus the date. Update it whenever
  you re-read the cited code and confirm the fact still holds. `memory_graph.py --check-citations`
  reports facts whose cited files changed after that commit as UNVERIFIED-SINCE. Advisory: it never
  fails the check.
- `applies-to: branch:<name>` or `applies-to: repo:<name>`: use only when a fact is true on one
  branch or in one repo but not others. The prefix is required. Omit the field entirely for the
  normal case (true everywhere in this repo).

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

### Keeping citations honest

Two more checks the same validator runs, so a citation to code does not silently rot:

- **Citation freshness** - `python docs/tools/memory_graph.py --check-citations --root docs/memory
  --src-root .` (with `--src-root` pointing at the code the facts cite) verifies that `file:NNN` and
  `` `path::symbol` `` citations still land on the right symbol. It reports STALE (the cited line is
  outside the symbol's definition block, or a `` `path::symbol` `` anchor whose symbol is gone) and,
  non-fatally, AMBIGUOUS (a bare filename matching several files - add a path prefix), UNRESOLVABLE
  (file not found under src-root), and UNANCHORED (a `file:NNN` with no adjacent backticked symbol to
  check). Prefer the `` `path::symbol` `` anchor form when you add a citation: it survives line-number
  drift, so it never goes stale on an edit that only moves lines.
- **Boundary drift** - `python docs/tools/memory_graph.py --check-tracking --tracking-root
  docs/project-tracking` flags a tracking record whose body has grown too large or embeds a
  `**MEASURED**` block. Measured evidence and long detail belong in a memory fact here, not in a
  tracking record body: tracking says what to do, memory says what is true.

## Provenance

Two trust tiers, marked in the fact body:
- **source-verified** - distilled from something an agent actually read (code, a CLI, a captured file).
- **attested** - from a person or a console the agent could not reach; include a re-verify command if
  one exists and a dated stamp.

## Deferred (not yet portable)

Project-tracking records (`action-items`, `decisions-log`) are maintained the same plain-markdown way
but their schema is not yet documented here. Enforcement hooks (guardrails, auto-lint) are Claude Code
runtime features and do not travel; a successor agent has the data and this procedure, not the automation.
