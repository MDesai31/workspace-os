#!/usr/bin/env bash
# Plain-bash test harness for scripts/memory_graph.py (deps: bash + python3 only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/memory_graph.py"
CLEAN="$HERE/fixtures/memory-clean"
BROKEN="$HERE/fixtures/memory-broken"
pass=0; fail=0

# run_check <fixture_root> -> sets globals ec (exit code) and out (combined output)
run_check() {
  local fx="$1"
  out="$(python3 "$SCRIPT" --check --root "$fx/docs/memory" \
        --tracking-root "$fx/docs/project-tracking" 2>&1)"; ec=$?
}

# check <name> <got_ec> <want_ec> <got_out> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec out=[$got_out])"; fail=$((fail+1)); fi
}

# --- clean tree: resolves wikilinks (incl. typed + D- record), index in parity ---
run_check "$CLEAN"
check "clean tree passes --check" "$ec" "0" "$out" "clean"

# --- broken tree: broken link + unindexed file + dangling entry all fail + are named ---
run_check "$BROKEN"
check "broken tree fails --check" "$ec" "1" "$out" ""
check "broken wikilink is named" "$ec" "1" "$out" "missing_note"
check "unindexed file is named" "$ec" "1" "$out" "unindexed_fact"
check "dangling index entry is named" "$ec" "1" "$out" "gone"

# --- report mode: typed edge counted; code-fence/inline links NOT counted ---
report="$(python3 "$SCRIPT" --root "$CLEAN/docs/memory" --tracking-root "$CLEAN/docs/project-tracking" 2>&1)"
case "$report" in *"supersedes: 1"*) echo "PASS: typed edge reported"; pass=$((pass+1));;
  *) echo "FAIL: typed edge missing from report"; fail=$((fail+1));; esac
case "$report" in *"not_a_real_link"*|*"also_not_a_link"*)
  echo "FAIL: code-span/fence link counted as an edge"; fail=$((fail+1));;
  *) echo "PASS: code-span/fence links ignored"; pass=$((pass+1));; esac
case "$report" in *"BROKEN LINKS (0)"*) echo "PASS: clean report has zero broken"; pass=$((pass+1));;
  *) echo "FAIL: clean report shows broken links"; fail=$((fail+1));; esac

# --- missing tracking root fails open (D- link becomes broken, but no crash) ---
out="$(python3 "$SCRIPT" --check --root "$CLEAN/docs/memory" --tracking-root "$CLEAN/nonexistent" 2>&1)"; ec=$?
check "missing tracking root = no crash, D- link now broken" "$ec" "1" "$out" "d_20260101_fixture_decision"

# --- two-tier (sidecar): --link-root resolves cross-tier wikilinks ---
TWO="$HERE/fixtures/memory-two-tier"
out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" 2>&1)"; ec=$?
check "cross-tier link WITHOUT --link-root is broken" "$ec" "1" "$out" "shared_data_contract"

out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" \
      --link-root "$TWO/workspace/memory" 2>&1)"; ec=$?
check "cross-tier link WITH --link-root resolves" "$ec" "0" "$out" "clean"

out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" \
      --link-root "$TWO/nonexistent" 2>&1)"; ec=$?
check "missing --link-root dir fails open (link broken, no crash)" "$ec" "1" "$out" "shared_data_contract"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
