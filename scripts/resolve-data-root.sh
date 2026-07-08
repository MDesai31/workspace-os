#!/usr/bin/env bash
# workspace-os data-root resolver — the SINGLE source of mode truth (conventions/data-root.md).
# Where a repo's workspace-os data lives is resolved, never assumed. Prints key=value lines:
#   mode=in-repo|sidecar|workspace-meta
#   data_root=<abs path>            in-repo: <repo>/docs   sidecar: <ws>/_meta/<repo-folder-name>
#   workspace=<name>                sidecar only, when the marker names one
#   workspace_root=<abs path>      sidecar + workspace-meta: the _meta dir
# Not inside a git repo -> message on stderr, exit 1. jq optional (grep fallback).
set -uo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "resolve-data-root: not inside a git repository" >&2
  exit 1
fi
# Repo root in the SHELL's path form (MSYS `/c/...` on Windows) — NOT git's `C:/...`
# `--show-toplevel` form — so emitted paths match `pwd` and downstream tooling on every platform.
cdup="$(git rev-parse --show-cdup 2>/dev/null)"
repo_root="$(cd "./${cdup}" 2>/dev/null && pwd)"
if [ -z "$repo_root" ]; then
  echo "resolve-data-root: not inside a git repository" >&2
  exit 1
fi

marker_mode() {  # marker_mode <marker-file> -> prints the "workspace-os" value
  if command -v jq >/dev/null 2>&1; then
    jq -r '."workspace-os" // empty' "$1" 2>/dev/null || true
  else
    grep -o '"workspace-os"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null \
      | head -1 | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/'
  fi
}
marker_name() {  # marker_name <marker-file> -> prints the "workspace" value
  if command -v jq >/dev/null 2>&1; then
    jq -r '.workspace // empty' "$1" 2>/dev/null || true
  else
    grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null \
      | head -1 | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/'
  fi
}

# The _meta repo itself: its data root is itself (never _meta/_meta).
if [ "$(basename "$repo_root")" = "_meta" ] && [ -f "$repo_root/workspace.json" ] \
   && [ "$(marker_mode "$repo_root/workspace.json")" = "sidecar" ]; then
  echo "mode=workspace-meta"
  echo "data_root=$repo_root"
  echo "workspace_root=$repo_root"
  exit 0
fi

# Walk up from the repo root's PARENT; nearest marker wins (spec §3).
dir="$(dirname "$repo_root")"
while :; do
  marker="$dir/_meta/workspace.json"
  if [ -f "$marker" ] && [ "$(marker_mode "$marker")" = "sidecar" ]; then
    echo "mode=sidecar"
    echo "data_root=$dir/_meta/$(basename "$repo_root")"
    name="$(marker_name "$marker")"
    [ -n "$name" ] && echo "workspace=$name"
    echo "workspace_root=$dir/_meta"
    exit 0
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break   # POSIX "/" and Windows "C:" both self-parent
  dir="$parent"
done

echo "mode=in-repo"
echo "data_root=$repo_root/docs"
exit 0
