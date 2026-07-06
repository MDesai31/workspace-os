#!/usr/bin/env bash
# Plain-bash test harness for hooks/guardrail.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/guardrail.sh"
FIX="$HERE/fixtures"
pass=0; fail=0

# run_hook <json> [config_path] -> prints "<exit_code>\t<combined stdout+stderr>"
# (warn -> systemMessage JSON on stdout; deny -> reason on stderr, exit 2)
run_hook() {
  local json="$1" cfg="${2:-}" out ec
  out="$(GUARDRAIL_CONFIG="$cfg" bash "$HOOK" <<<"$json" 2>&1)"; ec=$?
  printf '%s\t%s' "$ec" "$out"
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

# --- Task 2: generic secret-content warn ---
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"c.py","content":"api_key = \"foo\""}}')
check "api_key warns not denies" "$ec" "0" "$err" "possible secret"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"c.py","new_string":"PASSWORD=hunter2"}}')
check "password in new_string warns" "$ec" "0" "$err" "possible secret"

# --- Task 3: bash built-in defaults ---
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}')
check "force-push to main warns" "$ec" "0" "$err" "force-push"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}')
check "rm -rf root warns" "$ec" "0" "$err" "rm"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"git push origin feature"}}')
check "normal push passes" "$ec" "0" "$err" ""

# --- Task 4: per-repo rules + fail-open ---
CFG="$FIX/guardrails.json"
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"python -c \"import duckdb; duckdb.connect(1)\""}}' "$CFG")
check "per-repo bash deny" "$ec" "2" "$err" "mcp__duckdb__query"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"x.py","content":"see AcmeCorpInternal notes"}}' "$CFG")
check "per-repo write content warn" "$ec" "0" "$err" "tripwire"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"config/.env","content":"X=1"}}' "$CFG")
check "per-repo write path deny" "$ec" "2" "$err" "forbids writing .env"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}' "$CFG")
check "per-repo no-match passes" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"duckdb.connect("}}' "$FIX/malformed.json")
check "malformed config fails open" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"duckdb.connect("}}' "$FIX/nonexistent.json")
check "missing config fails open" "$ec" "0" "$err" ""

# --- warn channel: warns must be systemMessage JSON on stdout, not a bare stderr line ---
warn_out="$(echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}' | bash "$HOOK" 2>/dev/null)"
if printf '%s' "$warn_out" | jq -e '.systemMessage | test("force-push")' >/dev/null 2>&1; then
  echo "PASS: warn emits systemMessage JSON on stdout"; pass=$((pass+1))
else
  echo "FAIL: warn systemMessage channel (stdout=[$warn_out])"; fail=$((fail+1))
fi

# deny must NOT print JSON to stdout (reason goes to stderr, exit 2)
deny_out="$(echo '{"tool_name":"Write","tool_input":{"file_path":"a","content":"AKIA1234567890ABCDEF"}}' | bash "$HOOK" 2>/dev/null)"
if [ -z "$deny_out" ]; then
  echo "PASS: deny writes nothing to stdout"; pass=$((pass+1))
else
  echo "FAIL: deny leaked to stdout (stdout=[$deny_out])"; fail=$((fail+1))
fi

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
