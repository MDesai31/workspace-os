#!/usr/bin/env bash
# workspace-os guardrail engine — PreToolUse hook (Bash|Edit|Write).
# Reads tool-call JSON on stdin. Deny -> exit 2 + reason on stderr; warn -> reason on stderr, exit 0.
# Fail open: any error / no jq / no match -> exit 0 (never block a tool call).
# Config rules may carry a `predicate` (shell): the rule fires only when its regex matches AND the
# predicate exits 0, run in the call's cwd under a 5s timeout; any other outcome skips the rule
# (spec: docs/specs/2026-09-04-stateful-guardrail-predicates-design.md).
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0   # can't parse -> fail open

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
call_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -d "$call_cwd" ] || call_cwd="$PWD"
denies=(); warns=()

# predicate_holds <shell>: 0 iff the predicate exits 0 within 5s in the call's cwd. Output discarded;
# timeout (124), errors, and a missing `timeout` binary all fall through as "not fired" (fail open).
predicate_holds() {
  [ -z "$1" ] && return 0
  if command -v timeout >/dev/null 2>&1; then
    (cd "$call_cwd" && timeout 5 bash -c "$1") >/dev/null 2>&1
  else
    (cd "$call_cwd" && bash -c "$1") >/dev/null 2>&1
  fi
}

# Sidecar resolution (conventions/data-root.md). Fail open: resolver errors = in-repo behavior.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sc_out="$(bash "$HOOK_DIR/../scripts/resolve-data-root.sh" 2>/dev/null || true)"
sc_mode="$(printf '%s\n' "$sc_out" | sed -n 's/^mode=//p')"
sc_root="$(printf '%s\n' "$sc_out" | sed -n 's/^data_root=//p')"

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
    path_fwd="$(printf '%s' "$path" | tr '\\' '/')"   # Windows file_path is backslashed; match on a forward-slash view
    if [ "$sc_mode" = "sidecar" ] \
       && printf '%s' "$path_fwd" | grep -qE '(^|/)(docs/project-tracking|docs/memory)(/|$)|(^|/)\.claude/guardrails\.json$' \
       && ! printf '%s' "$path_fwd" | grep -qF '/_meta/'; then
      warns+=("guardrail: sidecar mode — the workspace-os data layer for this repo lives in _meta/, not in the repo tree ('$path'). See conventions/data-root.md.")
    fi
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
  # Sidecar fallback: in-repo config wins where present (spec §6).
  if [ ! -f "$config" ] && [ "$sc_mode" = "sidecar" ] && [ -f "$sc_root/guardrails.json" ]; then
    config="$sc_root/guardrails.json"
  fi
fi

if [ -n "$config" ] && [ -f "$config" ] && jq -e . "$config" >/dev/null 2>&1; then
  case "$tool" in
    Bash)
      while IFS=$'\t' read -r action reason predicate; do
        [ -z "$action" ] && continue
        predicate_holds "$predicate" || continue
        if [ "$action" = "deny" ]; then denies+=("$reason"); else warns+=("$reason"); fi
      done < <(jq -r --arg s "${cmd:-}" \
        '(.bash // [])[] | .match as $m | select($m != null and ($s | test($m))) | "\(.action)\t\(.reason)\t\(.predicate // "")"' \
        "$config" 2>/dev/null)
      ;;
    Edit|Write)
      while IFS=$'\t' read -r action reason predicate; do
        [ -z "$action" ] && continue
        predicate_holds "$predicate" || continue
        if [ "$action" = "deny" ]; then denies+=("$reason"); else warns+=("$reason"); fi
      done < <(jq -r --arg path "${path_fwd:-}" --arg content "${content:-}" \
        '(.write // [])[] | .match as $m | select($m != null and ((if (.field // "content") == "path" then $path else $content end) | test($m))) | "\(.action)\t\(.reason)\t\(.predicate // "")"' \
        "$config" 2>/dev/null)
      ;;
  esac
fi

# Deny: exit 2 with the reason(s) on stderr — the PreToolUse blocking contract feeds stderr to Claude.
if [ "${#denies[@]}" -gt 0 ]; then printf '%s\n' "${denies[@]}" >&2; exit 2; fi
# Warn: emit a top-level `systemMessage` JSON object on stdout — the documented user-facing warning
# channel (exit 0 = non-blocking). Deliberately NOT `additionalContext`: warns must not pollute
# Claude's context on routine edits.
if [ "${#warns[@]}" -gt 0 ]; then
  msg="$(printf '%s\n' "${warns[@]}")"
  jq -cn --arg m "$msg" '{systemMessage: $m}'
fi
exit 0
