#!/usr/bin/env bash
# workspace-os dispatch ledger — PostToolUse hook (Task|Agent subagent dispatches).
# Appends one JSONL line per dispatch to a LOCAL-ONLY ledger (default under ~/.claude,
# outside every repo by construction). Pure telemetry: fail open on EVERYTHING — any
# error is a silent exit 0; never blocks, never prints on success.
# PRIVACY INVARIANT: prompt/response TEXT never reaches the ledger — lengths + a short
# desc label only (safe to keep in a home-dir file while working in employer repos).
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)" || exit 0

ledger="${DISPATCH_LEDGER:-$HOME/.claude/workspace-os/dispatch-ledger.jsonl}"
mkdir -p "$(dirname "$ledger")" 2>/dev/null || exit 0

ts="$(date -u +%FT%TZ)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
repo=""
if [ -n "$cwd" ]; then
  top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] && repo="$(basename "$top")"
fi

line="$(printf '%s' "$input" | jq -c --arg ts "$ts" --arg repo "$repo" '
  .tool_input as $ti | select($ti != null)
  | (.tool_response // .tool_result // null) as $r
  | (if $r == null then "" elif ($r | type) == "string" then $r else ($r | tojson) end) as $rs
  | (($ti.prompt // "") | length) as $pc
  | ($rs | length) as $rc
  | {
      ts: $ts,
      session_id: (.session_id // ""),
      cwd: (.cwd // ""),
      repo: $repo,
      agent: ($ti.subagent_type // $ti.agentType // "unknown"),
      desc: (($ti.description // "")[0:120]),
      prompt_chars: $pc,
      response_chars: $rc,
      est_tokens: ((($pc + $rc) / 4) | floor),
      tokens: (($r.totalTokens? // $r.usage?.total_tokens? // $r.usage?.totalTokens?) // null),
      duration_ms: (($r.totalDurationMs? // $r.duration_ms?) // null),
      is_error: (($r.is_error?) // null)
    }' 2>/dev/null)" || exit 0
[ -n "$line" ] || exit 0
printf '%s\n' "$line" >> "$ledger" 2>/dev/null || true
exit 0
