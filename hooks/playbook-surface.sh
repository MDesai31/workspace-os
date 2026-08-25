#!/usr/bin/env bash
# workspace-os playbook surfacing — PreToolUse + PostToolUse hook (Bash|Edit|Write).
# Surfaces a matching playbook at most once per session per playbook:
#   surface: before -> PreToolUse deny-once (exit 2; stderr instructs read + retry;
#                      the marker is written FIRST so the retry passes)
#   surface: after  -> PostToolUse additionalContext injection (body, or a read-path
#                      instruction for bodies over 300 lines)
# PreToolUse cannot inject context non-blockingly (verified 2026-08-24; see
# conventions/playbooks.md) — hence the deny-once pattern for 'before'.
# Fail open EVERYWHERE: any error -> silent exit 0.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)" || exit 0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null || true)"
case "$event" in PreToolUse|PostToolUse) ;; *) exit 0 ;; esac

case "$tool" in
  Bash)
    subject="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    tkey="trigger-bash" ;;
  Edit|Write)
    subject="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    tkey="trigger-path" ;;
  *) exit 0 ;;
esac
[ -n "$subject" ] || exit 0

out="$(bash "$HERE/../scripts/resolve-data-root.sh" 2>/dev/null || true)"
data_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
ws_root="$(printf '%s\n' "$out" | sed -n 's/^workspace_root=//p')"

dirs=()
[ -n "$data_root" ] && [ -d "$data_root/playbooks" ] && dirs+=("$data_root/playbooks")
[ -n "$ws_root" ] && [ -d "$ws_root/playbooks" ] && dirs+=("$ws_root/playbooks")
[ "${#dirs[@]}" -gt 0 ] || exit 0

markdir="${TMPDIR:-/tmp}/workspace-os-surfaced-$sid"

# front <file> -> the flat frontmatter block (lines between the first two --- lines)
front() { awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---$/{exit} {print}' "$1" 2>/dev/null; }
# fval <frontmatter> <key> -> value
fval() { printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

for d in "${dirs[@]}"; do
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    fm="$(front "$f")"; [ -n "$fm" ] || continue
    trig="$(fval "$fm" "$tkey")"
    [ -n "$trig" ] || continue
    printf '%s' "$subject" | grep -qE -- "$trig" 2>/dev/null || continue
    slug="$(basename "$f" .md)"
    [ -f "$markdir/$slug" ] && continue
    name="$(fval "$fm" name)"; [ -n "$name" ] || name="$slug"
    mode="$(fval "$fm" surface)"; [ "$mode" = "after" ] || mode="before"
    if [ "$mode" = "before" ] && [ "$event" = "PreToolUse" ]; then
      mkdir -p "$markdir" 2>/dev/null || exit 0
      : > "$markdir/$slug" 2>/dev/null || exit 0
      printf "playbook '%s' applies to this call - read %s first, then retry.\n" "$name" "$f" >&2
      exit 2
    elif [ "$mode" = "after" ] && [ "$event" = "PostToolUse" ]; then
      mkdir -p "$markdir" 2>/dev/null || exit 0
      : > "$markdir/$slug" 2>/dev/null || exit 0
      body="$(awk 'c>=2{print} /^---$/{c++}' "$f" 2>/dev/null)"
      nlines="$(printf '%s\n' "$body" | wc -l)"
      if [ "$nlines" -gt 300 ]; then
        ctx="playbook '$name' applies to the call you just made - read $f before continuing."
      else
        ctx="## Playbook: $name ($f)
$body"
      fi
      jq -cn --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
      exit 0
    fi
  done
done
exit 0
