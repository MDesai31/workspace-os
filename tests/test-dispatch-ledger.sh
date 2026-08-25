#!/usr/bin/env bash
# Plain-bash test harness for hooks/dispatch-ledger.sh + scripts/dispatch-ledger-summary.sh
# (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/dispatch-ledger.sh"
SUMMARY="$HERE/../scripts/dispatch-ledger-summary.sh"
pass=0; fail=0

ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1${2:+ ($2)}"; fail=$((fail+1)); }

# jqledger <name> <jq -e filter over the LAST ledger line>
jqledger() {
  if tail -n 1 "$LEDGER" 2>/dev/null | jq -e "$2" >/dev/null 2>&1; then ok "$1"
  else bad "$1" "last=[$(tail -n 1 "$LEDGER" 2>/dev/null)]"; fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LEDGER="$TMP/ledger.jsonl"

# a real git repo for the cwd -> repo derivation
REPO="$TMP/proj-x"; mkdir -p "$REPO"; git -C "$REPO" init -q

LONGDESC="$(printf 'd%.0s' $(seq 1 150))"   # 150 chars
payload="$(jq -cn --arg cwd "$REPO" --arg desc "$LONGDESC" '{
  session_id: "s1", cwd: $cwd, hook_event_name: "PostToolUse", tool_name: "Task",
  tool_input: {description: $desc, prompt: "SENTINEL_PROMPT_XYZZY", subagent_type: "Explore"},
  tool_response: {totalDurationMs: 1234, totalTokens: 999,
                  content: [{type: "text", text: "SENTINEL_RESPONSE_PLUGH"}]}
}')"

# --- capture: full payload ---
out="$(printf '%s' "$payload" | DISPATCH_LEDGER="$LEDGER" bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && ok "capture exits 0 silently" || bad "capture exits 0 silently" "ec=$ec out=[$out]"
[ "$(wc -l < "$LEDGER")" = 1 ] && ok "one line appended" || bad "one line appended"
jqledger "agent from subagent_type" '.agent == "Explore"'
jqledger "session + cwd recorded" '.session_id == "s1" and (.cwd | length > 0)'
jqledger "repo derived from cwd git root" '.repo == "proj-x"'
jqledger "desc truncated to 120" '(.desc | length) == 120'
jqledger "prompt_chars counted" '.prompt_chars == 21'
jqledger "response_chars counted (object stringified)" '.response_chars > 0'
jqledger "est_tokens = (p+r)/4 floored" '.est_tokens == (((.prompt_chars + .response_chars) / 4) | floor)'
jqledger "harness tokens picked up" '.tokens == 999'
jqledger "harness duration picked up" '.duration_ms == 1234'
jqledger "ts is ISO-8601 UTC" '.ts | test("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")'

# --- privacy: sentinel text never reaches the ledger ---
if grep -q "SENTINEL_PROMPT_XYZZY\|SENTINEL_RESPONSE_PLUGH" "$LEDGER"; then
  bad "privacy: no prompt/response text in ledger"
else ok "privacy: no prompt/response text in ledger"; fi

# --- capture: agentType fallback + string response + absent optionals ---
p2='{"session_id":"s2","cwd":"/nowhere","tool_name":"Agent",
     "tool_input":{"description":"d","prompt":"pp","agentType":"claude"},
     "tool_response":"just a string"}'
printf '%s' "$p2" | DISPATCH_LEDGER="$LEDGER" bash "$HOOK"
[ "$(wc -l < "$LEDGER")" = 2 ] && ok "second dispatch appends" || bad "second dispatch appends"
jqledger "agentType fallback" '.agent == "claude"'
jqledger "string response measured" '.response_chars == 13'
jqledger "absent optionals are null" '.tokens == null and .duration_ms == null and .is_error == null'
jqledger "non-repo cwd -> empty repo" '.repo == ""'

# --- fail-open paths ---
before="$(wc -l < "$LEDGER")"
out="$(printf 'not json' | DISPATCH_LEDGER="$LEDGER" bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && [ "$(wc -l < "$LEDGER")" = "$before" ] \
  && ok "malformed stdin: silent no-op" || bad "malformed stdin: silent no-op" "ec=$ec"
out="$(printf '{"tool_name":"Task"}' | DISPATCH_LEDGER="$LEDGER" bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ "$(wc -l < "$LEDGER")" = "$before" ] \
  && ok "missing tool_input: silent no-op" || bad "missing tool_input: silent no-op" "ec=$ec"
out="$(printf '%s' "$payload" | DISPATCH_LEDGER=/proc/nonexistent/dir/l.jsonl bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && ok "unwritable ledger: silent exit 0" || bad "unwritable ledger: silent exit 0" "ec=$ec"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
