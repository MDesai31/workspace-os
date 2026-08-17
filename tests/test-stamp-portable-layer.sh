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

# case 8: --refresh replaces a stale vendored validator with the shipped one
d8="$TMP/repo8"; mkdir -p "$d8/docs/memory"; printf 'STALE_VALIDATOR\n' > "$TMP/fake_graph.py"
bash "$S" --manual-dest "$d8/docs/memory/README.md" --graph-dest "$d8/docs/tools/memory_graph.py" \
  --graph-src "$TMP/fake_graph.py" >/dev/null
grep -qF "STALE_VALIDATOR" "$d8/docs/tools/memory_graph.py"; assert "refresh-setup: stale validator stamped" $?
out="$(bash "$S" --manual-dest "$d8/docs/memory/README.md" --graph-dest "$d8/docs/tools/memory_graph.py" --refresh)"
! grep -qF "STALE_VALIDATOR" "$d8/docs/tools/memory_graph.py"; assert "refresh: stale validator replaced" $?
cmp -s "$GSRC" "$d8/docs/tools/memory_graph.py"; assert "refresh: validator matches shipped" $?
echo "$out" | grep -qF "graph: refreshed"; assert "refresh: graph reports refreshed" $?

# case 9: --refresh overwrites a modified manual (plugin-owned prose)
d9="$TMP/repo9"; mkdir -p "$d9/docs/memory"; printf 'HAND_EDITED\n' > "$d9/docs/memory/README.md"
out="$(bash "$S" --manual-dest "$d9/docs/memory/README.md" --graph-dest "$d9/docs/tools/memory_graph.py" --refresh)"
! grep -qF "HAND_EDITED" "$d9/docs/memory/README.md"; assert "refresh: modified manual overwritten" $?
echo "$out" | grep -qF "manual: refreshed"; assert "refresh: manual reports refreshed" $?

# case 10: --refresh never touches AGENTS.md (user-owned stale-priors content)
d10="$TMP/repo10"; mkdir -p "$d10/docs/memory"; printf 'MY_STALE_PRIORS\n' > "$d10/AGENTS.md"
out="$(bash "$S" --manual-dest "$d10/docs/memory/README.md" --graph-dest "$d10/docs/tools/memory_graph.py" \
  --agents "$d10/AGENTS.md" --refresh)"
grep -qF "MY_STALE_PRIORS" "$d10/AGENTS.md"; assert "refresh: AGENTS.md content preserved" $?
echo "$out" | grep -qF "agents: skipped"; assert "refresh: agents reports skipped" $?

# case 11: facts and the index are md5-unchanged across a refresh
d11="$TMP/repo11"; mkdir -p "$d11/docs/memory"
printf -- '---\nname: a-fact\n---\n\nbody text\n' > "$d11/docs/memory/a-fact.md"
printf '# Memory Index\n\n- [A fact](a-fact.md) - hook\n' > "$d11/docs/memory/MEMORY.md"
before="$(md5sum "$d11/docs/memory/a-fact.md" "$d11/docs/memory/MEMORY.md")"
bash "$S" --manual-dest "$d11/docs/memory/README.md" --graph-dest "$d11/docs/tools/memory_graph.py" --refresh >/dev/null
[ "$before" = "$(md5sum "$d11/docs/memory/a-fact.md" "$d11/docs/memory/MEMORY.md")" ]
assert "refresh: facts and index md5-unchanged" $?

# case 12: --refresh on a fresh base reports created, not refreshed
d12="$TMP/repo12"; mkdir -p "$d12/docs/memory"
out="$(bash "$S" --manual-dest "$d12/docs/memory/README.md" --graph-dest "$d12/docs/tools/memory_graph.py" --refresh)"
echo "$out" | grep -qF "manual: created"; assert "refresh-fresh: manual reports created" $?
echo "$out" | grep -qF "graph: created"; assert "refresh-fresh: graph reports created" $?

# case 13: --refresh when already identical reports current and leaves content in place
out="$(bash "$S" --manual-dest "$d12/docs/memory/README.md" --graph-dest "$d12/docs/tools/memory_graph.py" --refresh)"
echo "$out" | grep -qF "manual: current"; assert "refresh-identical: manual reports current" $?
echo "$out" | grep -qF "graph: current"; assert "refresh-identical: graph reports current" $?
cmp -s "$GSRC" "$d12/docs/tools/memory_graph.py"; assert "refresh-identical: validator still matches shipped" $?

# case 14: without --refresh an existing plugin-owned file is still left alone (add-only default)
d14="$TMP/repo14"; mkdir -p "$d14/docs/memory"; printf 'STALE_VALIDATOR\n' > "$TMP/fake_graph2.py"
bash "$S" --manual-dest "$d14/docs/memory/README.md" --graph-dest "$d14/docs/tools/memory_graph.py" \
  --graph-src "$TMP/fake_graph2.py" >/dev/null
out="$(bash "$S" --manual-dest "$d14/docs/memory/README.md" --graph-dest "$d14/docs/tools/memory_graph.py")"
grep -qF "STALE_VALIDATOR" "$d14/docs/tools/memory_graph.py"; assert "no-refresh: stale validator left alone" $?
echo "$out" | grep -qF "graph: exists"; assert "no-refresh: graph reports exists" $?

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
