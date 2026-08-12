#!/usr/bin/env bash
# Plain-bash tests for scripts/stamp-portable-layer.sh (deps: bash + coreutils only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/../scripts/stamp-portable-layer.sh"
MANT="$HERE/../templates/memory/README.md"
AGT="$HERE/../templates/AGENTS.md"
GSRC="$HERE/../scripts/memory_graph.py"
pass=0; fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
assert() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }
countF() { grep -cF -e "$2" "$1" 2>/dev/null || echo 0; }

# case 1: in-repo full stamp into a fresh base (validator goes to docs/tools/)
d="$TMP/repo1"; mkdir -p "$d/docs/memory"
out="$(bash "$S" --manual-dest "$d/docs/memory/README.md" --graph-dest "$d/docs/tools/memory_graph.py" \
  --agents "$d/AGENTS.md" --claude-bridge "$d/CLAUDE.md")"; ec=$?
[ "$ec" = 0 ]; assert "in-repo: exit 0" $?
[ -f "$d/docs/memory/README.md" ]; assert "in-repo: manual copied" $?
[ -f "$d/docs/tools/memory_graph.py" ]; assert "in-repo: graph vendored to tools/" $?
[ -f "$d/AGENTS.md" ]; assert "in-repo: AGENTS.md created" $?
grep -qF "## Stale priors (training vs reality)" "$d/AGENTS.md"; assert "in-repo: AGENTS managed heading" $?
grep -qF "@AGENTS.md" "$d/CLAUDE.md"; assert "in-repo: bridge @AGENTS.md" $?
grep -qF "@docs/memory/MEMORY.md" "$d/CLAUDE.md"; assert "in-repo: bridge @index" $?

# case 2: idempotent re-run adds nothing, no dup bridge lines, files unchanged
before="$(cat "$d/CLAUDE.md")"
out="$(bash "$S" --manual-dest "$d/docs/memory/README.md" --graph-dest "$d/docs/tools/memory_graph.py" \
  --agents "$d/AGENTS.md" --claude-bridge "$d/CLAUDE.md")"; ec=$?
[ "$ec" = 0 ]; assert "rerun: exit 0" $?
[ "$(countF "$d/CLAUDE.md" "@AGENTS.md")" = 1 ]; assert "rerun: bridge not duplicated" $?
[ "$before" = "$(cat "$d/CLAUDE.md")" ]; assert "rerun: CLAUDE.md unchanged" $?

# case 3: pre-existing CLAUDE.md with only the index import -> bridge adds only @AGENTS.md
d3="$TMP/repo3"; mkdir -p "$d3/docs/memory"; printf '# Proj\n\n@docs/memory/MEMORY.md\n' > "$d3/CLAUDE.md"
bash "$S" --manual-dest "$d3/docs/memory/README.md" --graph-dest "$d3/docs/tools/memory_graph.py" \
  --agents "$d3/AGENTS.md" --claude-bridge "$d3/CLAUDE.md" >/dev/null; ec=$?
[ "$ec" = 0 ]; assert "existing-claude: exit 0" $?
[ "$(countF "$d3/CLAUDE.md" "@docs/memory/MEMORY.md")" = 1 ]; assert "existing-claude: index not duplicated" $?
[ "$(countF "$d3/CLAUDE.md" "@AGENTS.md")" = 1 ]; assert "existing-claude: agents added once" $?

# case 4: sidecar-style call (manual to conventions/, graph to tools/, no agents/bridge)
d4="$TMP/meta"; mkdir -p "$d4/conventions" "$d4/tools"
out="$(bash "$S" --manual-dest "$d4/conventions/memory-base-guide.md" --graph-dest "$d4/tools/memory_graph.py")"; ec=$?
[ "$ec" = 0 ]; assert "sidecar: exit 0" $?
[ -f "$d4/conventions/memory-base-guide.md" ]; assert "sidecar: guide copied" $?
[ -f "$d4/tools/memory_graph.py" ]; assert "sidecar: graph vendored to tools/" $?
[ ! -f "$d4/AGENTS.md" ]; assert "sidecar: no AGENTS.md written" $?

# case 5: existing manual dest is left as-is (add-only)
d5="$TMP/repo5"; mkdir -p "$d5/docs/memory"; printf 'SENTINEL\n' > "$d5/docs/memory/README.md"
bash "$S" --manual-dest "$d5/docs/memory/README.md" --graph-dest "$d5/docs/memory/memory_graph.py" >/dev/null
grep -qF "SENTINEL" "$d5/docs/memory/README.md"; assert "add-only: existing manual preserved" $?

# case 6: missing source template -> exit 1
bash "$S" --manual-dest "$TMP/x/README.md" --graph-dest "$TMP/x/g.py" --manual-template "$TMP/nope.md" >/dev/null 2>&1
[ "$?" = 1 ]; assert "missing-src: exit 1" $?

# case 7: bad args -> exit 2
bash "$S" --manual-dest "$TMP/y/README.md" >/dev/null 2>&1; [ "$?" = 2 ]; assert "badargs: exit 2" $?

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
