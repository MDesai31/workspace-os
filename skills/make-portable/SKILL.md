---
name: make-portable
description: Add the portable (vendor-neutral) layer to an already-initialized memory base so a non-Claude agent can read and maintain it. Stamps the operator's manual, vendors memory_graph.py, and (in-repo) ensures AGENTS.md + the CLAUDE.md bridge. Add-only and idempotent; never touches facts or the index.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
argument-hint: "(no args - operates on the current repo's resolved memory base)"
---

# Make Portable

Add the vendor-neutral portable layer to an EXISTING memory base. Idempotent and add-only: it never
modifies facts or the `MEMORY.md` index. For a brand-new repo use `/project-init` instead (it stamps
this layer as part of bootstrap).

## Steps

1. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and
   parse `mode`/`data_root` (+ `workspace_root` in sidecar). Announce the mode.
2. **Refuse if there is no base.** If `<data_root>/memory/` does not exist, stop and point the user
   at `/project-init`.
3. **Stamp the portable layer** via the shared stamper:
   - *(in-repo)*:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest docs/memory/README.md --graph-dest docs/tools/memory_graph.py --agents AGENTS.md --claude-bridge CLAUDE.md`
   - *(sidecar)*:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest <workspace_root>/conventions/memory-base-guide.md --graph-dest <workspace_root>/tools/memory_graph.py`
     then enrich `<workspace_root>/INDEX.md` with a pointer to `conventions/memory-base-guide.md` and
     a one-line "Link grammar" note (add-only; skip if already present). Never write the repo tree.
4. **Report** each stamper status line (created vs exists), the mode, and that facts/index were untouched.
   In sidecar mode do not commit unless the user asks; in in-repo mode leave changes staged-ready.
