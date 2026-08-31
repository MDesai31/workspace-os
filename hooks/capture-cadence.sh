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
- an open question that closes on evidence -> /project-log finding (a verdict closes it)
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
# Repo tier when there is one. In workspace-root mode there is NO repo tier (data_root unset),
# so fan out instead across the workspace's per-repo data dirs -- the exact inverse of the
# resolver's own data_root=<ws>/<repo-folder-name> mapping -- plus the workspace tier itself.
# Fail open: any error in this block must not break the hook.
lines=""
collect_handoffs() {  # <handoffs-dir> <label-prefix>
  local d="$1" prefix="$2" f slug paused
  [ -d "$d" ] || return 0
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    slug="$(basename "$f" .md)"
    paused="$(sed -n 's/^- Paused: //p' "$f" 2>/dev/null | head -1)"
    [ -n "$paused" ] || paused="unknown"
    lines="${lines}- ${prefix}${slug} (paused ${paused})
"
  done
}

if [ -n "$data_root" ]; then
  collect_handoffs "$data_root/project-tracking/handoffs" ""
elif [ -n "$ws_root" ]; then
  collect_handoffs "$ws_root/project-tracking/handoffs" ""
  for rd in "$ws_root"/*/; do
    rd="${rd%/}"
    [ -d "$rd" ] || continue
    collect_handoffs "$rd/project-tracking/handoffs" "$(basename "$rd")/"
  done
fi

if [ -n "$lines" ]; then
  printf '\n## Live handoffs\n%b' "$lines"
  printf 'A `<folder>/` prefix names the repo the handoff belongs to (workspace-root mode lists\nevery repo in the workspace). If the user'\''s request matches one of these efforts,\nREAD that handoff file fully before starting work; refresh it as the work moves, and\ndelete it via /project-log done when the effort completes.\n'
fi
exit 0
