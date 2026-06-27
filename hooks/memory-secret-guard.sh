#!/usr/bin/env bash
# Warn (never block) when a write to docs/memory/ looks like it contains a secret.
# Claude Code PreToolUse hook (Edit|Write). Reads tool input JSON on stdin.
set -euo pipefail
input="$(cat)"
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
content="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null || true)"
case "$path" in
  */docs/memory/*|docs/memory/*) ;;   # in scope
  *) exit 0 ;;          # not a memory write — ignore
esac
if printf '%s' "$content" | grep -qEi '(api[_-]?key|secret|token|password|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,})'; then
  echo "⚠️  memory-secret-guard: possible secret in a docs/memory/ write to '$path'. Memory is shared and version-controlled (some repos are public). Remove secrets before committing." >&2 || true
fi
exit 0   # warn-only: never block
