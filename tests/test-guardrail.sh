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

# --- Task: sidecar mode (config fallback + repo-tree backstop) ---
# Runtime fixture: a marked workspace (committed fixtures can't hold nested .git dirs).
SWTMP="$(mktemp -d)"; trap 'rm -rf "$SWTMP"' EXIT
mkdir -p "$SWTMP/ws/_meta/repo-a" "$SWTMP/ws/repo-a"
printf '{ "workspace-os": "sidecar", "workspace": "gw" }\n' > "$SWTMP/ws/_meta/workspace.json"
git -C "$SWTMP/ws/repo-a" init -q
cat > "$SWTMP/ws/_meta/repo-a/guardrails.json" <<'JSON'
{ "bash": [ { "name": "no-prod", "match": "deploy --prod", "action": "deny", "reason": "sidecar-rule: no prod deploys" } ] }
JSON

# run_hook_in <dir> <json> -> prints "<exit_code>\t<combined output>"  (GUARDRAIL_CONFIG unset)
run_hook_in() {
  local dir="$1" json="$2" out ec
  out="$(cd "$dir" && bash "$HOOK" <<<"$json" 2>&1)"; ec=$?
  printf '%s\t%s' "$ec" "$out"
}

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Bash","tool_input":{"command":"deploy --prod now"}}')
check "sidecar guardrails.json fallback denies" "$ec" "2" "$err" "sidecar-rule"

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"docs/project-tracking/action-items.md","content":"x"}}')
check "sidecar write into repo tracking warns" "$ec" "0" "$err" "sidecar mode"

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"src/app.py","content":"print(1)"}}')
check "sidecar write to normal code passes" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"'"$SWTMP"'/ws/_meta/repo-a/memory/fact.md","content":"x"}}')
check "sidecar write into _meta passes" "$ec" "0" "$err" ""

# Windows file_path is backslashed — the repo-tree backstop must still fire (regression: forward-slash-only grep)
IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"docs\\project-tracking\\action-items.md","content":"x"}}')
check "sidecar backslash path warns (Windows)" "$ec" "0" "$err" "sidecar mode"

# --- Task: stateful predicates (spec: docs/specs/2026-09-04-stateful-guardrail-predicates-design.md) ---
# A rule fires when its regex matches AND its `predicate` exits 0; anything else skips it (fail open).
# hook_all <json> <cfg> -> full combined output, newlines joined (run_hook's `read` sees line 1 only)
hook_all() { GUARDRAIL_CONFIG="$2" bash "$HOOK" <<<"$1" 2>&1 | tr '\n' '|'; }
PCFG="$SWTMP/predicates.json"
cat > "$PCFG" <<'JSON'
{ "bash": [
    { "name": "pred-true",  "match": "gen\\.py", "predicate": "true",  "action": "deny", "reason": "pred-true fired" },
    { "name": "pred-false", "match": "gen\\.py", "predicate": "false", "action": "deny", "reason": "pred-false fired" },
    { "name": "pred-slow",  "match": "slow\\.py", "predicate": "sleep 10", "action": "deny", "reason": "pred-slow fired" },
    { "name": "pred-error", "match": "err\\.py", "predicate": "this-command-does-not-exist-xyz", "action": "deny", "reason": "pred-error fired" },
    { "name": "plain",      "match": "plain\\.py", "action": "warn", "reason": "plain rule fired" },
    { "name": "on-main",    "match": ".*", "predicate": "[ \"$(git branch --show-current)\" = main ]", "action": "warn", "reason": "on-main fired" }
  ],
  "write": [
    { "name": "w-pred-true",  "match": "\\.md$", "field": "path", "predicate": "true",  "action": "warn", "reason": "w-pred-true fired" },
    { "name": "w-pred-false", "match": "\\.md$", "field": "path", "predicate": "false", "action": "deny", "reason": "w-pred-false fired" }
  ] }
JSON

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"python gen.py"}}' "$PCFG")
check "predicate true fires (deny)" "$ec" "2" "$err" "pred-true fired"
all="$(hook_all '{"tool_name":"Bash","tool_input":{"command":"python gen.py"}}' "$PCFG")"
case "$all" in *"pred-false fired"*) echo "FAIL: predicate false must not fire (out=[$all])"; fail=$((fail+1));; *) echo "PASS: predicate false does not fire"; pass=$((pass+1));; esac

start=$(date +%s)
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"python slow.py"}}' "$PCFG")
elapsed=$(( $(date +%s) - start ))
check "predicate timeout fails open" "$ec" "0" "$err" ""
[ "$elapsed" -lt 9 ] && { echo "PASS: predicate timeout bounded (${elapsed}s)"; pass=$((pass+1)); } \
  || { echo "FAIL: predicate ran past its budget (${elapsed}s)"; fail=$((fail+1)); }

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"python err.py"}}' "$PCFG")
check "predicate command-not-found fails open" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"python plain.py"}}' "$PCFG")
check "no-predicate rule unaffected" "$ec" "0" "$err" "plain rule fired"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"notes.md","content":"x"}}' "$PCFG")
check "write predicate true fires (warn)" "$ec" "0" "$err" "w-pred-true fired"
all="$(hook_all '{"tool_name":"Write","tool_input":{"file_path":"notes.md","content":"x"}}' "$PCFG")"
case "$all" in *"w-pred-false fired"*) echo "FAIL: write predicate false must not fire (out=[$all])"; fail=$((fail+1));; *) echo "PASS: write predicate false does not fire"; pass=$((pass+1));; esac

# Predicates run in the call's cwd (stdin `cwd`), not the hook's: a branch check against a temp repo.
BR="$SWTMP/branchrepo"; mkdir -p "$BR"; git -C "$BR" init -q -b main
git -C "$BR" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","cwd":"'"$BR"'","tool_input":{"command":"ls"}}' "$PCFG")
check "predicate sees cwd from stdin: on main fires" "$ec" "0" "$err" "on-main fired"
git -C "$BR" checkout -q -b feature
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","cwd":"'"$BR"'","tool_input":{"command":"ls"}}' "$PCFG")
all="$(hook_all '{"tool_name":"Bash","cwd":"'"$BR"'","tool_input":{"command":"ls"}}' "$PCFG")"
case "$all" in *"on-main fired"*) echo "FAIL: on feature branch must not fire (out=[$all])"; fail=$((fail+1));; *) echo "PASS: predicate sees cwd from stdin: on feature branch passes"; pass=$((pass+1));; esac

# --- Task: probe-first dispatch gate (spec: docs/specs/2026-09-04-probe-first-dispatch-gate-design.md) ---
# `dispatch` rules: first matching Task|Agent call per session per rule runs the probe and denies once
# with the output on stderr (marker written first); the retry passes. TMPDIR is the marker seam.
DTMP="$SWTMP/dtmp"; mkdir -p "$DTMP"
DCFG="$SWTMP/dispatch.json"
big="$SWTMP/big.txt"; head -c 6000 /dev/zero | tr '\0' 'x' > "$big"
cat > "$DCFG" <<JSON
{ "bash": [ { "name": "plain-bash", "match": "gen\\\\.py", "action": "warn", "reason": "plain-bash fired" } ],
  "dispatch": [
    { "name": "output-exists", "match": "(derive|rebuild).*csv", "probe": "echo PROBE_OUTPUT_ALPHA; echo err-line >&2", "reason": "check the pipeline output first" },
    { "name": "second-rule",   "match": "rebuild", "probe": "echo PROBE_OUTPUT_BETA", "reason": "second reason" },
    { "name": "broken-probe",  "match": "broken-question", "probe": "exit 7", "reason": "broken reason" },
    { "name": "slow-probe",    "match": "slow-question", "probe": "sleep 30", "reason": "slow reason" },
    { "name": "big-probe",     "match": "big-question", "probe": "cat $big", "reason": "big reason" }
  ] }
JSON
# run_task <session> <description> <prompt> -> $tout (combined), $tec
run_task() {
  local json; json="$(jq -cn --arg s "$1" --arg d "$2" --arg p "$3" \
    '{hook_event_name:"PreToolUse", session_id:$s, tool_name:"Task", tool_input:{description:$d, prompt:$p, subagent_type:"Explore"}}')"
  tout="$(TMPDIR="$DTMP" GUARDRAIL_CONFIG="$DCFG" bash "$HOOK" <<<"$json" 2>&1)"; tec=$?
}
tcheck() {  # tcheck <name> <want_ec> <want_substr>
  local ok=1; [ "$tec" = "$2" ] || ok=0
  if [ -n "$3" ]; then case "$tout" in *"$3"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (exit=$tec want=$2 out=[$tout])"; fail=$((fail+1)); fi
}
tabsent() {  # tabsent <name> <must-not-substr>
  case "$tout" in *"$2"*) echo "FAIL: $1 (out=[$tout])"; fail=$((fail+1));; *) echo "PASS: $1"; pass=$((pass+1));; esac
}

run_task s1 "derive the features csv" "please derive features.csv from raw"
tcheck "dispatch: matching call denies" 2 "probe-first: 'output-exists'"
tcheck "dispatch: reason surfaced" 2 "check the pipeline output first"
tcheck "dispatch: probe stdout surfaced" 2 "PROBE_OUTPUT_ALPHA"
tcheck "dispatch: probe stderr surfaced" 2 "err-line"
tcheck "dispatch: closing instruction" 2 "Re-dispatch only if"
tabsent "dispatch: non-matching rule silent" "PROBE_OUTPUT_BETA"
run_task s1 "derive the features csv" "please derive features.csv from raw"
tcheck "dispatch: same session retry passes silently" 0 ""
[ -z "$tout" ] && { echo "PASS: dispatch: retry prints nothing"; pass=$((pass+1)); } || { echo "FAIL: dispatch: retry printed [$tout]"; fail=$((fail+1)); }
run_task s2 "derive the features csv" "please derive features.csv from raw"
tcheck "dispatch: new session denies again" 2 "PROBE_OUTPUT_ALPHA"
run_task s3 "summarize the README" "read README.md and summarize"
tcheck "dispatch: non-matching dispatch passes" 0 ""
run_task s4 "rebuild" "rebuild the csv"
tcheck "dispatch: two matching rules, first surfaced" 2 "PROBE_OUTPUT_ALPHA"
tcheck "dispatch: two matching rules, second surfaced" 2 "PROBE_OUTPUT_BETA"
run_task s5 "broken-question" "x"
tcheck "dispatch: failing probe still denies once" 2 "probe exited 7"
run_task s5 "broken-question" "x"
tcheck "dispatch: failing probe retry passes" 0 ""
start=$(date +%s); run_task s6 "slow-question" "x"; elapsed=$(( $(date +%s) - start ))
tcheck "dispatch: slow probe denies with timeout noted" 2 "probe exited 124"
[ "$elapsed" -lt 20 ] && { echo "PASS: dispatch: probe cut off inside budget (${elapsed}s)"; pass=$((pass+1)); } \
  || { echo "FAIL: dispatch: probe ran ${elapsed}s"; fail=$((fail+1)); }
run_task s7 "big-question" "x"
tcheck "dispatch: oversized output truncated" 2 "[probe output truncated"
[ "${#tout}" -lt 5000 ] && { echo "PASS: dispatch: output capped (${#tout} chars)"; pass=$((pass+1)); } \
  || { echo "FAIL: dispatch: output not capped (${#tout} chars)"; fail=$((fail+1)); }
# prompt-only match (description does not match) + Agent tool name
json='{"hook_event_name":"PreToolUse","session_id":"s8","tool_name":"Agent","tool_input":{"description":"help","prompt":"rebuild the csv please"}}'
tout="$(TMPDIR="$DTMP" GUARDRAIL_CONFIG="$DCFG" bash "$HOOK" <<<"$json" 2>&1)"; tec=$?
tcheck "dispatch: Agent tool + prompt-only match denies" 2 "PROBE_OUTPUT_ALPHA"
# a Bash call ignores dispatch rules and still gets its own rules
json='{"hook_event_name":"PreToolUse","session_id":"s9","tool_name":"Bash","tool_input":{"command":"python gen.py rebuild csv"}}'
tout="$(TMPDIR="$DTMP" GUARDRAIL_CONFIG="$DCFG" bash "$HOOK" <<<"$json" 2>&1)"; tec=$?
tcheck "dispatch: Bash call untouched by dispatch rules" 0 "plain-bash fired"
tabsent "dispatch: Bash call does not run probes" "PROBE_OUTPUT"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
