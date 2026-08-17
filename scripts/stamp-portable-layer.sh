#!/usr/bin/env bash
# Stamp the portable (vendor-neutral) layer into a memory base. Deterministic core shared by
# /project-init and /make-portable. Add-only and idempotent: copies the operator's manual and the
# vendored validator into the base, and (in-repo) ensures AGENTS.md + the CLAUDE.md bridge imports
# exist. Never modifies facts or the index. The confirm gate, mode resolution, and index/INDEX
# enrichment are the caller's job.
# With --refresh, the two plugin-owned files (manual, vendored validator) are re-copied from the
# shipped versions so an older base can pick up new validator modes. AGENTS.md is never refreshed:
# it carries user-authored stale-priors content.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manual_template="$here/../templates/memory/README.md"
agents_template="$here/../templates/AGENTS.md"
graph_src="$here/memory_graph.py"
manual_dest=""; graph_dest=""; agents=""; claude_bridge=""; refresh=0
usage="usage: stamp-portable-layer.sh --manual-dest P --graph-dest P [--agents P] [--claude-bridge P] [--refresh]"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manual-dest) manual_dest="$2"; shift 2;;
    --graph-dest) graph_dest="$2"; shift 2;;
    --agents) agents="$2"; shift 2;;
    --claude-bridge) claude_bridge="$2"; shift 2;;
    --manual-template) manual_template="$2"; shift 2;;
    --agents-template) agents_template="$2"; shift 2;;
    --graph-src) graph_src="$2"; shift 2;;
    --refresh) refresh=1; shift;;
    *) echo "$usage" >&2; exit 2;;
  esac
done
if [ -z "$manual_dest" ] || [ -z "$graph_dest" ]; then
  echo "$usage" >&2
  exit 2
fi

# src dest label refreshable(0|1) — refreshable marks a plugin-owned file that --refresh may
# overwrite; user-owned files pass 0 and are never rewritten.
stamp_file() {
  local src="$1" dest="$2" label="$3" refreshable="${4:-0}"
  if [ ! -f "$src" ] || [ ! -r "$src" ]; then echo "error: missing source: $src" >&2; exit 1; fi
  if [ -f "$dest" ]; then
    if [ "$refresh" = 1 ] && [ "$refreshable" = 1 ]; then
      if cmp -s "$src" "$dest"; then echo "$label: current"; return 0; fi
      cp "$src" "$dest" || { echo "error: cannot write $dest" >&2; exit 1; }
      echo "$label: refreshed"; return 0
    fi
    if [ "$refresh" = 1 ]; then echo "$label: skipped"; else echo "$label: exists"; fi
    return 0
  fi
  mkdir -p "$(dirname "$dest")" || { echo "error: cannot create dir for $dest" >&2; exit 1; }
  cp "$src" "$dest" || { echo "error: cannot write $dest" >&2; exit 1; }
  echo "$label: created"
}

stamp_file "$manual_template" "$manual_dest" "manual" 1
stamp_file "$graph_src" "$graph_dest" "graph" 1

if [ -n "$agents" ]; then
  stamp_file "$agents_template" "$agents" "agents" 0
fi

if [ -n "$claude_bridge" ]; then
  if [ ! -f "$claude_bridge" ]; then
    mkdir -p "$(dirname "$claude_bridge")" || { echo "error: cannot create dir for $claude_bridge" >&2; exit 1; }
    printf '# Project instructions\n\n' > "$claude_bridge" || { echo "error: cannot write $claude_bridge" >&2; exit 1; }
  fi
  for line in "@AGENTS.md" "@docs/memory/MEMORY.md"; do
    if grep -qF -e "$line" "$claude_bridge"; then
      echo "bridge: present $line"
    else
      printf '%s\n' "$line" >> "$claude_bridge"
      echo "bridge: added $line"
    fi
  done
fi

exit 0
