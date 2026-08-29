# Playbook follow-ups — implementation plan

Spec: `docs/specs/2026-08-29-playbook-followups-design.md`. Version target: v0.28.0.
Branch: `feat/playbook-followups`. Inline execution.

## Task 1 — playbook-lint.sh (TDD)

1. Commit spec + this plan on the branch.
2. Write `tests/test-playbook-lint.sh` (house style: tmpdir fixtures, ok/bad helpers,
   PASS/FAIL lines, nonzero exit on failure). Cases:
   - clean playbook (name=stem, description, valid trigger-bash ERE, surface: before) → PASS
   - no frontmatter at line 1 → FAIL
   - unterminated frontmatter → FAIL
   - missing name / missing description / name ≠ stem → FAIL each
   - invalid ERE in trigger-bash (`[unclosed`) → FAIL
   - invalid surface value (`befor`) → FAIL
   - docs-only (no triggers) → PASS with NOTE
   - body > 300 lines → PASS with NOTE
   - README.md in dir → ignored
   - missing dir / empty dir → exit 0, one-line note
   - two dirs, failure in second → exit 1
   Run: red (script absent).
3. Write `scripts/playbook-lint.sh`; run test: green.
4. Add the test to `.github/workflows/ci.yml`.

## Task 2 — init stamp + skill wiring

1. `templates/playbooks/README.md` (short; SoT pointer + /playbook pointer).
2. `skills/project-init/SKILL.md`: step 3 stamps `playbooks/` + README (skip if exists);
   step 7 report mentions `/playbook`.
3. `skills/memory-lint/SKILL.md`: Step 1c runs playbook-lint on repo tier (+ workspace tier
   in sidecar); merged report includes it.

## Task 3 — docs, version, ship

1. GUIDE.md: playbook-lint mention in Maintenance section + `/project-init` setup list line;
   README feature map row for `/memory-lint` mentions playbooks. plugin.json → 0.28.0.
2. Full test suite + validator; PR; green CI (sleep 10 before watch); squash-merge;
   pull main; `claude plugin update workspace-os@workspace-os`.
3. Tracking close-out: resolve the action record; ship-close the procedure-playbooks idea
   (UDX adoption noted as usage on the EC2 machine, not plugin work); memory_graph check.
