#!/usr/bin/env bash
# workspace-os advisory-lint engine — PostToolUse hook (Edit|Write|MultiEdit).
# Reads tool-call JSON on stdin. Lints the edited file with repo-declared linters; non-empty
# linter output -> additionalContext (for Claude to act on). Clean -> silent.
# Fail open: any error / no jq / no config / linter absent -> exit 0, no output.
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0   # can't parse -> fail open

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -z "$file_path" ] && exit 0
path_fwd="$(printf '%s' "$file_path" | tr '\\' '/')"   # Windows file_path is backslashed; match on a forward-slash view

# Config resolution: LINT_CONFIG (test override), else <repo-root>/.claude/lint.json;
# in a marked workspace with no in-repo config, fall back to the sidecar <data_root>/lint.json.
config="${LINT_CONFIG:-}"
if [ -z "$config" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
  config="$root/.claude/lint.json"
  if [ ! -f "$config" ]; then
    HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sc_out="$(bash "$HOOK_DIR/../scripts/resolve-data-root.sh" 2>/dev/null || true)"
    sc_mode="$(printf '%s\n' "$sc_out" | sed -n 's/^mode=//p')"
    sc_root="$(printf '%s\n' "$sc_out" | sed -n 's/^data_root=//p')"
    if [ "$sc_mode" = "sidecar" ] && [ -f "$sc_root/lint.json" ]; then
      config="$sc_root/lint.json"
    fi
  fi
fi

[ -n "$config" ] && [ -f "$config" ] && jq -e . "$config" >/dev/null 2>&1 || exit 0

# Run every linter whose `match` matches the file path; collect non-empty output.
report=""
while IFS=$'\t' read -r name cmd; do
  [ -z "$cmd" ] && continue
  cmd="${cmd%$'\r'}"  # strip trailing CR (CRLF from jq on Windows)
  out="$($cmd "$file_path" 2>&1)"; ec=$?
  [ "$ec" -eq 127 ] && continue          # linter not on PATH -> silent (fail open)
  [ -n "$out" ] && report+="[$name] $out"$'\n'
done < <(jq -r --arg p "$path_fwd" \
  '(.linters // [])[] | .match as $m | select($m != null and ($p | test($m))) | "\(.name)\t\(.command)"' \
  "$config" 2>/dev/null)

[ -z "$report" ] && exit 0

# additionalContext is capped at 10,000 chars by the hooks contract — truncate to a safe margin.
if [ "${#report}" -gt 9500 ]; then
  report="${report:0:9500}"$'\n[lint output truncated]'
fi

# Emit the diagnostics as PostToolUse additionalContext (stdout must be JSON-only; exit 0).
jq -cn --arg c "$report" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
exit 0
