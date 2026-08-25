---
name: memory-lint
description: Check this repo's docs/memory/ for index/file drift, invalid frontmatter, slug mismatches, and broken wikilinks. Use after editing memory by hand, before committing memory changes, or when memory recall seems stale.
user-invocable: true
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

To lint the workspace tier itself, run again with `--root "<workspace_root>/memory"`,
`--link-root` pointing at each repo's `_meta/<repo>/memory`, and — because workspace-tier facts
may reference `A-`/`D-` records in any repo tier — one `--tracking-root` per repo tier
(the flag is repeatable; a glob supplies them):

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" \
      --root "<workspace_root>/memory" \
      $(for d in "<workspace_root>"/*/project-tracking; do printf -- '--tracking-root %q ' "$d"; done) \
      $(for d in "<workspace_root>"/*/memory; do printf -- '--link-root %q ' "$d"; done)

It mechanically covers **index ↔ file parity** (unindexed files, dangling `MEMORY.md` entries)
and **wikilink resolution** (against fact files *and* `A-`/`D-` records in
`<data_root>/project-tracking/` — `docs/project-tracking/` in in-repo mode), plus graph health:
orphans, weakly-linked notes, hubs, naming drift,
duplicate `name:`/basenames, and typed-edge coverage (`[[supersedes::target]]` predicates — see
`conventions/memory.md`). Any BROKEN LINK, unindexed file, or dangling entry is a FAIL.
(`--check` is the CI/pre-commit form of the same gate.)

## Step 1b - citation freshness and the memory/tracking boundary

Two further deterministic gates. Run both; report their findings alongside Step 1.

**Citation freshness** - verify `file:NNN` and `` `path::symbol` `` citations against the source
they point at:

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" --check-citations \
      --root "<data_root>/memory" --src-root "$(git rev-parse --show-toplevel)"

`--src-root` is the code the facts cite - the repo root in both modes (in sidecar mode the
`_meta/<repo>/memory` facts cite that same repo's code). It reports **STALE** (a line citation
whose line is outside the cited symbol's definition block, or a `` `path::symbol` `` anchor whose
symbol no longer exists - a FAIL, exit 1) and, non-fatally, **AMBIGUOUS** (a bare basename matching
several files - add a path prefix), **UNRESOLVABLE** (file not found under src-root), and
**UNANCHORED** (a line citation with no adjacent backticked symbol to check). The last three are not
failures; they mark citations that need a path prefix or a symbol anchor to become checkable.

**UNVERIFIED-SINCE** (also non-fatal) is the freshness bucket: the fact carries
`verified-against: <sha> <date>`, its citation still resolves, but a cited file changed after that
sha — nobody has confirmed the claim since the code moved. Re-read the cited code; if the fact still
holds, update the sha and date. Facts without the field are never reported, and the bucket never
fails the lint. It degrades to a one-line "unverifiable" note when src-root is not a git repo or the
recorded sha is unknown there. Prefer
the rot-proof `` `path::symbol` `` anchor form when adding citations. When linting the **workspace
tier** (`_meta/memory/`), whose facts may cite code across several repos, expect AMBIGUOUS under a
single `--src-root`; that is normal - add a path prefix in the citation, or point `--src-root` at the
one repo you are checking.

**Boundary drift** - keep measured evidence and long detail out of tracking record bodies:

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" --check-tracking \
      --tracking-root "<data_root>/project-tracking"

Flags any `A-`/`D-` record whose body exceeds `--max-record-lines` (default 40) or embeds a
`**MEASURED**` block; both belong in a memory fact (`conventions/project-tracking.md` § the
memory/tracking boundary). Exit 1 on findings.

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
