# CLAUDE.md

Claude Code plugin (the engine) operating on a per-repo data layer. Source of truth:
`ARCHITECTURE.md` (layers) and `conventions/` (tracking, memory, data-root rules — skills
follow these and never restate them).

## Commands

- Full test suite (plain bash + jq, no framework): `for t in tests/test-*.sh; do bash "$t"; done`
- Plugin manifest check: `python3 scripts/validate-plugin.py`
- CI (`.github/workflows/ci.yml`) runs the validator plus every `tests/test-*.sh` — keep new test scripts listed there.

## Workflow

- Feature flow: plan in `docs/plans/`, design in `docs/specs/` (`YYYY-MM-DD-<slug>[-design].md`),
  and dogfood `docs/project-tracking/` at each step, not batched at the end.
- Bump `version` in `.claude-plugin/plugin.json` on user-visible changes.
- After merge to main: pull this checkout, then `claude plugin update workspace-os@workspace-os`.

## Gotchas

- Hooks (`guardrail.sh`, `lint.sh`) fail open by design — a missing config is silence, not an error.
- Data paths are resolved, never assumed: everything routes through `scripts/resolve-data-root.sh`.

@docs/memory/MEMORY.md
