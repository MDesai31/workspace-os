---
name: make-portable
description: Add the portable (vendor-neutral) layer to an already-initialized memory base so a non-Claude agent can read and maintain it. Stamps the operator's manual, vendors memory_graph.py, and (in-repo) ensures AGENTS.md + the CLAUDE.md bridge. Add-only and idempotent by default; the `refresh` argument re-copies the plugin-owned manual + validator so a base stamped at an older version picks up new validator modes. Never touches facts or the index.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
argument-hint: "[refresh]"
---

# Make Portable

Add the vendor-neutral portable layer to an EXISTING memory base. Idempotent and add-only: it never
modifies facts or the `MEMORY.md` index. For a brand-new repo use `/project-init` instead (it stamps
this layer as part of bootstrap).

## Steps

0. **Parse `$ARGUMENTS`.** No argument = default add-only mode. The bare word `refresh` selects
   refresh mode (below). Any other token → say so, name the one valid argument, and stop.
1. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and
   parse `mode`/`data_root` (+ `workspace_root` in sidecar). Announce the mode.
2. **Refuse if there is no base.** If `<data_root>/memory/` does not exist, stop and point the user
   at `/project-init`.
2a. **(refresh mode only) Propose, then confirm.** Refresh is the only mode here that overwrites an
   existing file, so it gets a gate. Classify each plugin-owned file three ways against its shipped
   source (`${CLAUDE_PLUGIN_ROOT}/templates/memory/README.md` → the manual dest;
   `${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py` → the graph dest) — test existence FIRST, then
   `cmp -s`; an absent dest is not a difference:
   - **absent** → "will be created" (purely additive; no overwrite warning)
   - **exists and differs** → "will be overwritten" (the only case the confirm is really about)
   - **exists and identical** → `current`, nothing to do
   If nothing is absent and nothing differs, say the base is already current and stop without
   writing. Otherwise show the classified list and wait for confirmation. Warn that a hand-edited
   manual would be replaced ONLY when the manual is in the overwritten group, and note git is the
   undo.
3. **Stamp the portable layer** via the shared stamper (append `--refresh` in refresh mode):
   - *(in-repo)*:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest docs/memory/README.md --graph-dest docs/tools/memory_graph.py --agents AGENTS.md --claude-bridge CLAUDE.md`
   - *(sidecar)*:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest <workspace_root>/conventions/memory-base-guide.md --graph-dest <workspace_root>/tools/memory_graph.py`
     then enrich `<workspace_root>/INDEX.md` with a pointer to `conventions/memory-base-guide.md` and
     a one-line "Link grammar" note (add-only; skip if already present). Never write the repo tree.
4. **Report** each stamper status line, the mode, and that facts/index were untouched. Status words:
   `created` (was absent), `exists` (present, add-only mode), `refreshed` (overwritten from the
   shipped version), `current` (refresh requested, already identical), `skipped` (user-owned, never
   refreshed — `AGENTS.md`). In sidecar mode do not commit unless the user asks; in in-repo mode
   leave changes staged-ready.

## What refresh does and does not touch

- **Refreshed** (plugin-owned): the operator's manual and the vendored `memory_graph.py`. They
  version together — the manual documents the validator's lint modes, so refreshing one without the
  other leaves the base able to run a mode it is not documented to have.
- **Never refreshed:** `AGENTS.md` carries user-authored stale-priors content, so an EXISTING one is
  reported `skipped` rather than overwritten. An absent `AGENTS.md` is still created, in refresh mode
  as in the default — refresh withholds overwrites, it does not withhold the initial stamp. The
  `CLAUDE.md` bridge needs nothing: it is already additive and idempotent.
- **Never touched, in any mode:** facts and the `MEMORY.md` index. The stamper only ever writes the
  paths its flags name, so this is structural, not a guard.
