#!/usr/bin/env bash
# Plain-bash test harness for scripts/guardrails-upsert.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSERT="$HERE/../scripts/guardrails-upsert.sh"
pass=0; fail=0

# run <args...> -> sets $out (stdout+stderr) and $ec, with GUARDRAIL_CONFIG="$CFG"
run() { out="$(GUARDRAIL_CONFIG="$CFG" bash "$UPSERT" "$@" 2>&1)"; ec=$?; }

# expect <name> <want_ec> <want_substr>
expect() {
  local name="$1" want_ec="$2" want="$3" ok=1
  [ "$ec" = "$want_ec" ] || ok=0
  case "$out" in *"$want"*) ;; *) ok=0 ;; esac
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (ec=$ec out=[$out])"; fail=$((fail+1)); fi
}

# jqcheck <name> <jq -e filter over $CFG>
jqcheck() {
  if jq -e "$2" "$CFG" >/dev/null 2>&1; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1 (config=[$(cat "$CFG" 2>/dev/null)])"; fail=$((fail+1)); fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- add: creates config from template (nested dir) ---
CFG="$TMP/a/.claude/guardrails.json"
run add --type bash --name no-enterprise-push --match 'git +push +enterprise' \
    --action deny --reason "never push to the enterprise remote"
expect "add creates config from template" 0 "added bash rule 'no-enterprise-push' (deny)"
jqcheck "seeded config keeps template ip_class" '.ip_class'
jqcheck "rule landed with all fields" \
  '.bash | length == 1 and .[0].name == "no-enterprise-push" and .[0].action == "deny" and .[0].match == "git +push +enterprise" and (.[0].reason | length > 0)'

# --- add: idempotent replace by name ---
run add --type bash --name no-enterprise-push --match 'git +push +enterprise' \
    --action warn --reason "downgraded to advisory"
expect "replace same name exits 0" 0 "added bash rule"
jqcheck "replace does not duplicate" '.bash | length == 1'
jqcheck "replace updates fields" '.bash[0].action == "warn" and .bash[0].reason == "downgraded to advisory"'

# --- add: second rule appends ---
run add --type bash --name no-sudo --match '^sudo ' --action warn --reason "no sudo here"
expect "second rule appends" 0 "added bash rule 'no-sudo'"
jqcheck "both rules present" '.bash | length == 2'

# --- add: write rule with --field path ---
run add --type write --name no-env-writes --match '\.env$' --field path \
    --action deny --reason "never write .env files"
expect "write rule with field=path" 0 "added write rule"
jqcheck "field recorded" '.write[0].field == "path"'

# --- add: validation failures leave config untouched ---
before="$(cat "$CFG")"
run add --type bash --name x --match 'ok' --field path --action warn --reason r
expect "--field with --type bash rejected" 1 "--field is only valid with --type write"
run add --type nope --name x --match 'ok' --action warn --reason r
expect "bad type rejected" 1 "--type must be bash|write"
run add --type bash --name x --match 'ok' --action block --reason r
expect "bad action rejected" 1 "--action must be deny|warn"
run add --type bash --name x --match '(' --action warn --reason r
expect "invalid regex rejected (jq dialect)" 1 "invalid regex"
run add --type bash --match 'ok' --action warn --reason r
expect "missing --name rejected" 1 "--name is required"
[ "$(cat "$CFG")" = "$before" ] && { echo "PASS: failed adds leave config untouched"; pass=$((pass+1)); } \
  || { echo "FAIL: config changed by failing adds"; fail=$((fail+1)); }

# --- add: refuses to touch a malformed existing config ---
CFG="$TMP/broken.json"; printf '{oops' > "$CFG"
run add --type bash --name x --match 'ok' --action warn --reason r
expect "malformed existing config refused" 1 "does not parse"
[ "$(cat "$CFG")" = '{oops' ] && { echo "PASS: malformed config not clobbered"; pass=$((pass+1)); } \
  || { echo "FAIL: malformed config was modified"; fail=$((fail+1)); }

# --- add: no temp debris after success or failure ---
if ls "$TMP"/a/.claude/guardrails.json.tmp.* >/dev/null 2>&1 || ls "$TMP"/broken.json.tmp.* >/dev/null 2>&1; then
  echo "FAIL: temp debris left behind"; fail=$((fail+1))
else echo "PASS: no temp debris"; pass=$((pass+1)); fi

# --- remove / list ---
CFG="$TMP/rl/guardrails.json"
run add --type bash --name rule-a --match 'aaa' --action deny --reason "A"
run add --type write --name rule-b --match 'bbb' --action warn --reason "B"

run list
expect "list shows config header" 0 "config: $CFG"
expect "list shows a bash row" 0 "rule-a"
case "$out" in *"rule-b"*) echo "PASS: list shows write row"; pass=$((pass+1));; \
  *) echo "FAIL: list missing write row (out=[$out])"; fail=$((fail+1));; esac

run remove --type bash --name rule-a
expect "remove deletes the rule" 0 "removed bash rule 'rule-a'"
jqcheck "removed from bash array" '.bash | length == 0'
jqcheck "write array untouched by remove" '.write | length == 1'

run remove --type bash --name rule-a
expect "remove missing rule errors" 1 "no bash rule named 'rule-a'"

CFG="$TMP/rl/none.json"
run remove --type bash --name x
expect "remove with no config errors" 1 "no config at"
run list
expect "list with no config is a note, exit 0" 0 "no guardrails config"

CFG="$TMP/rl/bad.json"; printf 'not json' > "$CFG"
run list
expect "list on malformed config errors" 1 "does not parse"

# --- data-root routing (no GUARDRAIL_CONFIG) ---
HOOK="$HERE/../hooks/guardrail.sh"

# in-repo mode -> <git root>/.claude/guardrails.json
R="$TMP/plain-repo"; mkdir -p "$R"; git -C "$R" init -q
out="$(cd "$R" && bash "$UPSERT" add --type bash --name t --match 'zzz' --action warn --reason r 2>&1)"; ec=$?
expect "in-repo add resolves to .claude/" 0 "/.claude/guardrails.json"
[ -f "$R/.claude/guardrails.json" ] && { echo "PASS: in-repo file created"; pass=$((pass+1)); } \
  || { echo "FAIL: in-repo file missing"; fail=$((fail+1)); }

# sidecar mode -> <ws>/_meta/<repo>/guardrails.json, repo tree untouched
WS="$TMP/ws"; mkdir -p "$WS/_meta" "$WS/repo-a"
printf '{"workspace-os":"sidecar","workspace":"test"}\n' > "$WS/_meta/workspace.json"
git -C "$WS/repo-a" init -q
out="$(cd "$WS/repo-a" && bash "$UPSERT" add --type bash --name no-enterprise-push \
      --match 'git +push +enterprise' --action deny --reason "never push enterprise" 2>&1)"; ec=$?
expect "sidecar add reports sidecar mode" 0 "[mode: sidecar]"
[ -f "$WS/_meta/repo-a/guardrails.json" ] && { echo "PASS: sidecar file at _meta/repo-a/"; pass=$((pass+1)); } \
  || { echo "FAIL: sidecar file missing (out=[$out])"; fail=$((fail+1)); }
[ ! -e "$WS/repo-a/.claude/guardrails.json" ] && { echo "PASS: repo tree untouched in sidecar mode"; pass=$((pass+1)); } \
  || { echo "FAIL: sidecar add wrote into the repo tree"; fail=$((fail+1)); }

# engine round-trip: the real hook denies based on the rule we just wrote
json='{"tool_name":"Bash","tool_input":{"command":"git  push enterprise main"}}'
hout="$(cd "$WS/repo-a" && printf '%s' "$json" | GUARDRAIL_CONFIG="" bash "$HOOK" 2>&1)"; hec=$?
[ "$hec" = 2 ] && { echo "PASS: engine round-trip denies"; pass=$((pass+1)); } \
  || { echo "FAIL: engine round-trip (ec=$hec out=[$hout])"; fail=$((fail+1)); }
case "$hout" in *"never push enterprise"*) echo "PASS: engine surfaces our reason"; pass=$((pass+1));; \
  *) echo "FAIL: reason not surfaced (out=[$hout])"; fail=$((fail+1));; esac

# sidecar list resolves the same path
out="$(cd "$WS/repo-a" && bash "$UPSERT" list 2>&1)"; ec=$?
expect "sidecar list finds the config" 0 "_meta/repo-a/guardrails.json"

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
