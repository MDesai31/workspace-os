#!/usr/bin/env bash
# Plain-bash test harness for scripts/playbook-lint.sh (deps: bash + grep/sed).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/playbook-lint.sh"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }
check() { if [ "$2" = 0 ]; then ok "$1"; else bad "$1"; fi; }
contains() { printf '%s' "$1" | grep -qF -- "$2"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- fixtures ---------------------------------------------------------------
GOOD="$TMP/good"; mkdir -p "$GOOD"
cat > "$GOOD/clean-playbook.md" <<'EOF'
---
name: clean-playbook
description: a well-formed playbook
trigger-bash: sfq\.py
surface: before
---
# Clean
## Steps
EOF

BADDIR="$TMP/bad"; mkdir -p "$BADDIR"
cat > "$BADDIR/no-front.md" <<'EOF'
# Just a doc
no frontmatter at line 1
EOF
cat > "$BADDIR/unterminated.md" <<'EOF'
---
name: unterminated
description: block never closes
EOF
cat > "$BADDIR/missing-name.md" <<'EOF'
---
description: no name key
trigger-bash: foo
---
body
EOF
cat > "$BADDIR/missing-desc.md" <<'EOF'
---
name: missing-desc
trigger-bash: foo
---
body
EOF
cat > "$BADDIR/stem-mismatch.md" <<'EOF'
---
name: other-name
description: name does not equal stem
---
body
EOF
cat > "$BADDIR/bad-ere.md" <<'EOF'
---
name: bad-ere
description: invalid trigger regex
trigger-bash: [unclosed
---
body
EOF
cat > "$BADDIR/bad-surface.md" <<'EOF'
---
name: bad-surface
description: typo'd surface value
trigger-bash: foo
surface: befor
---
body
EOF

NOTES="$TMP/notes"; mkdir -p "$NOTES"
cat > "$NOTES/docs-only.md" <<'EOF'
---
name: docs-only
description: no triggers at all
---
body
EOF
{ printf -- '---\nname: long-body\ndescription: body over 300 lines\ntrigger-path: \\.ipynb$\n---\n'
  for i in $(seq 1 310); do echo "line $i"; done; } > "$NOTES/long-body.md"
cat > "$NOTES/README.md" <<'EOF'
# Playbooks
Scaffold README — not a playbook; must be ignored (it has no frontmatter).
EOF

EMPTY="$TMP/empty"; mkdir -p "$EMPTY"

# --- clean dir --------------------------------------------------------------
out="$(bash "$SCRIPT" "$GOOD" 2>&1)"; ec=$?
check "clean dir exits 0" $([ "$ec" = 0 ] && echo 0 || echo 1)
check "clean playbook PASSes" $(contains "$out" "PASS: clean-playbook" && echo 0 || echo 1)

# --- failure classes --------------------------------------------------------
out="$(bash "$SCRIPT" "$BADDIR" 2>&1)"; ec=$?
check "bad dir exits 1" $([ "$ec" = 1 ] && echo 0 || echo 1)
check "no frontmatter FAILs"    $(contains "$out" "FAIL: no-front" && echo 0 || echo 1)
check "unterminated FAILs"      $(contains "$out" "FAIL: unterminated" && echo 0 || echo 1)
check "missing name FAILs"      $(contains "$out" "FAIL: missing-name" && echo 0 || echo 1)
check "missing description FAILs" $(contains "$out" "FAIL: missing-desc" && echo 0 || echo 1)
check "stem mismatch FAILs"     $(contains "$out" "FAIL: stem-mismatch" && echo 0 || echo 1)
check "invalid ERE FAILs"       $(contains "$out" "FAIL: bad-ere" && echo 0 || echo 1)
check "invalid surface FAILs"   $(contains "$out" "FAIL: bad-surface" && echo 0 || echo 1)

# --- notes (non-fatal) ------------------------------------------------------
out="$(bash "$SCRIPT" "$NOTES" 2>&1)"; ec=$?
check "notes-only dir exits 0" $([ "$ec" = 0 ] && echo 0 || echo 1)
check "docs-only PASSes with note" $(contains "$out" "NOTE: docs-only" && echo 0 || echo 1)
check "long body noted"            $(contains "$out" "NOTE: long-body" && echo 0 || echo 1)
check "README ignored" $(contains "$out" "README" && echo 1 || echo 0)

# --- empty / missing dirs ---------------------------------------------------
out="$(bash "$SCRIPT" "$EMPTY" 2>&1)"; ec=$?
check "empty dir exits 0" $([ "$ec" = 0 ] && echo 0 || echo 1)
out="$(bash "$SCRIPT" "$TMP/nonexistent" 2>&1)"; ec=$?
check "missing dir exits 0" $([ "$ec" = 0 ] && echo 0 || echo 1)

# --- multiple dirs: failure anywhere fails the run ---------------------------
out="$(bash "$SCRIPT" "$GOOD" "$BADDIR" 2>&1)"; ec=$?
check "two dirs, bad second: exits 1" $([ "$ec" = 1 ] && echo 0 || echo 1)
check "two dirs: clean one still PASSes" $(contains "$out" "PASS: clean-playbook" && echo 0 || echo 1)

# --- no args is a usage error ------------------------------------------------
bash "$SCRIPT" >/dev/null 2>&1; ec=$?
check "no args exits nonzero" $([ "$ec" != 0 ] && echo 0 || echo 1)

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ] || exit 1
