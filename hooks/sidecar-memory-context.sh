#!/usr/bin/env bash
# workspace-os sidecar memory surfacing — SessionStart hook.
# Sidecar mode: emit the workspace-tier MEMORY.md then the repo-tier MEMORY.md on stdout
# (SessionStart stdout is added to session context) — general before specific, spec §6.
# In-repo mode the CLAUDE.md @import covers retrieval: print nothing. Fail open always.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out="$(bash "$HERE/../scripts/resolve-data-root.sh" 2>/dev/null)" || exit 0
mode="$(printf '%s\n' "$out" | sed -n 's/^mode=//p')"
[ "$mode" = "sidecar" ] || exit 0
data_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
ws_root="$(printf '%s\n' "$out" | sed -n 's/^workspace_root=//p')"

if [ -n "$ws_root" ] && [ -f "$ws_root/memory/MEMORY.md" ]; then
  printf '## workspace-os memory — workspace tier (%s)\n' "$ws_root/memory/MEMORY.md"
  cat "$ws_root/memory/MEMORY.md"
  printf '\n'
fi
if [ -n "$data_root" ] && [ -f "$data_root/memory/MEMORY.md" ]; then
  printf '## workspace-os memory — repo tier (%s)\n' "$data_root/memory/MEMORY.md"
  cat "$data_root/memory/MEMORY.md"
fi
exit 0
