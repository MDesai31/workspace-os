#!/usr/bin/env bash
# workspace-os capture cadence - SessionStart hook.
# Emits a short always-loaded instruction telling the model to capture decisions/facts/actions
# proactively and PROPOSE them as a batch at task boundaries. Emitted ONLY when this repo has
# workspace-os data (a project-tracking/ or memory/ dir under the resolved data root, or the
# sidecar workspace tier), so unrelated repos are unaffected. Fires in BOTH data-root modes.
# Fail open always: any error, missing data, or non-git dir -> no output, exit 0.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out="$(bash "$HERE/../scripts/resolve-data-root.sh" 2>/dev/null)" || exit 0
data_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
ws_root="$(printf '%s\n' "$out" | sed -n 's/^workspace_root=//p')"

has_data=0
check_dir() { [ -n "$1" ] && [ -d "$1" ] && has_data=1; }
if [ -n "$data_root" ]; then
  check_dir "$data_root/project-tracking"
  check_dir "$data_root/memory"
fi
if [ -n "$ws_root" ]; then
  check_dir "$ws_root/memory"
  check_dir "$ws_root/project-tracking"
fi
[ "$has_data" = 1 ] || exit 0

cat <<'EOF'
## workspace-os capture cadence

As you work in this repo, watch for durable items worth recording and capture them proactively:
- a decision (a choice + why) -> /project-log decision (or model-decision)
- a started or finished action -> /project-log action | done
- a durable fact about this codebase -> /ingest
- a future intent -> /project-plan
- a hazard or near-miss worth a permanent rule -> /guardrails
- a repeated multi-step procedure -> /playbook
- a fix landed in another checkout of this project -> /project-log propagated
- stopping with work unfinished -> /handoff

Do not interrupt mid-task. Accumulate candidates and PROPOSE them as a batch at a natural stopping
point (task done, before a commit). On the user's confirmation, invoke the relevant skill so the
record follows its full ritual (format, the AGENTS.md/CLAUDE.md boundary test, secret-scan,
idempotency). Skip trivia; capture only what future-you could not re-derive.
EOF

# Live handoffs: surface paused efforts (conventions/project-tracking.md § Session continuity).
# Fail open: any error in this block must not break the hook.
hdir="$data_root/project-tracking/handoffs"
if [ -n "$data_root" ] && [ -d "$hdir" ]; then
  lines=""
  for f in "$hdir"/*.md; do
    [ -f "$f" ] || continue
    slug="$(basename "$f" .md)"
    paused="$(sed -n 's/^- Paused: //p' "$f" 2>/dev/null | head -1)"
    [ -n "$paused" ] || paused="unknown"
    lines="${lines}- ${slug} (paused ${paused})
"
  done
  if [ -n "$lines" ]; then
    printf '\n## Live handoffs\n%b' "$lines"
    printf 'If the user'\''s request matches one of these efforts, READ that handoff file fully before\nstarting work; refresh it as the work moves, and delete it via /project-log done when the\neffort completes.\n'
  fi
fi
exit 0
