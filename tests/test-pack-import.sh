#!/usr/bin/env bash
# Plain-bash test harness for scripts/pack-import.sh (deps: bash + jq).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/pack-import.sh"
ENGINE="$HERE/../hooks/guardrail.sh"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }
check() { if [ "$2" = 0 ]; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
GCFG="$TMP/.claude/guardrails.json"
export GUARDRAIL_CONFIG="$GCFG"
PACKS="$TMP/packs"; mkdir -p "$PACKS"

# Fixture pack: bash + write rules, ip_class — already substituted (no {{}}).
cat > "$PACKS/testpack.json" <<'EOF'
{ "name": "testpack", "description": "fixture",
  "ip_class": "enterprise",
  "guardrails": {
    "bash":  [ { "name": "tp-bash", "match": "forbidden\\.example", "action": "deny", "reason": "tp bash" } ],
    "write": [ { "name": "tp-write", "match": "TRIPWIRE", "field": "content", "action": "deny", "reason": "tp write" } ] } }
EOF

# 1) add: rules stamped, ledger written, ip_class set
out="$(bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" 2>&1)"; ec=$?
check "add exits 0" $([ "$ec" = 0 ] && echo 0 || echo 1)
check "bash rule stamped"   $([ "$(jq -r '.bash[]  | select(.name=="tp-bash").pack'  "$GCFG")" = "testpack" ] && echo 0 || echo 1)
check "write rule stamped"  $([ "$(jq -r '.write[] | select(.name=="tp-write").pack' "$GCFG")" = "testpack" ] && echo 0 || echo 1)
check "ledger has version"  $(jq -e '._packs.testpack.version' "$GCFG" >/dev/null && echo 0 || echo 1)
check "ledger has date"     $(jq -e '._packs.testpack.imported' "$GCFG" >/dev/null && echo 0 || echo 1)
check "ip_class set"        $([ "$(jq -r '.ip_class' "$GCFG")" = "enterprise" ] && echo 0 || echo 1)

# 2) idempotent re-add: counts stable
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" >/dev/null 2>&1
check "re-add no dup bash"  $([ "$(jq '.bash | length' "$GCFG")" = 1 ] && echo 0 || echo 1)

# 3) hand-authored rule survives add and remove
jq '.bash += [{"name":"hand-rule","match":"handmade","action":"warn","reason":"mine"}]' "$GCFG" > "$GCFG.t" && mv "$GCFG.t" "$GCFG"
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" >/dev/null 2>&1
check "hand rule survives add" $(jq -e '.bash[] | select(.name=="hand-rule")' "$GCFG" >/dev/null && echo 0 || echo 1)

# 4) engine tolerance: stamped deny rule fires (extra key inert)
printf '{"tool_name":"Bash","tool_input":{"command":"git push forbidden.example main"}}' \
  | GUARDRAIL_CONFIG="$GCFG" bash "$ENGINE" >/dev/null 2>&1; ec=$?
check "engine denies on stamped rule (exit 2)" $([ "$ec" = 2 ] && echo 0 || echo 1)

# 5) remove: pack rules + ledger gone, hand rule survives, ip_class note printed
out="$(bash "$SCRIPT" --packs-dir "$PACKS" remove testpack 2>&1)"; ec=$?
check "remove exits 0"          $([ "$ec" = 0 ] && echo 0 || echo 1)
check "pack bash rule gone"     $(jq -e '.bash[] | select(.name=="tp-bash")' "$GCFG" >/dev/null 2>&1 && echo 1 || echo 0)
check "ledger entry gone"       $(jq -e '._packs.testpack' "$GCFG" >/dev/null 2>&1 && echo 1 || echo 0)
check "hand rule survives remove" $(jq -e '.bash[] | select(.name=="hand-rule")' "$GCFG" >/dev/null && echo 0 || echo 1)
case "$out" in *ip_class*) ok "ip_class note printed";; *) bad "ip_class note printed (out=[$out])";; esac
check "ip_class untouched by remove" $([ "$(jq -r '.ip_class' "$GCFG")" = "enterprise" ] && echo 0 || echo 1)

# 6) unsubstituted placeholder -> die, config untouched
cat > "$PACKS/badsub.json" <<'EOF'
{ "name": "badsub", "description": "x",
  "guardrails": { "bash": [ { "name": "b", "match": "{{oops}}", "action": "deny", "reason": "r" } ] } }
EOF
before="$(cat "$GCFG")"
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/badsub.json" >/dev/null 2>&1; ec=$?
check "unsubstituted placeholder dies" $([ "$ec" != 0 ] && echo 0 || echo 1)
check "config untouched after die"     $([ "$(cat "$GCFG")" = "$before" ] && echo 0 || echo 1)

# 7) invalid regex -> die, config untouched
cat > "$PACKS/badre.json" <<'EOF'
{ "name": "badre", "description": "x",
  "guardrails": { "bash": [ { "name": "b", "match": "([unclosed", "action": "deny", "reason": "r" } ] } }
EOF
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/badre.json" >/dev/null 2>&1; ec=$?
check "invalid regex dies" $([ "$ec" != 0 ] && echo 0 || echo 1)
check "config untouched after regex die" $([ "$(cat "$GCFG")" = "$before" ] && echo 0 || echo 1)

# 7b) a pack carrying the retired lint key -> die, config untouched
cat > "$PACKS/lintpack.json" <<'EOF'
{ "name": "lintpack", "description": "x", "guardrails": { "bash": [] }, "lint": { "linters": [] } }
EOF
before="$(cat "$GCFG")"
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/lintpack.json" >/dev/null 2>&1; ec=$?
check "retired lint key dies" $([ "$ec" != 0 ] && echo 0 || echo 1)
check "config untouched after lint die" $([ "$(cat "$GCFG")" = "$before" ] && echo 0 || echo 1)

# 8) remove of a pack never imported -> die
bash "$SCRIPT" --packs-dir "$PACKS" remove neverimported >/dev/null 2>&1; ec=$?
check "remove unknown pack dies" $([ "$ec" != 0 ] && echo 0 || echo 1)

# 9) list shows available + imported
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" >/dev/null 2>&1
out="$(bash "$SCRIPT" --packs-dir "$PACKS" list 2>&1)"
case "$out" in *testpack*) ok "list names the pack";; *) bad "list names the pack (out=[$out])";; esac
case "$out" in *imported*) ok "list shows imported state";; *) bad "list shows imported state (out=[$out])";; esac

# 10) dispatch rules travel in packs: stamped, idempotent, removed with the pack
cat > "$PACKS/dpack.json" <<'EOF'
{ "name": "dpack", "description": "x",
  "guardrails": { "bash": [], "write": [],
    "dispatch": [ { "name": "pack-probe", "match": "rebuild.*csv", "probe": "ls data/out", "reason": "check first" } ] } }
EOF
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/dpack.json" >/dev/null 2>&1; ec=$?
check "dispatch pack imports" "$ec"
check "dispatch rule stamped" $(jq -e '.dispatch | map(select(.name=="pack-probe" and .pack=="dpack" and .probe=="ls data/out")) | length == 1' "$GCFG" >/dev/null 2>&1 && echo 0 || echo 1)
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/dpack.json" >/dev/null 2>&1
check "dispatch re-import idempotent" $([ "$(jq '.dispatch | map(select(.pack=="dpack")) | length' "$GCFG")" = 1 ] && echo 0 || echo 1)
bash "$SCRIPT" --packs-dir "$PACKS" remove dpack >/dev/null 2>&1
check "dispatch rules removed with pack" $([ "$(jq '.dispatch | map(select(.pack=="dpack")) | length' "$GCFG")" = 0 ] && echo 0 || echo 1)

echo "---"; echo "pass=$pass fail=$fail"; [ "$fail" = 0 ]
