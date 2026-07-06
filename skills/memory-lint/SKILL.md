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

## Step 1 — run the deterministic pass (the graph script)

Run this plugin's `scripts/memory_graph.py` from the repo root (resolve the plugin root via
`${CLAUDE_PLUGIN_ROOT}` when set, else the plugin's install directory):

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py"
```

It mechanically covers **index ↔ file parity** (unindexed files, dangling `MEMORY.md` entries)
and **wikilink resolution** (against fact files *and* `A-`/`D-` records in
`docs/project-tracking/`), plus graph health: orphans, weakly-linked notes, hubs, naming drift,
duplicate `name:`/basenames, and typed-edge coverage (`[[supersedes::target]]` predicates — see
`conventions/memory.md`). Any BROKEN LINK, unindexed file, or dangling entry is a FAIL.
(`--check` is the CI/pre-commit form of the same gate.)

## Step 2 — model checks (what the script can't judge)

1. **Frontmatter** — each fact file has valid frontmatter with `name`, `description`, and
   `type` ∈ `domain|convention|reference`. Report missing/invalid.
2. **Slug match** — each file's `name:` equals its filename stem. Report mismatches.
3. **Content-level review** — only when asked or when something looks off: near-duplicate facts,
   stale claims. These are judgment calls, deliberately not in the script.

## Step 3 — report

One merged `PASS`/`FAIL` summary listing the specific offenders from both passes. Offer to fix
mechanical issues (missing index line, slug/name mismatch, a mistyped wikilink) but never edit
fact bodies. Do **not** commit.
