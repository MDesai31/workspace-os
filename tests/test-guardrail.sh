#!/usr/bin/env bash
# Plain-bash test harness for hooks/guardrail.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/guardrail.sh"
FIX="$HERE/fixtures"
pass=0; fail=0

# run_hook <json> [config_path] -> prints "<exit_code>\t<stderr>"
run_hook() {
  local json="$1" cfg="${2:-}" err ec
  err="$(GUARDRAIL_CONFIG="$cfg" bash "$HOOK" <<<"$json" 2>&1 1>/dev/null)"; ec=$?
  printf '%s\t%s' "$ec" "$err"
}

# check <name> <got_ec> <want_ec> <got_err> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_err="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_err" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec stderr=[$got_err])"; fail=$((fail+1)); fi
}

# --- Task 1: high-confidence secret deny + benign pass ---
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"a.txt","content":"key AKIA1234567890ABCDEF here"}}')
check "AKIA secret denies" "$ec" "2" "$err" "secret"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"a.txt","content":"hello world"}}')
check "benign write passes" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}')
check "benign bash passes" "$ec" "0" "$err" ""

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
