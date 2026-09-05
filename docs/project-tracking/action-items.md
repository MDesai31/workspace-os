# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260904-retire-advisory-lint — remove the advisory lint hook, config, template, tests, and pack support
- Workstream: workflow
- Status: open
- Created: 2026-09-04

Executes D-20260904-retire-advisory-lint. Spec `docs/specs/2026-09-04-lint-retirement-decision.md`.
Deletes `hooks/lint.sh`, `templates/lint.json`, `tests/test-lint.sh`, the fake-linter fixture,
the hooks.json entry, the CI step, and pack `lint` support (import script + tests + both
packs + packs.md); the validator rejects a `lint` key as retired; docs updated (README, GUIDE,
ARCHITECTURE, CLAUDE.md, /guardrails pack wording). v0.37.0.
