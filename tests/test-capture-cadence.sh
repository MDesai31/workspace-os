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

# unreadable handoff file -> hook still exits 0 (fail open)
R6="$TMP/bad-handoff"; mkdir -p "$R6/docs/project-tracking/handoffs"; git -C "$R6" init -q
printf 'x\n' > "$R6/docs/project-tracking/handoffs/locked.md"; chmod 000 "$R6/docs/project-tracking/handoffs/locked.md"
( cd "$R6" && bash "$HOOK" >/dev/null 2>&1 ); ec=$?
chmod 644 "$R6/docs/project-tracking/handoffs/locked.md"
[ "$ec" = 0 ] && { echo "PASS: unreadable handoff fail-open"; pass=$((pass+1)); } || { echo "FAIL: unreadable handoff nonzero exit"; fail=$((fail+1)); }

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
