#!/usr/bin/env bash
# Plain-bash test harness for scripts/checkout-groups.sh (deps: bash + git).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/checkout-groups.sh"
pass=0; fail=0

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
G() { git -c user.email=t@t -c user.name=t "$@"; }

WS="$TMP/ws"
mkdir -p "$WS/_meta"
printf '{ "workspace-os": "sidecar", "workspace": "test-ws" }\n' > "$WS/_meta/workspace.json"

# A + B: same project via different URL forms; A on a named branch
mkdir -p "$WS/checkout-a" && G -C "$WS/checkout-a" init -q -b work
G -C "$WS/checkout-a" remote add origin "https://Host.example/Org/Repo.git"
# B: scp-style URL, detached HEAD
mkdir -p "$WS/checkout-b" && G -C "$WS/checkout-b" init -q -b main
G -C "$WS/checkout-b" remote add origin "git@host.example:org/repo.git"
( cd "$WS/checkout-b" && touch f && G add f && G commit -qm c && G checkout -q --detach )
# C: a different project
mkdir -p "$WS/other" && G -C "$WS/other" init -q -b main
G -C "$WS/other" remote add origin "https://host.example/org/elsewhere.git"
# D: repo with no remote; E: not a repo; F: nested one level under a plain dir
mkdir -p "$WS/noremote" && G -C "$WS/noremote" init -q
mkdir -p "$WS/plaindir"
mkdir -p "$WS/nested/checkout-f" && G -C "$WS/nested/checkout-f" init -q -b main
G -C "$WS/nested/checkout-f" remote add origin "https://host.example/org/repo.git"

check() { # check <name> <cond-ok 0|1>
  if [ "$2" = 0 ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}

out="$(bash "$SCRIPT" "$WS")"; ec=$?
check "exits 0 on a valid workspace" $([ "$ec" = 0 ] && echo 0 || echo 1)

line_a="$(printf '%s\n' "$out" | grep 'folder=checkout-a' || true)"
line_b="$(printf '%s\n' "$out" | grep 'folder=checkout-b' || true)"
line_f="$(printf '%s\n' "$out" | grep 'folder=checkout-f' || true)"
key_a="$(printf '%s' "$line_a" | sed 's/.*key=\([^ ]*\).*/\1/')"
key_b="$(printf '%s' "$line_b" | sed 's/.*key=\([^ ]*\).*/\1/')"

check "A normalized (scheme/case/.git stripped)" $([ "$key_a" = "host.example/org/repo" ] && echo 0 || echo 1)
check "A and B share a key (scp form matches)" $([ -n "$key_a" ] && [ "$key_a" = "$key_b" ] && echo 0 || echo 1)
check "project name is key basename" $(printf '%s' "$line_a" | grep -q 'project=repo ' && echo 0 || echo 1)
check "branch reported for A" $(printf '%s' "$line_a" | grep -q 'branch=work' && echo 0 || echo 1)
check "detached HEAD -> empty branch" $(printf '%s' "$line_b" | grep -q 'branch=$' && echo 0 || echo 1)
check "different remote gets its own key" $(printf '%s\n' "$out" | grep 'folder=other' | grep -q 'key=host.example/org/elsewhere' && echo 0 || echo 1)
check "nested depth-2 checkout found" $([ -n "$line_f" ] && echo 0 || echo 1)
check "no-remote repo skipped" $(printf '%s\n' "$out" | grep -q 'folder=noremote' && echo 1 || echo 0)
check "non-repo dir skipped" $(printf '%s\n' "$out" | grep -q 'folder=plaindir' && echo 1 || echo 0)
check "_meta never scanned" $(printf '%s\n' "$out" | grep -q 'folder=_meta' && echo 1 || echo 0)

out2="$(bash "$SCRIPT" "$WS/_meta")"
check "accepts the _meta dir and normalizes" $([ "$out2" = "$out" ] && echo 0 || echo 1)

bash "$SCRIPT" "$TMP/definitely-missing" 2>/dev/null; ec=$?
check "missing dir -> exit 1" $([ "$ec" = 1 ] && echo 0 || echo 1)
bash "$SCRIPT" 2>/dev/null; ec=$?
check "missing arg -> exit 1" $([ "$ec" = 1 ] && echo 0 || echo 1)

echo "---"; echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
