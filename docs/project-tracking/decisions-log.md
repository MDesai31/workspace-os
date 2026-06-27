# Decisions Log

Append-only record of *why* we chose X. Added by `/project-log decision` with a `D-YYYYMMDD-slug`
ID. Never rewrite history — only add. Records use the decision template from the conventions doc.

### D-20260626-repo-canonical-memory — repo `docs/memory/` is canonical shared memory; auto-memory is an optional bridge
- Workstream: memory
- Created: 2026-06-26
- Rationale: workspace-os is a general plugin (solo or team, with or without harness auto-memory); the universal store is the repo itself, not a personal `~/.claude`. klapp is collaborative, so shared knowledge must travel with the repo. Inverts the colleague's personal→mirror direction. "Reconcile, don't duplicate" is an operational test — costly-if-unseen → CLAUDE.md, else → `docs/memory/`. Retrieval = import the index only.
- Spawns: A-20260626-sp2b-memory-roundout

Full design: `docs/specs/2026-06-26-sp2-memory-design.md`. Plan: `docs/plans/2026-06-26-sp2-memory.md`.

### D-20260626-ingest-skill-name — capture skill is `/ingest`, not `/remember` (collision)
- Workstream: skills
- Created: 2026-06-26
- Rationale: `remember@claude-plugins-official` is an existing official-marketplace plugin (a `.remember/` session-handoff memory system) globally enabled on the user's Windows machine. workspace-os is portable, so a `remember` skill would collide there and confuse two memory systems. Renamed to `/ingest` (also the colleague's proven name). Surfaced by the SP2a klapp dogfood.
- Spawns: none

### D-20260626-claude-import-syntax — CLAUDE.md import is `@path`, not `@import`
- Workstream: memory
- Created: 2026-06-26
- Rationale: SP2a wired retrieval as `@import docs/memory/MEMORY.md`, but Claude Code's CLAUDE.md import syntax is a bare `@path` (cf. klapp's existing `@AGENTS.md`); `@import …` loads nothing. Corrected to `@docs/memory/MEMORY.md` across the plugin. Caught by the live klapp dogfood — the per-task reviews had flagged live import behavior as unverifiable from a diff.
- Spawns: none

### D-20260626-memory-skill-family — memory upkeep skills use a `memory-*` prefix
- Workstream: skills
- Created: 2026-06-26
- Rationale: rename `/sync-memory` → `/memory-sync` so the two upkeep skills (`/memory-lint`, `/memory-sync`) share a discoverable prefix; `/ingest` stays as the capture verb. User decision at SP2b kickoff.
- Spawns: none
