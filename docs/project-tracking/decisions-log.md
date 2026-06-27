# Decisions Log

Append-only record of *why* we chose X. Added by `/project-log decision` with a `D-YYYYMMDD-slug`
ID. Never rewrite history — only add. Records use the decision template from the conventions doc.

### D-20260626-repo-canonical-memory — repo `docs/memory/` is canonical shared memory; auto-memory is an optional bridge
- Workstream: memory
- Created: 2026-06-26
- Rationale: workspace-os is a general plugin (solo or team, with or without harness auto-memory); the universal store is the repo itself, not a personal `~/.claude`. klapp is collaborative, so shared knowledge must travel with the repo. Inverts the colleague's personal→mirror direction. "Reconcile, don't duplicate" is an operational test — costly-if-unseen → CLAUDE.md, else → `docs/memory/`. Retrieval = `@import` the index only.
- Spawns: A-20260626-sp2b-memory-roundout

Full design: `docs/specs/2026-06-26-sp2-memory-design.md`. Plan: `docs/plans/2026-06-26-sp2-memory.md`.
