#!/usr/bin/env bash
# Plain-bash test harness for hooks/sidecar-memory-context.sh (deps: bash + git).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/sidecar-memory-context.sh"
pass=0; fail=0

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WS="$TMP/ws"
mkdir -p "$WS/_meta/memory" "$WS/_meta/repo-a/memory"
printf '{ "workspace-os": "sidecar", "workspace": "hooktest" }\n' > "$WS/_meta/workspace.json"
printf '# Memory Index\n- shared fact WS-TIER-CANARY\n' > "$WS/_meta/memory/MEMORY.md"
printf '# Memory Index\n- repo fact REPO-TIER-CANARY\n' > "$WS/_meta/repo-a/memory/MEMORY.md"
git -C "$WS" init -q --initial-branch=main "$WS/repo-a" 2>/dev/null || git -C "$WS/repo-a" init -q
mkdir -p "$WS/repo-b" && git -C "$WS/repo-b" init -q   # sidecar repo with NO memory yet

mk_plain() { mkdir -p "$1" && git -C "$1" init -q; }
mk_plain "$TMP/plain"

check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec out=[$got_out])"; fail=$((fail+1)); fi
}

out="$(cd "$WS/repo-a" && bash "$HOOK" 2>&1)"; ec=$?
check "sidecar: emits workspace tier" "$ec" "0" "$out" "WS-TIER-CANARY"
check "sidecar: emits repo tier" "$ec" "0" "$out" "REPO-TIER-CANARY"
case "$out" in *WS-TIER-CANARY*REPO-TIER-CANARY*) echo "PASS: workspace tier first"; pass=$((pass+1));;
  *) echo "FAIL: tier order wrong"; fail=$((fail+1));; esac

out="$(cd "$WS/repo-b" && bash "$HOOK" 2>&1)"; ec=$?
check "sidecar repo w/o memory: workspace tier only" "$ec" "0" "$out" "WS-TIER-CANARY"
case "$out" in *REPO-TIER-CANARY*) echo "FAIL: repo-b leaked repo-a memory"; fail=$((fail+1));;
  *) echo "PASS: no cross-repo leak"; pass=$((pass+1));; esac

out="$(cd "$TMP/plain" && bash "$HOOK" 2>&1)"; ec=$?
check "in-repo mode: silent" "$ec" "0" "$out" ""
[ -z "$out" ] && { echo "PASS: in-repo emits nothing"; pass=$((pass+1)); } \
  || { echo "FAIL: in-repo emitted output"; fail=$((fail+1)); }

out="$(cd "$TMP" && bash "$HOOK" 2>&1)"; ec=$?
check "non-repo dir: silent, exit 0" "$ec" "0" "$out" ""

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
