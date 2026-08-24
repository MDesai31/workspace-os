#!/usr/bin/env bash
# Plain-bash test harness for scripts/memory_graph.py (deps: bash + python3 only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/memory_graph.py"
CLEAN="$HERE/fixtures/memory-clean"
BROKEN="$HERE/fixtures/memory-broken"
pass=0; fail=0

# run_check <fixture_root> -> sets globals ec (exit code) and out (combined output)
run_check() {
  local fx="$1"
  out="$(python3 "$SCRIPT" --check --root "$fx/docs/memory" \
        --tracking-root "$fx/docs/project-tracking" 2>&1)"; ec=$?
}

# check <name> <got_ec> <want_ec> <got_out> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec out=[$got_out])"; fail=$((fail+1)); fi
}

# --- clean tree: resolves wikilinks (incl. typed + D- record), index in parity ---
run_check "$CLEAN"
check "clean tree passes --check" "$ec" "0" "$out" "clean"

# --- broken tree: broken link + unindexed file + dangling entry all fail + are named ---
run_check "$BROKEN"
check "broken tree fails --check" "$ec" "1" "$out" ""
check "broken wikilink is named" "$ec" "1" "$out" "missing_note"
check "unindexed file is named" "$ec" "1" "$out" "unindexed_fact"
check "dangling index entry is named" "$ec" "1" "$out" "gone"

# --- report mode: typed edge counted; code-fence/inline links NOT counted ---
report="$(python3 "$SCRIPT" --root "$CLEAN/docs/memory" --tracking-root "$CLEAN/docs/project-tracking" 2>&1)"
case "$report" in *"supersedes: 1"*) echo "PASS: typed edge reported"; pass=$((pass+1));;
  *) echo "FAIL: typed edge missing from report"; fail=$((fail+1));; esac
case "$report" in *"not_a_real_link"*|*"also_not_a_link"*)
  echo "FAIL: code-span/fence link counted as an edge"; fail=$((fail+1));;
  *) echo "PASS: code-span/fence links ignored"; pass=$((pass+1));; esac
case "$report" in *"BROKEN LINKS (0)"*) echo "PASS: clean report has zero broken"; pass=$((pass+1));;
  *) echo "FAIL: clean report shows broken links"; fail=$((fail+1));; esac

# --- missing tracking root fails open (D- link becomes broken, but no crash) ---
out="$(python3 "$SCRIPT" --check --root "$CLEAN/docs/memory" --tracking-root "$CLEAN/nonexistent" 2>&1)"; ec=$?
check "missing tracking root = no crash, D- link now broken" "$ec" "1" "$out" "d_20260101_fixture_decision"

# --- two-tier (sidecar): --link-root resolves cross-tier wikilinks ---
TWO="$HERE/fixtures/memory-two-tier"
out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" 2>&1)"; ec=$?
check "cross-tier link WITHOUT --link-root is broken" "$ec" "1" "$out" "shared_data_contract"

out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" \
      --link-root "$TWO/workspace/memory" 2>&1)"; ec=$?
check "cross-tier link WITH --link-root resolves" "$ec" "0" "$out" "clean"

out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" \
      --link-root "$TWO/nonexistent" 2>&1)"; ec=$?
check "missing --link-root dir fails open (link broken, no crash)" "$ec" "1" "$out" "shared_data_contract"

# --- search mode: name/description substring, case-insensitive, empty result = exit 0 ---
out="$(python3 "$SCRIPT" --search "second fixture" --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "search finds fact by description" "$ec" "0" "$out" "fact-b"

out="$(python3 "$SCRIPT" --search "FIRST FIXTURE" --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "search is case-insensitive" "$ec" "0" "$out" "fact-a"

out="$(python3 "$SCRIPT" --search "zzz-no-such-term" --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "search no-match is MATCHES (0), exit 0" "$ec" "0" "$out" "MATCHES (0)"

# the MEMORY.md index file is not a fact: a name-match on it must NOT surface as a hit
out="$(python3 "$SCRIPT" --search memory --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
case "$out" in *MEMORY*) echo "FAIL: --search returns the MEMORY.md index as a hit"; fail=$((fail+1));;
  *) echo "PASS: --search excludes the MEMORY.md index"; pass=$((pass+1));; esac

# --- backlinks mode: typed LINKS OUT + a BACKLINK both appear; unknown node = no crash ---
out="$(python3 "$SCRIPT" --backlinks fact-a --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "backlinks shows typed LINKS OUT" "$ec" "0" "$out" "supersedes -> fact-b"
check "backlinks shows BACKLINK source" "$ec" "0" "$out" "fact-b (related)"

out="$(python3 "$SCRIPT" --backlinks no-such-fact --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "backlinks unknown node = no crash, exit 0" "$ec" "0" "$out" "no such fact"

# --- citation lint: block-containment, symbol anchors, unresolvable/unanchored ---
CIT="$HERE/fixtures/memory-citations"
out="$(python3 "$SCRIPT" --check-citations --root "$CIT/docs/memory" --src-root "$CIT" 2>&1)"; ec=$?
check "citation lint fails on stale citations" "$ec" "1" "$out" ""
check "stale line-number citation is named" "$ec" "1" "$out" "fact-stale-line"
check "vanished symbol anchor is named" "$ec" "1" "$out" "fact-anchor-gone"
check "unresolvable citation reported (not stale)" "$ec" "1" "$out" "fact-unresolvable"
check "unanchored citation reported (not stale)" "$ec" "1" "$out" "fact-unanchored"
# false-positive guard: a correct citation to a line INSIDE the symbol block must never be named
case "$out" in *fact-good-inblock*) echo "FAIL: in-block citation wrongly flagged"; fail=$((fail+1));;
  *) echo "PASS: in-block citation not flagged"; pass=$((pass+1));; esac
# a symbol-anchor whose symbol still exists must never be named
case "$out" in *fact-anchor-present*) echo "FAIL: live symbol anchor wrongly flagged"; fail=$((fail+1));;
  *) echo "PASS: live symbol anchor not flagged"; pass=$((pass+1));; esac
# real-base regression: a nearby backticked NON-definition token (an import/exception/literal)
# must not make a valid line citation STALE -- only true symbol defs are checkable. Exactly two
# genuine stales remain (fact-stale-line, fact-anchor-gone).
check "nearby non-definition token is not stale" "$ec" "1" "$out" "stale: 2"
# real-base regression: a bare basename matching multiple files is AMBIGUOUS, not STALE
# (duplicate basenames are ubiquitous; an arbitrary pick would false-positive).
check "ambiguous basename is reported" "$ec" "1" "$out" "AMBIGUOUS"
check "ambiguous fact is named, not stale" "$ec" "1" "$out" "fact-ambiguous"

# no citations anywhere = clean, exit 0
out="$(python3 "$SCRIPT" --check-citations --root "$CLEAN/docs/memory" --src-root "$CLEAN" 2>&1)"; ec=$?
check "no citations = clean, exit 0" "$ec" "0" "$out" ""

# --src-root is required for the citation lint
out="$(python3 "$SCRIPT" --check-citations --root "$CIT/docs/memory" 2>&1)"; ec=$?
check "citation lint without --src-root errors (exit 2)" "$ec" "2" "$out" "src-root"

# --- tracking boundary lint: oversized bodies + MEASURED blocks ---
TB="$HERE/fixtures/tracking-boundary"
out="$(python3 "$SCRIPT" --check-tracking --tracking-root "$TB/docs/project-tracking" 2>&1)"; ec=$?
check "tracking boundary lint fails on violations" "$ec" "1" "$out" ""
check "oversized record is named" "$ec" "1" "$out" "A-20260102-huge"
check "MEASURED-block record is named" "$ec" "1" "$out" "A-20260103-measured"
case "$out" in *A-20260101-small*) echo "FAIL: well-scoped record wrongly flagged"; fail=$((fail+1));;
  *) echo "PASS: well-scoped record not flagged"; pass=$((pass+1));; esac
# a record that only MENTIONS the marker in inline code must not be flagged (dogfood regression)
case "$out" in *A-20260104-mention*) echo "FAIL: prose mention of the marker wrongly flagged"; fail=$((fail+1));;
  *) echo "PASS: prose mention of the marker not flagged"; pass=$((pass+1));; esac

# --max-record-lines raises the size threshold; MEASURED stays independent of size
out="$(python3 "$SCRIPT" --check-tracking --tracking-root "$TB/docs/project-tracking" --max-record-lines 100 2>&1)"; ec=$?
check "raised threshold still catches MEASURED" "$ec" "1" "$out" "A-20260103-measured"
case "$out" in *A-20260102-huge*) echo "FAIL: oversized record flagged despite raised threshold"; fail=$((fail+1));;
  *) echo "PASS: raised threshold clears the oversized record"; pass=$((pass+1));; esac

# clean tracking tree = exit 0
out="$(python3 "$SCRIPT" --check-tracking --tracking-root "$CLEAN/docs/project-tracking" 2>&1)"; ec=$?
check "clean tracking = exit 0" "$ec" "0" "$out" ""

# --- applies-to: parsed and surfaced, never a gate ---
SCOPED="$HERE/fixtures/memory-scoped"
out="$(python3 "$SCRIPT" --root "$SCOPED/docs/memory" --tracking-root "$SCOPED/none" 2>&1)"; ec=$?
check "applies-to is reported" "$ec" "0" "$out" "branch:develop"
# the report prints norm stems (hyphens folded to underscores) like every other section
check "applies-to names the scoped fact" "$ec" "0" "$out" "fact_scoped"
out="$(python3 "$SCRIPT" --check --root "$SCOPED/docs/memory" --tracking-root "$SCOPED/none" 2>&1)"; ec=$?
check "applies-to does not fail --check" "$ec" "0" "$out" ""

# --- verified-against: UNVERIFIED-SINCE when cited code moved after the recorded sha ---
GT="$(mktemp -d)"; mkdir -p "$GT/docs/memory" "$GT/src"
cat > "$GT/src/opt.py" <<'EOF'
def prune_prepare_inputs(rows):
    return rows
EOF
git -C "$GT" init -q
git -C "$GT" config user.email t@t.t; git -C "$GT" config user.name t
git -C "$GT" add -A >/dev/null; git -C "$GT" commit -qm one
OLD_SHA="$(git -C "$GT" rev-parse --short HEAD)"
cat > "$GT/src/opt.py" <<'EOF'
def prune_prepare_inputs(rows, limit):
    return rows[:limit]
EOF
git -C "$GT" add -A >/dev/null; git -C "$GT" commit -qm two
NEW_SHA="$(git -C "$GT" rev-parse --short HEAD)"

write_fact() {  # $1=sha
  cat > "$GT/docs/memory/fact-verified.md" <<EOF
---
name: fact-verified
description: cites a symbol that still resolves
type: domain
verified-against: $1 2026-08-19
---

Entry point: \`src/opt.py::prune_prepare_inputs\`.
EOF
  printf '# Memory Index\n\n## domain\n- [fact-verified](fact-verified.md) - x\n' \
    > "$GT/docs/memory/MEMORY.md"
}

write_fact "$OLD_SHA"
out="$(python3 "$SCRIPT" --check-citations --root "$GT/docs/memory" --src-root "$GT" 2>&1)"; ec=$?
check "stale sha reports UNVERIFIED-SINCE" "$ec" "0" "$out" "UNVERIFIED-SINCE"
check "unverified fact is named" "$ec" "0" "$out" "fact-verified"
check "UNVERIFIED-SINCE does not fail the lint" "$ec" "0" "$out" "citations: clean"

write_fact "$NEW_SHA"
out="$(python3 "$SCRIPT" --check-citations --root "$GT/docs/memory" --src-root "$GT" 2>&1)"; ec=$?
case "$out" in *UNVERIFIED-SINCE*) echo "FAIL: current sha wrongly flagged"; fail=$((fail+1));;
  *) echo "PASS: current sha not flagged"; pass=$((pass+1));; esac
rm -rf "$GT"

# --- provenance fields: the two schema statements must agree ---
CONV="$HERE/../conventions/memory.md"
MANUAL="$HERE/../templates/memory/README.md"
for field in "verified-against" "applies-to"; do
  c=$(grep -c -- "$field" "$CONV"); m=$(grep -c -- "$field" "$MANUAL")
  if [ "$c" -gt 0 ] && [ "$m" -gt 0 ]; then
    echo "PASS: $field documented in both schema statements"; pass=$((pass+1))
  else
    echo "FAIL: $field missing (conventions:$c manual:$m)"; fail=$((fail+1))
  fi
done

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
