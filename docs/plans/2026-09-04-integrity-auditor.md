# Integrity auditor (Tier 0) — plan

Spec: `docs/specs/2026-09-04-integrity-auditor-design.md`. Branch `feat/integrity-auditor`.

1. **Fixture + tests** — `tests/fixtures/tracking-audit/` with one offender per check; append
   `--audit-tracking` cases (fixture, clean, git-baseline temp repo) to
   `tests/test-memory-graph.sh`; red.
2. **Audit** — `audit_tracking()` + `print_audit()` + `--audit-tracking`/`--baseline` in
   `scripts/memory_graph.py`. Green.
3. **Engine** — export `WORKSPACE_OS_PLUGIN_ROOT`; predicate test in `tests/test-guardrail.sh`.
4. **Wiring** — `/memory-lint` 1b, ship-a-slice close-out gate, CI step, this repo's
   `.claude/guardrails.json` via the upsert CLI (dry-run both directions).
5. **Docs** — conventions § Integrity audit, GUIDE line, template comment, skill note.
6. **Version** 0.36.0; validator + full suite.
7. **Ship** — PR, foreground checks, merge, close-out (audit gate before the tracking commit).
