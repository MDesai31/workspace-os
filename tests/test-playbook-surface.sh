#!/usr/bin/env bash
# Plain-bash test harness for hooks/playbook-surface.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/playbook-surface.sh"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1${2:+ ($2)}"; fail=$((fail+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmp"; mkdir -p "$TMPDIR"   # markers land here, not /tmp

# in-repo fixture: git repo with docs/playbooks/
R="$TMP/repo"; mkdir -p "$R/docs/playbooks"; git -C "$R" init -q
cat > "$R/docs/playbooks/snowflake.md" <<'EOF'
---
name: snowflake-querying
description: query snowflake safely
trigger-bash: sfq\.py
surface: before
---
# Snowflake querying
## Steps
- always use --dry-run first
EOF
cat > "$R/docs/playbooks/notebooks.md" <<'EOF'
---
name: notebook-editing
description: edit notebooks safely
trigger-path: \.ipynb$
surface: after
---
# Notebook editing
## Known traps
- never edit raw JSON by hand
EOF

# call <event> <session> <tool> <json-field> <value> -> $out (stdout), $err, $ec
call() {
  local ev="$1" sid="$2" tool="$3" field="$4" val="$5"
  local json; json="$(jq -cn --arg ev "$ev" --arg sid "$sid" --arg tool "$tool" \
    --arg f "$field" --arg v "$val" '{hook_event_name:$ev, session_id:$sid, tool_name:$tool,
    tool_input: {($f): $v}}')"
  out="$(cd "$R" && printf '%s' "$json" | bash "$HOOK" 2>"$TMP/err")"; ec=$?
  err="$(cat "$TMP/err")"
}

# --- before-mode: first matching Bash call denies with path ---
call PreToolUse s1 Bash command "python sfq.py --query 'select 1'"
[ "$ec" = 2 ] && ok "before: first match denies (exit 2)" || bad "before: first match denies" "ec=$ec"
case "$err" in *"snowflake-querying"*) ok "before: reason names playbook";; *) bad "before: reason names playbook" "err=[$err]";; esac
case "$err" in *"/docs/playbooks/snowflake.md"*) ok "before: reason carries path";; *) bad "before: reason carries path" "err=[$err]";; esac

# --- same session second call passes; different session denies again ---
call PreToolUse s1 Bash command "python sfq.py again"
[ "$ec" = 0 ] && [ -z "$out$err" ] && ok "before: same session passes silently" || bad "before: same session passes silently" "ec=$ec"
call PreToolUse s2 Bash command "python sfq.py again"
[ "$ec" = 2 ] && ok "before: new session denies again" || bad "before: new session denies again" "ec=$ec"

# --- after-mode: PostToolUse Edit on .ipynb injects additionalContext once ---
call PostToolUse s3 Edit file_path "$R/nb/analysis.ipynb"
[ "$ec" = 0 ] && ok "after: exit 0" || bad "after: exit 0" "ec=$ec"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("never edit raw JSON")' >/dev/null 2>&1; then
  ok "after: body injected via additionalContext"
else bad "after: body injected via additionalContext" "out=[$out]"; fi
call PostToolUse s3 Edit file_path "$R/nb/analysis.ipynb"
[ "$ec" = 0 ] && [ -z "$out" ] && ok "after: once per session" || bad "after: once per session" "out=[$out]"

# --- mode/event cross-silence ---
call PostToolUse s4 Bash command "python sfq.py x"
[ "$ec" = 0 ] && [ -z "$out" ] && ok "before-playbook silent on PostToolUse" || bad "before-playbook silent on PostToolUse" "ec=$ec out=[$out]"
call PreToolUse s4 Edit file_path "$R/nb/analysis.ipynb"
[ "$ec" = 0 ] && [ -z "$out$err" ] && ok "after-playbook silent on PreToolUse" || bad "after-playbook silent on PreToolUse" "ec=$ec"

# --- ordering: two before-playbooks matching one command deny one at a time ---
cat > "$R/docs/playbooks/aaa-first.md" <<'EOF'
---
name: aaa-first
trigger-bash: doubletrig
surface: before
---
body
EOF
cat > "$R/docs/playbooks/zzz-second.md" <<'EOF'
---
name: zzz-second
trigger-bash: doubletrig
surface: before
---
body
EOF
call PreToolUse s5 Bash command "doubletrig now"
case "$err" in *"aaa-first"*) ok "ordering: first slug denies first";; *) bad "ordering: first slug denies first" "err=[$err]";; esac
call PreToolUse s5 Bash command "doubletrig now"
case "$err" in *"zzz-second"*) ok "ordering: second slug denies on next call";; *) bad "ordering: second slug denies on next call" "err=[$err]";; esac
call PreToolUse s5 Bash command "doubletrig now"
[ "$ec" = 0 ] && ok "ordering: both marked -> pass" || bad "ordering: both marked -> pass" "ec=$ec"

# --- long body (>300 lines) -> pointer instead of content ---
{ printf -- '---\nname: long-one\ntrigger-bash: longtrig\nsurface: after\n---\n'
  for i in $(seq 1 320); do echo "line $i"; done; } > "$R/docs/playbooks/long-one.md"
call PostToolUse s6 Bash command "longtrig go"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | (contains("read ") and (contains("line 250") | not))' >/dev/null 2>&1; then
  ok "long body -> read-path instruction"
else bad "long body -> read-path instruction" "out=[$out]"; fi

# --- silence paths ---
call PreToolUse s7 Bash command "git status"
[ "$ec" = 0 ] && [ -z "$out$err" ] && ok "non-matching call silent" || bad "non-matching call silent" "ec=$ec"
printf 'garbage no frontmatter' > "$R/docs/playbooks/broken.md"
call PreToolUse s7 Bash command "git status"
[ "$ec" = 0 ] && ok "malformed playbook skipped" || bad "malformed playbook skipped" "ec=$ec"
printf -- '---\nname: no-trig\n---\nbody' > "$R/docs/playbooks/no-trig.md"
call PreToolUse s7 Bash command "anything at all"
[ "$ec" = 0 ] && ok "trigger-less playbook never surfaces" || bad "trigger-less playbook never surfaces" "ec=$ec"
R2="$TMP/no-pb"; mkdir -p "$R2"; git -C "$R2" init -q
out="$(cd "$R2" && printf '{"hook_event_name":"PreToolUse","session_id":"s8","tool_name":"Bash","tool_input":{"command":"sfq.py"}}' | bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && ok "no playbooks dir silent" || bad "no playbooks dir silent" "ec=$ec"
out="$(printf 'not json' | bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && ok "malformed stdin silent" || bad "malformed stdin silent" "ec=$ec"

# --- workspace tier: sidecar repo surfaces workspace playbook ---
WS="$TMP/ws"; mkdir -p "$WS/_meta/playbooks" "$WS/repo-a"
printf '{"workspace-os":"sidecar","workspace":"t"}\n' > "$WS/_meta/workspace.json"
git -C "$WS/repo-a" init -q
cat > "$WS/_meta/playbooks/ws-play.md" <<'EOF'
---
name: ws-play
trigger-bash: wstrig
surface: before
---
body
EOF
json='{"hook_event_name":"PreToolUse","session_id":"s9","tool_name":"Bash","tool_input":{"command":"wstrig go"}}'
err9="$(cd "$WS/repo-a" && printf '%s' "$json" | bash "$HOOK" 2>&1 >/dev/null)"; ec=$?
[ "$ec" = 2 ] && ok "workspace-tier playbook surfaces in sidecar repo" || bad "workspace-tier playbook surfaces in sidecar repo" "ec=$ec err=[$err9]"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
