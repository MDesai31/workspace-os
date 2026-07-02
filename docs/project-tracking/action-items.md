# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260701-guardrail-engine — guardrail engine + provenance rules (hook-starter-library + provenance-guard)
- Workstream: workflow
- Status: open
- Created: 2026-07-01

One portable PreToolUse engine (`hooks/guardrail.sh`) applying declarative per-repo rules
(`.claude/guardrails.json`) to Bash + Edit/Write, emitting deny/warn. Folds `hook-starter-library`
and `provenance-guard` into one mechanism, two rule packs. Built-in defaults are warn-only (no
conflict with the global `guard.sh`); retires `hooks/memory-secret-guard.sh` into the engine.
Design: `docs/specs/2026-07-01-guardrail-engine-design.md`. Deferred: PostToolUse lint template,
`/guardrails` skill, `project-init` wiring.
