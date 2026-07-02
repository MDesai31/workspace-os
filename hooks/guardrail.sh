#!/usr/bin/env bash
# workspace-os guardrail engine — PreToolUse hook (Bash|Edit|Write).
# Reads tool-call JSON on stdin. Deny -> exit 2 + reason on stderr; warn -> reason on stderr, exit 0.
# Fail open: any error / no jq / no match -> exit 0 (never block a tool call).
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0   # can't parse -> fail open

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
denies=(); warns=()

case "$tool" in
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push' \
       && printf '%s' "$cmd" | grep -qE -- '(--force|-f)([[:space:]]|$)' \
       && printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(main|master)([[:space:]]|$)'; then
      warns+=("guardrail: force-push to a protected branch (main/master).")
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])rm([[:space:]]|$)' \
       && printf '%s' "$cmd" | grep -qE '\-[a-zA-Z]*r' \
       && printf '%s' "$cmd" | grep -qE '\-[a-zA-Z]*f' \
       && printf '%s' "$cmd" | grep -qE '[[:space:]](/|~|\.|\*)([[:space:]/]|$)'; then
      warns+=("guardrail: 'rm' with -r and -f targeting a root-like path.")
    fi
    ;;
  Edit|Write)
    content="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null || true)"
    if printf '%s' "$content" | grep -qE '(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,})'; then
      denies+=("guardrail: high-confidence secret detected in write content. Remove it before writing.")
    fi
    path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    if printf '%s' "$content" | grep -qEi '(api[_-]?key|secret|token|password)'; then
      warns+=("guardrail: possible secret in write content ('$path'). Files are version-controlled — do not commit secrets.")
    fi
    ;;
esac

config="${GUARDRAIL_CONFIG:-}"
if [ -z "$config" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
  config="$root/.claude/guardrails.json"
fi

if [ -n "$config" ] && [ -f "$config" ] && jq -e . "$config" >/dev/null 2>&1; then
  case "$tool" in
    Bash)
      while IFS=$'\t' read -r action reason; do
        [ -z "$action" ] && continue
        if [ "$action" = "deny" ]; then denies+=("$reason"); else warns+=("$reason"); fi
      done < <(jq -r --arg s "${cmd:-}" \
        '(.bash // [])[] | .match as $m | select($m != null and ($s | test($m))) | "\(.action)\t\(.reason)"' \
        "$config" 2>/dev/null)
      ;;
    Edit|Write)
      while IFS=$'\t' read -r action reason; do
        [ -z "$action" ] && continue
        if [ "$action" = "deny" ]; then denies+=("$reason"); else warns+=("$reason"); fi
      done < <(jq -r --arg path "${path:-}" --arg content "${content:-}" \
        '(.write // [])[] | .match as $m | select($m != null and ((if (.field // "content") == "path" then $path else $content end) | test($m))) | "\(.action)\t\(.reason)"' \
        "$config" 2>/dev/null)
      ;;
  esac
fi

if [ "${#denies[@]}" -gt 0 ]; then printf '%s\n' "${denies[@]}" >&2; exit 2; fi
if [ "${#warns[@]}" -gt 0 ]; then printf '%s\n' "${warns[@]}" >&2; fi
exit 0
