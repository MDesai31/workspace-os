# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260711-tracking-adopt-git — build /tracking-adopt git mode per spec
- Workstream: skills
- Status: open
- Created: 2026-07-11

Implement `docs/specs/2026-07-11-tracking-adopt-git-design.md` (adoption-import sub-slice b.2):
the `git` mode on `/tracking-adopt` — bounded history mining → resolved.md records (one per
merged unit, SHA/PR# dedup), opportunistic gh enrichment, doc-completed cross-match; SoT
completed-route update in `conventions/project-tracking.md`; version bump + README/ARCHITECTURE
touch-ups. Gated live dogfood on Options Analyzer before merge. Spawned by
D-20260711-tracking-adopt-git-design.
