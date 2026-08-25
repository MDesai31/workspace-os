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

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
