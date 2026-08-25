# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260824-guardrail-conversational-authoring — /guardrails: conversational guardrail rule authoring
- Workstream: workflow
- Status: open
- Created: 2026-08-24

Promotes the guardrail-conversational-authoring idea (EC2 audit 2026-08-24). Ships
`scripts/guardrails-upsert.sh` (deterministic add/remove/list over the resolved guardrails.json —
fail-loud, atomic, jq-dialect regex validation, sidecar-aware), the `/guardrails` skill
(elicit → route → draft → dry-run through `hooks/guardrail.sh` → propose-confirm → apply), a
capture-cadence nudge line, and `tests/test-guardrails-upsert.sh`. Spec:
`docs/specs/2026-08-24-guardrail-conversational-authoring-design.md`.
