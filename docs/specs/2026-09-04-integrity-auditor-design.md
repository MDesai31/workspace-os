# Integrity auditor (Tier 0) — design

Date: 2026-09-04. Status: approved (user picked it off the brief 2026-09-04). Ships the
deterministic half of the integrity-auditor idea (brainstorm 2026-06-28); the dormant
cloud-cron LLM tiers remain as that idea's open slice.

## Problem

The append-`merge=union` tracking files silently lose or duplicate entries on bad merges and
on bad move scripts. The evidence is one hour old: the v0.35.0 close-out commit (d526ca0)
truncated `resolved.md` from 42 records to 1 because a script opened the file for writing
before reading it. A `wc -l` was printed and not gated; the commit and push went through.
`memory_graph.py` already lints the memory side (index parity, wikilinks) and the
memory/tracking boundary (`--check-tracking`), but nothing checks the tracking files' own
integrity, and nothing stands between a bad tracking edit and `git commit`.

## Design

### 1. `memory_graph.py --audit-tracking [--baseline REF]`

A new flag beside `--check-tracking`, over one or more `--tracking-root`s, exit 1 on any FAIL.

| check | severity | what |
|---|---|---|
| duplicate record ID | FAIL | the same `A-`/`D-`/`F-` heading appears twice across all files in the tree (a record left in `action-items.md` after being copied to `resolved.md`; union-merge duplication) |
| invalid ID date | FAIL | the `YYYYMMDD` in a heading is not a calendar date |
| dangling record reference | FAIL | a record-ID token anywhere in the tree (`Spawns:`, `Supersedes:`, `Superseded-by:`, prose) with no heading in the tree |
| placeholder beside records | FAIL | an italic empty-state line (`_No … yet._`) in a file that also holds a record |
| append-only shrink | FAIL | vs `--baseline` (default `HEAD`): `resolved.md` and `decisions-log.md` record counts must not drop, and the total across `action-items.md` + `resolved.md` + `findings.md` must not drop (a done-move keeps it constant; a truncation lowers it) |
| duplicate non-trivial line | WARN | a line ≥ 40 chars, not a boilerplate field line, appearing more than once in one file — union-merge artifacts for a human to judge |

Baseline semantics: the tracking root's git repo is found with `git -C <root> rev-parse
--show-toplevel`; each file is read at `<ref>:<relpath>`. Not a git repo, or a file absent at
the baseline (new repo, first record) → one NOTE line, no failure. Legacy `#`/letter IDs are
outside the regex and never counted or flagged.

Rejected: a separate `tracking-audit.sh` (the record iterator, ID regex, and tracking-root
plumbing already live in `memory_graph.py`; `/memory-lint` already runs it). Folding into
`--check-tracking` (its tests pin exact behaviour; the boundary check and the integrity audit
answer different questions and deserve separate exit codes).

### 2. Engine: `WORKSPACE_OS_PLUGIN_ROOT`

`hooks/guardrail.sh` exports `WORKSPACE_OS_PLUGIN_ROOT` (its own resolved plugin directory)
before running predicates and probes, so a rule can locate plugin scripts without hardcoding a
cache path. One line; documented in the skill's drafting guidance and the template comment.

### 3. Wiring

- `/memory-lint` step 1b runs the audit alongside the boundary check.
- `docs/playbooks/ship-a-slice.md` close-out: run the audit as a **gate** before the tracking
  commit (replacing "check `wc -l`" folklore with an exit code).
- `.github/workflows/ci.yml`: `python3 scripts/memory_graph.py --audit-tracking
  --tracking-root docs/project-tracking` on this repo's own tracking.
- This repo's first own `.claude/guardrails.json`: a bash `deny` on `git[[:space:]]+commit`
  whose predicate runs the audit and fires on failure — authored through
  `guardrails-upsert.sh`, dry-run both directions. Today's truncation, replayed: resolved.md
  42 → 1 vs HEAD ⇒ audit exit 1 ⇒ predicate exit 0 ⇒ commit denied.

### 4. Tests

`tests/test-memory-graph.sh`: a fixture tree (`tests/fixtures/tracking-audit/`) exercising each
FAIL and the WARN, with the expected IDs named in the output; the clean fixture passes; a temp
git repo with a committed baseline where (a) truncating `resolved.md` FAILs, (b) moving a record
from `action-items.md` to `resolved.md` PASSes, (c) `--baseline` pointing at a ref works, and
(d) a non-git root prints the NOTE and exits 0. `tests/test-guardrail.sh`: a predicate testing
`[ -f "$WORKSPACE_OS_PLUGIN_ROOT/hooks/guardrail.sh" ]` fires.

### 5. Docs and records

`conventions/project-tracking.md` gains an "Integrity audit" section (the SoT for the checks;
the skill and playbook point at it). GUIDE's maintenance section gains a line. Version 0.36.0.
The idea stays open with a Shipped line naming the cloud-tier remainder.

### Out of scope

Memory-side checks (already in `--check`), path-existence (memory-lint-hardening), any LLM tier,
auto-fixing anything.

## Verification

Suite green locally and in CI; validator clean; `memory_graph: clean`; the new commit gate
proven by dry-run AND by the close-out commit passing through it.
