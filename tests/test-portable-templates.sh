#!/usr/bin/env bash
# Content assertions for the portable templates (deps: bash + coreutils only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
MAN="$ROOT/templates/memory/README.md"
AGENTS="$ROOT/templates/AGENTS.md"
IDX="$ROOT/templates/memory/MEMORY.md"
pass=0; fail=0
assert() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }
has() { grep -qF -e "$2" "$1"; }
hasre() { grep -qE -e "$2" "$1"; }

# manual exists and covers the required sections
[ -f "$MAN" ]; assert "manual exists" $?
has "$MAN" "name:"; assert "manual: schema frontmatter" $?
hasre "$MAN" "domain \| convention \| reference|domain, convention"; assert "manual: type vocabulary" $?
has "$MAN" "AGENTS.md"; assert "manual: boundary names AGENTS.md" $?
has "$MAN" "memory_graph.py --check"; assert "manual: validator command" $?
has "$MAN" "[[supersedes::"; assert "manual: typed wikilink grammar" $?
has "$MAN" "broken wikilink"; assert "manual: validator checks in prose" $?
has "$MAN" "source-verified"; assert "manual: provenance tiers" $?
has "$MAN" "/ingest"; assert "manual: names the Claude shortcut" $?

# AGENTS.md exists, thin entry point with the managed section
[ -f "$AGENTS" ]; assert "agents exists" $?
has "$AGENTS" "docs/memory/MEMORY.md"; assert "agents: points to index" $?
has "$AGENTS" "docs/memory/README.md"; assert "agents: points to manual" $?
has "$AGENTS" "## Stale priors (training vs reality)"; assert "agents: managed gotcha heading" $?
has "$AGENTS" "Always-loaded"; assert "agents: always-loaded section" $?

# MEMORY.md header points at the local manual, not the plugin cache
has "$IDX" "./README.md"; assert "index header points at local manual" $?
grep -qF "conventions/memory.md" "$IDX" && { echo "FAIL: index still points at plugin cache"; fail=$((fail+1)); } || { echo "PASS: index no plugin-cache pointer"; pass=$((pass+1)); }

# no em dashes in the new templates
for f in "$MAN" "$AGENTS"; do
  if grep -qP '\x{2014}' "$f"; then echo "FAIL: em dash in $f"; fail=$((fail+1)); else echo "PASS: no em dash in $(basename "$f")"; pass=$((pass+1)); fi
done

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
