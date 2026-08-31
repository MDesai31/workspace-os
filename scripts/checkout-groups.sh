#!/usr/bin/env bash
# workspace-os checkout grouping — which sibling folders are checkouts of ONE project.
# Usage: checkout-groups.sh <workspace-dir>
#   <workspace-dir> is the workspace root (the dir containing _meta/) or the _meta dir itself
#   (resolve-data-root.sh's workspace_root); a trailing _meta component is normalized away.
# Scans directories at depth 1, and depth 2 under non-repo dirs (mirroring the resolver's
# support for nested repos), excluding _meta/. For each git repo with an `origin` remote,
# prints one line:
#   project=<basename-of-key-path> key=<normalized-url> folder=<basename> branch=<current-or-empty>
# The key is the origin URL lowercased with scheme, credentials, and trailing .git stripped,
# and scp-style git@host:path rewritten to host/path. Non-repos and no-remote repos are
# skipped silently. Fail-loud on a missing argument or directory (a read tool that errors
# should say so). Deps: bash + git.
set -uo pipefail

root="${1:-}"
[ -n "$root" ] || { echo "checkout-groups: usage: checkout-groups.sh <workspace-dir>" >&2; exit 1; }
# Validate the argument AS GIVEN, then resolve to absolute, and only then strip a trailing
# _meta. Stripping first broke relative arguments both ways: `dirname _meta` is `.`, which
# always exists (so a nonexistent `_meta` silently scanned the caller's cwd), and a plain `.`
# from inside _meta never matched the basename test (so it scanned _meta's own subdirs and
# reported nothing). Fail-loud on a bad directory is this script's documented contract.
[ -d "$root" ] || { echo "checkout-groups: no such directory: $root" >&2; exit 1; }
root="$(cd "$root" && pwd)" || { echo "checkout-groups: cannot enter directory: $1" >&2; exit 1; }
[ "$(basename "$root")" = "_meta" ] && root="$(dirname "$root")"

normalize() {  # <origin-url> -> lowercase host/path key
  local u="$1"
  u="${u%.git}"
  u="${u#ssh://}"; u="${u#git://}"; u="${u#https://}"; u="${u#http://}"
  u="${u#*@}"          # user[:pass]@ credentials
  u="${u/:/\/}"        # scp-style host:path -> host/path
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

scan_repo() {  # <dir> -> 0 if a git repo (emitting a line when it has an origin), 1 otherwise
  local d="$1" url key branch
  [ -d "$d/.git" ] || return 1
  url="$(git -C "$d" remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || return 0
  key="$(normalize "$url")"
  branch="$(git -C "$d" branch --show-current 2>/dev/null || true)"
  printf 'project=%s key=%s folder=%s branch=%s\n' "${key##*/}" "$key" "$(basename "$d")" "$branch"
  return 0
}

for d in "$root"/*/; do
  d="${d%/}"
  [ -d "$d" ] || continue
  [ "$(basename "$d")" = "_meta" ] && continue
  scan_repo "$d" && continue
  for c in "$d"/*/; do
    c="${c%/}"
    [ -d "$c" ] || continue
    scan_repo "$c" || true
  done
done
exit 0
