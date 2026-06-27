# Resolved (the record)

Completed action records, archived here by `/project-log done` (with completion date + commit
ref). Append-only.

### A-20260625-install-and-dogfood — install workspace-os and use it natively
- Workstream: skills
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-26
- Commit: n/a (klapp tracking left staged-ready)

Installed via marketplace + `/plugin install`; native skills confirmed by running `/project-init` on klapp (first live dogfood).

### A-20260626-sp2a-memory-core — SP2a: memory conventions + /project-init scaffold + /ingest
- Workstream: memory
- Status: done
- Created: 2026-06-26
- Completed: 2026-06-26
- Commit: 4a758e3..4613206 (branch sp2-memory)

Built subagent-driven, all tasks reviewed clean: `conventions/memory.md` (schema + boundary test + retrieval SoT), `/project-init` scaffolds `docs/memory/` + import, `/ingest` captures a fact. Live klapp dogfood passed; PR #1 merged. Decision: D-20260626-repo-canonical-memory.

### A-20260626-sp2b-memory-roundout — SP2b: /memory-lint, /memory-sync, warn-only secret guard
- Workstream: memory
- Status: done
- Created: 2026-06-26
- Completed: 2026-06-26
- Commit: 6db96ab..8a5d47a (branch sp2b-memory)

Built subagent-driven (all tasks reviewed clean): `/memory-lint` (index/frontmatter/wikilink integrity), `/memory-sync` (one-way `~/.claude`→repo bridge), and a warn-only secret-guard hook (`hooks/memory-secret-guard.sh` + `hooks/hooks.json`). Naming: D-20260626-memory-skill-family. Batched review minors fixed in 8a5d47a.
