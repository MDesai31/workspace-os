---
name: memory-lint
description: Check this repo's docs/memory/ for index/file drift, invalid frontmatter, slug mismatches, and broken wikilinks. Use after editing memory by hand, before committing memory changes, or when memory recall seems stale.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Edit, Bash, Glob, Grep
---

# Memory Lint

Verify the integrity of this repo's `docs/memory/`. The schema and rules live in this plugin's
`conventions/memory.md`.

**Prerequisite:** the repo must have `docs/memory/`. If missing, say so and stop.

## Checks

1. **Index ↔ files** — every `docs/memory/*.md` (except `MEMORY.md`) has exactly one entry in
   `MEMORY.md`, and every index entry points to an existing file. Report **orphans** (file with
   no entry) and **dangling** entries (entry with no file).
2. **Frontmatter** — each fact file has valid frontmatter with `name`, `description`, and
   `type` ∈ `domain|convention|reference`. Report missing/invalid.
3. **Slug match** — each file's `name:` equals its filename stem. Report mismatches.
4. **Wikilinks** — every `[[target]]` resolves to an existing `docs/memory/<target>.md`, or a
   `D-`/`A-` record in `docs/project-tracking/`. Report unresolved links.
5. **Report** a `PASS`/`FAIL` summary listing the specific offenders. Offer to fix mechanical
   issues (missing index line, slug/name mismatch) but never edit fact bodies. Do **not** commit.
