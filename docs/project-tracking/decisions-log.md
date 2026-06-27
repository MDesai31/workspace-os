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

### D-20260626-automem-type-mapping — /memory-sync uses content-driven gates, not a rigid type map
- Workstream: memory
- Created: 2026-06-26
- Rationale: the SP2b live dogfood showed auto-memory's taxonomy (`user|feedback|project|reference`) doesn't map 1:1 to repo types (`domain|convention|reference`), and `project`/`feedback` are heterogeneous. Added content-driven gates (codebase-knowledge → knowledge-vs-state → CLAUDE.md) + type *hints* + a slug-normalization rule to `conventions/memory.md`; the type is a hint, the gates decide. `user`-type never migrates; goals/status → tracking. `/memory-sync` steps 2 + 4 point at this.
- Spawns: none

### D-20260626-memory-adopt-design — /memory-adopt is opt-in, propose→confirm→apply, reuses conventions gates
- Workstream: memory
- Created: 2026-06-26
- Rationale: opt-in adoption is the non-empty-repo entry point; `/project-init` scaffolds-if-absent so memory-adopt can run after init or independently. CLAUDE.md trim is proposed but only applied on explicit confirm + gate-passing lines (imperatives stay). Dedup is model-judgment (no exact-match required). Reuses the existing conventions boundary test and type gates from `conventions/memory.md` — no new schema. Source files are read-only; only `docs/memory/` and the CLAUDE.md summary section are written.
- Spawns: A-20260626-memory-adopt

### D-20260627-memory-adopt-claudemd-scope — "never migrate CLAUDE.md" scoped to the passive default
- Workstream: memory
- Created: 2026-06-27
- Rationale: the live klapp dogfood surfaced a contradiction in `conventions/memory.md` — the boundary-rule line "Never migrate existing CLAUDE.md content into memory" read as a blanket ban, contradicting `/memory-adopt`'s own purpose (reshape an overgrown CLAUDE.md) and its trim rule (Adopting existing docs §). Scoped that line to the **passive default** (`/project-init` + day-to-day work): never bulk-migrate; the explicit opt-in `/memory-adopt` is the one exception, extracting non-costly *reference* lines only with confirmation. Trim feature retained. User design call at the dogfood gate.
- Spawns: none
