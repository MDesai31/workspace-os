#!/usr/bin/env bash
# Test harness for hooks/capture-cadence.sh (deps: bash + git).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/capture-cadence.sh"
pass=0; fail=0
contains() { case "$2" in *"$3"*) echo "PASS: $1"; pass=$((pass+1));; *) echo "FAIL: $1 (out=[$2])"; fail=$((fail+1));; esac; }
empty() { if [ -z "$2" ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (want empty, got [$2])"; fail=$((fail+1)); fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# in-repo WITH tracking data -> emits the cadence
R1="$TMP/with-data"; mkdir -p "$R1/docs/project-tracking"; git -C "$R1" init -q
out="$(cd "$R1" && bash "$HOOK" 2>/dev/null)"
contains "in-repo with tracking data emits cadence" "$out" "capture cadence"
contains "cadence names /project-log" "$out" "/project-log"
contains "cadence names /ingest" "$out" "/ingest"
contains "cadence names /guardrails" "$out" "/guardrails"
contains "cadence names /playbook" "$out" "/playbook"
contains "cadence names propagated" "$out" "/project-log propagated"
contains "cadence names /handoff" "$out" "/handoff"

# in-repo with memory/ only -> still emits
R4="$TMP/memory-only"; mkdir -p "$R4/docs/memory"; git -C "$R4" init -q
out="$(cd "$R4" && bash "$HOOK" 2>/dev/null)"
contains "memory/ alone emits cadence" "$out" "capture cadence"

# in-repo WITHOUT workspace-os data -> silent
R2="$TMP/no-data"; mkdir -p "$R2"; git -C "$R2" init -q
out="$(cd "$R2" && bash "$HOOK" 2>/dev/null)"
empty "in-repo without workspace-os data is silent" "$out"

# outside a git repo -> silent, exit 0 (fail open)
R3="$TMP/not-git"; mkdir -p "$R3/docs/memory"
out="$(cd "$R3" && bash "$HOOK" 2>/dev/null)"; ec=$?
empty "outside a git repo is silent" "$out"
[ "$ec" = 0 ] && { echo "PASS: fail-open exit 0 outside git"; pass=$((pass+1)); } || { echo "FAIL: nonzero exit outside git"; fail=$((fail+1)); }

# sidecar mode: workspace-tier memory present -> emits
WS="$TMP/ws"; mkdir -p "$WS/_meta/memory" "$WS/repo-a"
printf '{"workspace-os":"sidecar","workspace":"test"}\n' > "$WS/_meta/workspace.json"
git -C "$WS/repo-a" init -q
out="$(cd "$WS/repo-a" && bash "$HOOK" 2>/dev/null)"
contains "sidecar with workspace-tier memory emits cadence" "$out" "capture cadence"

# in-repo with a live handoff -> emits the Live handoffs block
R5="$TMP/with-handoff"; mkdir -p "$R5/docs/project-tracking/handoffs"; git -C "$R5" init -q
printf '# Handoff: demo effort\n- Paused: 2026-08-20\n' > "$R5/docs/project-tracking/handoffs/demo-effort.md"
out="$(cd "$R5" && bash "$HOOK" 2>/dev/null)"
contains "live handoff block emitted" "$out" "Live handoffs"
contains "live handoff names the slug" "$out" "demo-effort"
contains "live handoff shows paused date" "$out" "2026-08-20"
contains "live handoff instructs a read" "$out" "READ that handoff file"

# no handoffs dir -> no block (R1 has tracking data but no handoffs/)
out="$(cd "$R1" && bash "$HOOK" 2>/dev/null)"
case "$out" in *"Live handoffs"*) echo "FAIL: no-handoffs repo emitted block"; fail=$((fail+1));; *) echo "PASS: no handoffs dir -> no block"; pass=$((pass+1));; esac

# workspace-root mode: no repo tier, so handoffs fan out across the workspace's repo dirs.
# Each repo-tier entry is labelled <folder>/<slug> (a bare slug is ambiguous across repos);
# a workspace-tier handoff stays bare, since it belongs to no repo.
WS2="$TMP/ws-root"; mkdir -p "$WS2/_meta/memory" "$WS2/repo-a" "$WS2/repo-b"
printf '{"workspace-os":"sidecar","workspace":"test"}\n' > "$WS2/_meta/workspace.json"
git -C "$WS2/repo-a" init -q; git -C "$WS2/repo-b" init -q
mkdir -p "$WS2/_meta/repo-a/project-tracking/handoffs" \
         "$WS2/_meta/repo-b/project-tracking/handoffs" \
         "$WS2/_meta/project-tracking/handoffs"
printf '# Handoff\n- Paused: 2026-08-21\n' > "$WS2/_meta/repo-a/project-tracking/handoffs/effort-one.md"
printf '# Handoff\n- Paused: 2026-08-22\n' > "$WS2/_meta/repo-b/project-tracking/handoffs/effort-two.md"
printf '# Handoff\n- Paused: 2026-08-23\n' > "$WS2/_meta/project-tracking/handoffs/ws-effort.md"
out="$(cd "$WS2" && bash "$HOOK" 2>/dev/null)"
contains "workspace-root emits Live handoffs" "$out" "Live handoffs"
contains "workspace-root labels repo-a handoff" "$out" "repo-a/effort-one"
contains "workspace-root labels repo-b handoff" "$out" "repo-b/effort-two"
contains "workspace-root shows repo-b paused date" "$out" "2026-08-22"
contains "workspace-root surfaces workspace-tier handoff" "$out" "ws-effort"

# sidecar mode stays repo-scoped: inside repo-a, repo-b's handoff must NOT surface.
out="$(cd "$WS2/repo-a" && bash "$HOOK" 2>/dev/null)"
contains "sidecar surfaces its own repo handoff" "$out" "effort-one"
case "$out" in *"effort-two"*) echo "FAIL: sidecar leaked a sibling repo's handoff"; fail=$((fail+1));; *) echo "PASS: sidecar does not leak sibling handoffs"; pass=$((pass+1));; esac

# workspace-root with no handoffs anywhere -> cadence but no block
WS3="$TMP/ws-root-bare"; mkdir -p "$WS3/_meta/memory"
printf '{"workspace-os":"sidecar","workspace":"test"}\n' > "$WS3/_meta/workspace.json"
out="$(cd "$WS3" && bash "$HOOK" 2>/dev/null)"
contains "bare workspace-root still emits cadence" "$out" "capture cadence"
case "$out" in *"Live handoffs"*) echo "FAIL: bare workspace-root emitted handoff block"; fail=$((fail+1));; *) echo "PASS: bare workspace-root -> no handoff block"; pass=$((pass+1));; esac

# unreadable handoff file -> hook still exits 0 (fail open)
R6="$TMP/bad-handoff"; mkdir -p "$R6/docs/project-tracking/handoffs"; git -C "$R6" init -q
printf 'x\n' > "$R6/docs/project-tracking/handoffs/locked.md"; chmod 000 "$R6/docs/project-tracking/handoffs/locked.md"
( cd "$R6" && bash "$HOOK" >/dev/null 2>&1 ); ec=$?
chmod 644 "$R6/docs/project-tracking/handoffs/locked.md"
[ "$ec" = 0 ] && { echo "PASS: unreadable handoff fail-open"; pass=$((pass+1)); } || { echo "FAIL: unreadable handoff nonzero exit"; fail=$((fail+1)); }

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
