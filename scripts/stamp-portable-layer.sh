#!/usr/bin/env bash
# Stamp the portable (vendor-neutral) layer into a memory base. Deterministic core shared by
# /project-init and /make-portable. Add-only and idempotent: copies the operator's manual and the
# vendored validator into the base, and (in-repo) ensures AGENTS.md + the CLAUDE.md bridge imports
# exist. Never modifies facts or the index. The confirm gate, mode resolution, and index/INDEX
# enrichment are the caller's job.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manual_template="$here/../templates/memory/README.md"
agents_template="$here/../templates/AGENTS.md"
graph_src="$here/memory_graph.py"
manual_dest=""; graph_dest=""; agents=""; claude_bridge=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manual-dest) manual_dest="$2"; shift 2;;
    --graph-dest) graph_dest="$2"; shift 2;;
    --agents) agents="$2"; shift 2;;
    --claude-bridge) claude_bridge="$2"; shift 2;;
    --manual-template) manual_template="$2"; shift 2;;
    --agents-template) agents_template="$2"; shift 2;;
    --graph-src) graph_src="$2"; shift 2;;
    *) echo "usage: stamp-portable-layer.sh --manual-dest P --graph-dest P [--agents P] [--claude-bridge P]" >&2; exit 2;;
  esac
done
if [ -z "$manual_dest" ] || [ -z "$graph_dest" ]; then
  echo "usage: stamp-portable-layer.sh --manual-dest P --graph-dest P [--agents P] [--claude-bridge P]" >&2
  exit 2
fi

copy_if_absent() { # src dest label
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$src" ] || [ ! -r "$src" ]; then echo "error: missing source: $src" >&2; exit 1; fi
  if [ -f "$dest" ]; then echo "$label: exists"; return 0; fi
  mkdir -p "$(dirname "$dest")" || { echo "error: cannot create dir for $dest" >&2; exit 1; }
  cp "$src" "$dest" || { echo "error: cannot write $dest" >&2; exit 1; }
  echo "$label: created"
}

copy_if_absent "$manual_template" "$manual_dest" "manual"
copy_if_absent "$graph_src" "$graph_dest" "graph"

if [ -n "$agents" ]; then
  copy_if_absent "$agents_template" "$agents" "agents"
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
