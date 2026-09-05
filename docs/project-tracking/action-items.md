# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.


### A-20260904-stateful-guardrail-predicates — `predicate` field on guardrail rules: state tests, not just text
- Workstream: workflow
- Status: open
- Created: 2026-09-04

Graduates the stateful-guardrail-predicates idea. Spec
`docs/specs/2026-09-04-stateful-guardrail-predicates-design.md`, plan
`docs/plans/2026-09-04-stateful-guardrail-predicates.md`. An optional `predicate` shell string
on any bash/write rule: fires when the regex matches AND the predicate exits 0, run in the
call's cwd under a 5-second timeout, fail open on anything else, no caching. Touches the
engine, the upsert CLI, the /guardrails skill routing (state-dependent hazards become
engine-fit), packs.md, the template, GUIDE, and both test suites. v0.34.0.
Decision: D-20260904-predicate-exit0-fires-fail-open.
