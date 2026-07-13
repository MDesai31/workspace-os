#!/usr/bin/env bash
# Plain-bash test harness for hooks/lint.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/lint.sh"
LINTER="bash $HERE/fixtures/fake-linter.sh"   # invoke via bash: exec bit is unreliable on Windows
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# run_hook <json> [config_path] -> prints "<exit_code>\t<stdout>"
# lint emits additionalContext JSON on stdout and never blocks (always exit 0).
run_hook() {
  local json="$1" cfg="${2:-}" out ec
  out="$(LINT_CONFIG="$cfg" bash "$HOOK" <<<"$json" 2>/dev/null)"; ec=$?
  printf '%s\t%s' "$ec" "$out"
}

# check <name> <got_ec> <want_ec> <got_out> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec stdout=[$got_out])"; fail=$((fail+1)); fi
}
# check_empty <name> <got_ec> <got_out> : passes only if exit code is 0 AND stdout is empty (the silent, fail-open case)
check_empty() {
  local name="$1" got_ec="$2" got="$3"
  if [ "$got_ec" = "0" ] && [ -z "$got" ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (expected exit 0 + silent, got exit=$got_ec stdout=[$got])"; fail=$((fail+1)); fi
}

# A config that lints *.py with the stub linter.
jq -n --arg c "$LINTER" '{linters:[{name:"py",match:"\\.py$",command:$c}]}' > "$TMP/lint.json"

# 1. Dirty .py -> diagnostics injected
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' "$TMP/lint.json")
check "dirty file injects diagnostics" "$ec" "0" "$out" "E501"

# 2. Clean .py -> silent
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/clean.py"}}' "$TMP/lint.json")
check_empty "clean file is silent" "$ec" "$out"

# 3. Non-matching extension -> silent
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"/tmp/dirty.txt"}}' "$TMP/lint.json")
check_empty "no-match extension is silent" "$ec" "$out"

# 4. Missing config -> fail open silent
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' "$TMP/none.json")
check_empty "missing config fails open" "$ec" "$out"

# 5. Malformed config -> fail open silent
printf '{ "linters": [ this is not json\n' > "$TMP/bad.json"
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' "$TMP/bad.json")
check_empty "malformed config fails open" "$ec" "$out"

# 6. Linter not on PATH (exit 127) -> silent
jq -n '{linters:[{name:"nope",match:"\\.py$",command:"workspace-os-no-such-linter-xyz"}]}' > "$TMP/nolinter.json"
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' "$TMP/nolinter.json")
check_empty "missing linter fails open" "$ec" "$out"

# 7. Multiple matching linters concatenate
jq -n --arg c "$LINTER" '{linters:[{name:"one",match:"\\.py$",command:$c},{name:"two",match:"\\.py$",command:$c}]}' > "$TMP/multi.json"
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' "$TMP/multi.json")
check "multiple linters both run (one)" "$ec" "0" "$out" "[one]"
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' "$TMP/multi.json")
check "multiple linters both run (two)" "$ec" "0" "$out" "[two]"

# 8. additionalContext nests under hookSpecificOutput with the required hookEventName
struct_out="$(LINT_CONFIG="$TMP/lint.json" bash "$HOOK" <<<'{"tool_name":"Edit","tool_input":{"file_path":"/tmp/dirty.py"}}' 2>/dev/null)"
if printf '%s' "$struct_out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | test("E501"))' >/dev/null 2>&1; then
  echo "PASS: additionalContext under hookSpecificOutput"; pass=$((pass+1))
else
  echo "FAIL: hookSpecificOutput structure (stdout=[$struct_out])"; fail=$((fail+1))
fi

# 9. Windows backslash path is normalized before matching (rule has a slash)
jq -n --arg c "$LINTER" '{linters:[{name:"src-py",match:"src/.*\\.py$",command:$c}]}' > "$TMP/slash.json"
IFS=$'\t' read -r ec out < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"src\\dirty.py"}}' "$TMP/slash.json")
check "backslash path matches slash rule (Windows)" "$ec" "0" "$out" "E501"

# --- sidecar config fallback (no LINT_CONFIG; resolve via a marked workspace's _meta/) ---
# Runtime fixture: committed fixtures can't hold nested .git dirs.
SW="$(mktemp -d)"
mkdir -p "$SW/ws/_meta/repo-a" "$SW/ws/repo-a"
printf '{ "workspace-os": "sidecar", "workspace": "gw" }\n' > "$SW/ws/_meta/workspace.json"
git -C "$SW/ws/repo-a" init -q
jq -n --arg c "$LINTER" '{linters:[{name:"sc",match:"\\.py$",command:$c}]}' > "$SW/ws/_meta/repo-a/lint.json"

sc_out="$(cd "$SW/ws/repo-a" && bash "$HOOK" <<<'{"tool_name":"Edit","tool_input":{"file_path":"dirty.py"}}' 2>/dev/null)"
if printf '%s' "$sc_out" | jq -e '.hookSpecificOutput.additionalContext | test("E501")' >/dev/null 2>&1; then
  echo "PASS: sidecar lint.json fallback injects"; pass=$((pass+1))
else
  echo "FAIL: sidecar fallback (stdout=[$sc_out])"; fail=$((fail+1))
fi
rm -rf "$SW"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
