# Policy-Pack Conventions

The single source of truth for the pack format. `/guardrails pack` and
`scripts/pack-import.sh` follow these rules - they do not restate them.
Spec: `docs/specs/2026-08-28-policy-packs-design.md`.

## What a pack is

A versioned, machine-read bundle of guardrail rules + lint linters, shipped in this
plugin's `packs/<name>.json` (one distribution channel; the pack's version IS the plugin
version). Importing a pack is activation: the engines read the target configs directly, so
a landed pack enforces immediately.

## Format (`packs/<name>.json`)

- `name` (required, = filename stem), `description` (required).
- `guardrails` (required): `bash` / `write` arrays of the engine's exact rule shape
  (`name`, `match`, `action` deny|warn, `reason`, plus `field` content|path on write rules,
  plus an optional `predicate` - shell the engine runs in the call's cwd; the rule fires only
  when the regex matches AND the predicate exits 0). An optional `dispatch` array holds
  probe-first rules (`name`, `match` over a subagent dispatch's description + prompt, `probe`
  shell, `reason`; no action - always deny-once per session with the probe output).
- `lint` (optional): `linters` array of the lint engine's shape (`name`, `match`, `command`).
- `ip_class` (optional): set on import; announced by the skill before confirmation.
- `params` (optional): `[{name, prompt}]`. Rule strings may carry `{{name}}` placeholders;
  the `/guardrails` skill substitutes values conversationally BEFORE the import script runs
  (the script dies on any remaining `{{`). Params are policy data, never secret values.
- Validation: `scripts/validate-plugin.py` fails CI on a malformed pack (parse, required
  fields, params declared <-> placeholders used).

## Import semantics (`scripts/pack-import.sh`)

- Every imported rule/linter is stamped `"pack": "<name>"` (inert to the engines).
- `add` replaces only that pack's stamped rules - idempotent re-import; hand-authored
  rules are never touched. A `_packs` ledger in `guardrails.json` records
  `{name: {version, imported}}`.
- `remove` deletes the stamped rules + ledger entry from both configs but NEVER changes
  `ip_class` - it prints a review note instead (dropping a provenance boundary silently is
  worse than a stale one).
- Configs resolve exactly like the engines read them (sidecar data root, else
  `<git root>/.claude/`); missing configs are seeded from the templates on `add` only.
