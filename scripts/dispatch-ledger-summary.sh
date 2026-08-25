#!/usr/bin/env bash
# workspace-os dispatch-ledger summary — read-only view over the local dispatch ledger
# (written by hooks/dispatch-ledger.sh). Fails loud, unlike the capture hook: a read tool
# that errors should say so. Torn lines are tolerated (skipped + counted) — an append-only
# file written by a fail-open hook may legitimately contain one.
set -uo pipefail
die() { echo "dispatch-ledger-summary: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq is required"

ledger="${DISPATCH_LEDGER:-$HOME/.claude/workspace-os/dispatch-ledger.jsonl}"
repo=""; top=10
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || die "missing value for --repo"; repo="$2"; shift 2 ;;
    --top)  [ $# -ge 2 ] || die "missing value for --top"; top="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
case "$top" in ''|*[!0-9]*) die "--top must be a positive integer" ;; esac

if [ ! -f "$ledger" ]; then
  echo "no dispatch ledger yet (would live at: $ledger)"; exit 0
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
skipped=0
while IFS= read -r l; do
  [ -z "$l" ] && continue
  if printf '%s' "$l" | jq -e . >/dev/null 2>&1; then printf '%s\n' "$l" >> "$tmp"
  else skipped=$((skipped+1)); fi
done < "$ledger"

jq -s -r --arg repo "$repo" --argjson top "$top" '
  map(select($repo == "" or .repo == $repo))
  | if length == 0 then
      "no entries" + (if $repo != "" then " for repo " + $repo else "" end)
    else
      "entries: \(length)   est_tokens total: \(map(.est_tokens // 0) | add)   span: \(first.ts) -> \(last.ts)",
      "",
      "by agent:",
      (group_by(.agent) | sort_by(-(map(.est_tokens // 0) | add))[]
        | "  \(.[0].agent)  n=\(length)  est_tokens=\(map(.est_tokens // 0) | add)  tokens=\((map(.tokens // empty) | add) // "-")"),
      "",
      "top \($top) by est_tokens:",
      (sort_by(-(.est_tokens // 0))[:$top][]
        | "  \(.ts)  \(.agent)  \(if .repo == "" then "-" else .repo end)  est=\(.est_tokens)  \(.desc)")
    end
' "$tmp" || die "ledger unreadable"
echo "ledger: $ledger"
[ "$skipped" -gt 0 ] && echo "$skipped unparseable line(s) skipped"
exit 0
