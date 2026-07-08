#!/usr/bin/env bash
# Plain-bash test harness for scripts/resolve-data-root.sh (deps: bash + git; jq optional).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$HERE/../scripts/resolve-data-root.sh"
pass=0; fail=0

# Fixture workspaces are built at runtime (committed fixtures can't hold nested .git dirs).
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mk_repo() { mkdir -p "$1" && git -C "$1" init -q; }

# Marked workspace with two repos, one nested a level deeper
WS="$TMP/ws"
mkdir -p "$WS/_meta"
printf '{ "workspace-os": "sidecar", "workspace": "test-ws" }\n' > "$WS/_meta/workspace.json"
mk_repo "$WS/repo-a"
mkdir -p "$WS/repo-a/src" "$WS/repo-a/docs/project-tracking"   # sidecar must win over in-repo dirs
mkdir -p "$WS/nested"
mk_repo "$WS/nested/repo-b"                                     # marker is in a grandparent
git -C "$WS/_meta" init -q                                      # _meta is itself a git repo

# Unmarked plain repo
mk_repo "$TMP/plain"
# _meta dir WITHOUT workspace.json
mkdir -p "$TMP/ws2/_meta"; mk_repo "$TMP/ws2/repo-c"
# marker present but mode value is not "sidecar"
mkdir -p "$TMP/ws3/_meta"
printf '{ "workspace-os": "off" }\n' > "$TMP/ws3/_meta/workspace.json"
mk_repo "$TMP/ws3/repo-d"
# not a git repo at all
mkdir -p "$TMP/norepo"

# run <dir> -> sets globals ec, out
run() { out="$(cd "$1" && bash "$RESOLVER" 2>&1)"; ec=$?; }

# check <name> <got_ec> <want_ec> <got_out> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec out=[$got_out])"; fail=$((fail+1)); fi
}

run "$WS/repo-a"
check "marked ws: sidecar mode" "$ec" "0" "$out" "mode=sidecar"
check "marked ws: data_root under _meta" "$ec" "0" "$out" "data_root=$WS/_meta/repo-a"
check "marked ws: workspace name" "$ec" "0" "$out" "workspace=test-ws"
check "marked ws: workspace_root" "$ec" "0" "$out" "workspace_root=$WS/_meta"

run "$WS/repo-a/src"
check "resolves from a subdir" "$ec" "0" "$out" "data_root=$WS/_meta/repo-a"

run "$WS/repo-a"
check "sidecar wins over in-repo docs/" "$ec" "0" "$out" "mode=sidecar"

run "$WS/nested/repo-b"
check "grandparent marker found" "$ec" "0" "$out" "data_root=$WS/_meta/repo-b"

run "$WS/_meta"
check "inside _meta itself: workspace-meta mode" "$ec" "0" "$out" "mode=workspace-meta"
check "workspace-meta data_root is _meta" "$ec" "0" "$out" "data_root=$WS/_meta"

run "$TMP/plain"
check "unmarked repo: in-repo mode" "$ec" "0" "$out" "mode=in-repo"
check "in-repo data_root is <repo>/docs" "$ec" "0" "$out" "data_root=$TMP/plain/docs"

run "$TMP/ws2/repo-c"
check "_meta without marker = in-repo" "$ec" "0" "$out" "mode=in-repo"

run "$TMP/ws3/repo-d"
check "marker without sidecar value = in-repo" "$ec" "0" "$out" "mode=in-repo"

run "$TMP/norepo"
check "not a git repo errors" "$ec" "1" "$out" "not inside a git repository"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
