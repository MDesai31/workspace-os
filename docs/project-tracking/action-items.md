# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260904-integrity-auditor — Tier 0 tracking integrity audit + a commit gate on this repo
- Workstream: workflow
- Status: open
- Created: 2026-09-04

Ships the deterministic half of the integrity-auditor idea. Spec
`docs/specs/2026-09-04-integrity-auditor-design.md`, plan
`docs/plans/2026-09-04-integrity-auditor.md`. `memory_graph.py --audit-tracking`: duplicate
IDs, invalid ID dates, dangling record references, placeholder-beside-records, append-only
shrink vs a git baseline (FAILs) and duplicate non-trivial lines (WARN). Wired into
/memory-lint, the ship-a-slice close-out, CI, and this repo's first own guardrails.json — a
predicate-gated deny on `git commit`. Engine exports WORKSPACE_OS_PLUGIN_ROOT to
predicates/probes. v0.36.0. Decision: D-20260904-tracking-audit-in-graph-script-gated-commit.
