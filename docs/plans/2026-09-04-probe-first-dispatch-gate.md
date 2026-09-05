# Probe-first dispatch gate — plan

Spec: `docs/specs/2026-09-04-probe-first-dispatch-gate-design.md`. Branch
`feat/probe-first-dispatch-gate`. Red-then-green at each step.

1. **Engine tests** — append the dispatch cases to `tests/test-guardrail.sh`; red.
2. **Engine + wiring** — `hooks/guardrail.sh` Task|Agent case (marker-first deny-once, probe
   under `timeout 10`, 4000-char cap); `hooks/hooks.json` PreToolUse `Task|Agent` entry. Green.
3. **CLI tests** — `--type dispatch` cases in `tests/test-guardrails-upsert.sh`; red.
4. **CLI** — `--probe`, type-specific arg validation, list column. Green.
5. **Packs** — `pack-import.sh` handles `dispatch`; `validate-plugin.py` checks dispatch rule
   fields; `test-pack-import.sh` dispatch case.
6. **Skill + conventions + template + docs** — dispatch-fit route, three-call dry-run,
   packs.md, template, GUIDE, README, ledger-spec pointer.
7. **Version** — 0.35.0. **Verify** — validator + full suite.
8. **Ship** — PR, foreground checks, merge on green, ship-a-slice close-out.
