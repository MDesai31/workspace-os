---
name: memory-lint
description: Check this repo's docs/memory/ for index/file drift, invalid frontmatter, slug mismatches, and broken wikilinks. Use after editing memory by hand, before committing memory changes, or when memory recall seems stale.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Edit, Bash, Glob, Grep
---

# Memory Lint

Verify the integrity of this repo's `<data_root>/memory/` (`docs/memory/` in in-repo mode). The
schema and rules live in this plugin's `conventions/memory.md`.

**Prerequisite — resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` (see `conventions/data-root.md`).
Memory lives at `<data_root>/memory/`; if missing, say so and stop. Announce the resolved mode.

## Step 1 — run the deterministic pass (the graph script)

Resolve the plugin root via `${CLAUDE_PLUGIN_ROOT}` when set, else the plugin's install
directory.

In-repo mode (from the repo root):

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py"

Sidecar mode — pass the resolved paths, plus the workspace tier as a link root so cross-tier
wikilinks resolve (conventions/memory.md § two-tier memory):

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" \
      --root "<data_root>/memory" \
      --tracking-root "<data_root>/project-tracking" \
      --link-root "<workspace_root>/memory"

To lint the workspace tier itself, run again with `--root "<workspace_root>/memory"` and
`--link-root` pointing at each repo's `_meta/<repo>/memory`.

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
