# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260628-memory-adopt-hardening — /memory-adopt: resolve @imports + widen candidate set
- Workstream: skills
- Status: open
- Created: 2026-06-28

Closes `adoption-import` sub-slices (c) + (d) from `ideas.md`, both surfaced by the 2026-06-27
klapp dogfood. Introduce the always-loaded **instruction-file class** (`CLAUDE.md` + `AGENTS.md` +
resolved `@import` targets, all trimmable), resolve `@import`s recursively (guarded, depth cap 5,
repo-relative only), and widen the default candidate set. Edits `conventions/memory.md` (SoT) +
`skills/memory-adopt/SKILL.md` (delete its "Known limitations" block). Spec:
`docs/specs/2026-06-28-memory-adopt-hardening-design.md`. Decision pending: instruction-file class
+ recursive @import.
