#!/usr/bin/env bash
# workspace-os playbook lint - deterministic checks over playbook dirs.
# The surfacing hook (hooks/playbook-surface.sh) fails OPEN, so a malformed playbook is
# silent non-surfacing; this script is the fail-LOUD counterpart, and it parses the exact
# same dialect the hook does (flat frontmatter via sed, triggers via grep -E) so that
# lint-clean implies hook-parseable. Rules: conventions/playbooks.md.
#
# Usage: playbook-lint.sh <playbooks-dir> [<playbooks-dir>...]
# Exit 1 iff any FAIL; NOTEs are non-fatal. A missing or empty dir is a note, not an error.
set -uo pipefail

[ "$#" -ge 1 ] || { echo "usage: $(basename "$0") <playbooks-dir> [<playbooks-dir>...]" >&2; exit 64; }

fails=0

# Same parsing as the hook.
front() { awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---$/{exit} {print}' "$1" 2>/dev/null; }
fval()  { printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

# ere_ok <pattern> -> 0 if grep -E accepts it (exit 2 from grep = bad pattern)
ere_ok() { printf '' | grep -qE -- "$1" 2>/dev/null; [ "$?" -ne 2 ]; }

for d in "$@"; do
  if [ ! -d "$d" ]; then echo "note: $d - no such dir, skipped"; continue; fi
  found=0
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    slug="$(basename "$f" .md)"
    [ "$slug" = "README" ] && continue
    found=1
    file_fails=0
    fm="$(front "$f")"

    if [ "$(head -1 "$f")" != "---" ]; then
      echo "FAIL: $slug - no frontmatter at line 1 (the hook skips this file entirely)"
      file_fails=1
    elif [ "$(grep -c '^---$' "$f")" -lt 2 ]; then
      echo "FAIL: $slug - unterminated frontmatter (the hook mis-parses: whole file becomes frontmatter, body empty)"
      file_fails=1
    else
      name="$(fval "$fm" name)"
      desc="$(fval "$fm" description)"
      tb="$(fval "$fm" trigger-bash)"
      tp="$(fval "$fm" trigger-path)"
      sf="$(fval "$fm" surface)"

      [ -n "$name" ] || { echo "FAIL: $slug - missing 'name'"; file_fails=1; }
      [ -n "$desc" ] || { echo "FAIL: $slug - missing 'description'"; file_fails=1; }
      if [ -n "$name" ] && [ "$name" != "$slug" ]; then
        echo "FAIL: $slug - name '$name' != filename stem"
        file_fails=1
      fi
      if [ -n "$tb" ] && ! ere_ok "$tb"; then
        echo "FAIL: $slug - trigger-bash is not a valid ERE (the trigger silently never matches)"
        file_fails=1
      fi
      if [ -n "$tp" ] && ! ere_ok "$tp"; then
        echo "FAIL: $slug - trigger-path is not a valid ERE (the trigger silently never matches)"
        file_fails=1
      fi
      if [ -n "$sf" ] && [ "$sf" != "before" ] && [ "$sf" != "after" ]; then
        echo "FAIL: $slug - surface '$sf' is not before|after (the hook silently coerces it to 'before')"
        file_fails=1
      fi

      if [ "$file_fails" = 0 ]; then
        echo "PASS: $slug"
        if [ -z "$tb" ] && [ -z "$tp" ]; then
          echo "NOTE: $slug - no trigger; docs-only (listable, never auto-surfaced)"
        fi
        body_lines="$(awk 'c>=2{print} /^---$/{c++}' "$f" | wc -l)"
        if [ "$body_lines" -gt 300 ]; then
          echo "NOTE: $slug - body $body_lines lines (>300: surfaces as a read-path instruction, not inline)"
        fi
      fi
    fi
    [ "$file_fails" = 0 ] || fails=$((fails + file_fails))
  done
  [ "$found" = 1 ] || echo "note: $d - no playbooks"
done

if [ "$fails" -gt 0 ]; then echo "playbook-lint: FAIL ($fails file(s))"; exit 1; fi
echo "playbook-lint: clean"
