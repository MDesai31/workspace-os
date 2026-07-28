#!/usr/bin/env bash
# Plain-bash tests for scripts/claude-md-upsert.sh (deps: bash + coreutils only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/claude-md-upsert.sh"
SECTION="## Stale priors (training vs reality)"
BULLET="- Prisma import: use @/generated/prisma/client, NOT @prisma/client (training prior is wrong here)."
pass=0; fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

assert() { # assert "<name>" <exit-code-of-preceding-test>
  if [ "$2" -eq 0 ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}
contains() { case "$(cat "$1")" in *"$2"*) return 0;; *) return 1;; esac; }

# case 1: section absent -> created
f="$TMP/a.md"; printf '# Project\n\nSome intro.\n' > "$f"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "absent: exit 0" $?
[ "$out" = "created section" ]; assert "absent: says created" $?
contains "$f" "$SECTION"; assert "absent: heading present" $?
contains "$f" "$BULLET"; assert "absent: bullet present" $?

# case 2: section present -> appended under it (before the next heading)
f="$TMP/b.md"
printf '# P\n\n%s\n- existing: use B, NOT A (training prior is wrong here).\n\n## After\ntail\n' "$SECTION" > "$f"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "present: exit 0" $?
[ "$out" = "appended" ]; assert "present: says appended" $?
awk -v b="$BULLET" -v a="## After" 'index($0,b){bi=NR} index($0,a){ai=NR} END{exit !(bi>0 && ai>0 && bi<ai)}' "$f"
assert "present: bullet sits under section (before ## After)" $?

# case 3: exact duplicate -> skipped, file unchanged
f="$TMP/c.md"; printf '# P\n\n%s\n%s\n' "$SECTION" "$BULLET" > "$f"; before="$(cat "$f")"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "dup: exit 0" $?
case "$out" in skipped*) true;; *) false;; esac; assert "dup: says skipped" $?
[ "$before" = "$(cat "$f")" ]; assert "dup: file unchanged" $?

# case 4: trailing @import -> section inserted before it, import still last non-blank
f="$TMP/d.md"; printf '# P\n\nintro\n\n@docs/memory/MEMORY.md\n' > "$f"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "import: exit 0" $?
awk -v h="$SECTION" '$0==h{hi=NR} /^@/{imp=NR} END{exit !(hi>0 && imp>0 && hi<imp)}' "$f"
assert "import: heading before @import line" $?
last="$(awk 'NF{l=$0} END{print l}' "$f")"; case "$last" in @*) true;; *) false;; esac
assert "import: @import still last non-blank" $?

# case 5: missing file -> nonzero, nothing created
out="$(bash "$SCRIPT" "$TMP/nope.md" "$SECTION" "$BULLET" 2>/dev/null)"; ec=$?
[ "$ec" != 0 ]; assert "missing: nonzero exit" $?
[ ! -f "$TMP/nope.md" ]; assert "missing: file not created" $?

# case 6: bad args -> exit 2
bash "$SCRIPT" "$TMP/a.md" "$SECTION" >/dev/null 2>&1; [ "$?" = 2 ]; assert "badargs: exit 2" $?

# case 7: unrelated content preserved
f="$TMP/g.md"; printf '# P\n\nSENTINEL-XYZ\n\n@a.md\n' > "$f"
bash "$SCRIPT" "$f" "$SECTION" "$BULLET" >/dev/null
contains "$f" "SENTINEL-XYZ"; assert "preserve: sentinel intact" $?

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
