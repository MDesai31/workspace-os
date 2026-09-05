# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260904-probe-first-dispatch-gate — `dispatch` guardrail rules: probe once per session before an expensive dispatch
- Workstream: workflow
- Status: open
- Created: 2026-09-04

Graduates the probe-first-dispatch-gate idea. Spec
`docs/specs/2026-09-04-probe-first-dispatch-gate-design.md`, plan
`docs/plans/2026-09-04-probe-first-dispatch-gate.md`. A third rule array in `guardrails.json`,
`dispatch` (`name`, `match`, `probe`, `reason`), enforced by the guardrail engine on a new
PreToolUse `Task|Agent` surface via playbook-surface's deny-once pattern: first matching
dispatch per session per rule runs the probe (call cwd, 10s, 4000-char cap) and denies with the
output on stderr; the retry passes. Reuses the upsert CLI, /guardrails authoring + dry-run,
packs. v0.35.0. Decision: D-20260904-dispatch-gate-deny-once-not-predicate.
