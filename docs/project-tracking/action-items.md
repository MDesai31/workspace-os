# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260829-playbook-followups — /project-init stamps playbooks/ + deterministic playbook lint
- Workstream: skills
- Status: open
- Created: 2026-08-29

Plugin-side remainder of the shipped procedure-playbooks idea: stamp the playbooks/ scaffold at
init, and lint the silent failure modes of the fail-open surfacing hook (bad frontmatter, dead
ERE triggers, coerced surface values) via scripts/playbook-lint.sh, wired into /memory-lint.
Spec: docs/specs/2026-08-29-playbook-followups-design.md.
