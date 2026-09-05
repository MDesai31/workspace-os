# Stateful guardrail predicates — plan

Spec: `docs/specs/2026-09-04-stateful-guardrail-predicates-design.md`. Branch
`feat/stateful-guardrail-predicates`. Each step is red-then-green where a test exists.

1. **Engine tests first** — append the predicate cases to `tests/test-guardrail.sh`; run,
   confirm they fail (the engine ignores the field today).
2. **Engine** — `hooks/guardrail.sh`: read `.cwd` from stdin JSON; jq emits
   `action\treason\tpredicate`; a `run_predicate` helper (timeout 5, cwd, output discarded);
   loop skips rows whose predicate does not exit 0. Suite green.
3. **CLI tests** — append `--predicate` cases to `tests/test-guardrails-upsert.sh`; red.
4. **CLI** — `scripts/guardrails-upsert.sh`: `--predicate` arg, non-empty check, stored via
   the same jq builder, `list` column. Green.
5. **Skill + conventions + template + GUIDE** — routing flip, drafting guidance, three-case
   dry-run, packs.md line, template comment + example, GUIDE bullet.
6. **Version** — `.claude-plugin/plugin.json` → 0.34.0.
7. **Verify** — `python3 scripts/validate-plugin.py`; `for t in tests/test-*.sh; do bash "$t"; done`.
8. **PR** — push, open the PR, watch checks once in the foreground, merge on green, then the
   ship-a-slice close-out.
