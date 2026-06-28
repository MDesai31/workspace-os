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

### A-20260626-memory-adopt — memory-adopt slice: adopt existing docs into docs/memory/ (v0.3.0)
- Workstream: memory
- Status: done
- Created: 2026-06-26
- Completed: 2026-06-26
- Commit: c9860ac..090bc38 (022b0a5 conventions, 6b17db9 skill; branch memory-adopt)

Built subagent-driven, all tasks reviewed clean: `conventions/memory.md` gained an "Adopting existing docs" subsection; `/memory-adopt` skill (opt-in, propose→confirm→apply) that scans free-form docs, classifies facts, deduplicates, secret-scans, proposes, and applies only on confirm. Dogfooded on this repo: README → multiple facts, boundary test, idempotent re-run, secret refusal. Decision: D-20260626-memory-adopt-design.

### A-20260627-tracking-adopt — build /tracking-adopt slice 1 (docs-only)
- Workstream: skills
- Status: done
- Created: 2026-06-27
- Completed: 2026-06-27
- Commit: f3a5763..ceb1420 (tracking-adopt branch)

Spec docs/specs/2026-06-27-tracking-adopt-design.md; plan docs/plans/2026-06-27-tracking-adopt.md. Decision D-20260627-tracking-adopt-design.

### A-20260625-default-branch-main — rename default branch master→main
- Workstream: packaging
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-28
- Commit: n/a (repo-admin op; see PR #5)

Renamed `master`→`main`, set the remote default to `main`, deleted the old remote `master`. Part of the packaging sweep (spec docs/specs/2026-06-28-packaging-sweep-design.md; plan docs/plans/2026-06-28-packaging-sweep.md).

### A-20260625-visibility-decision — decide repo visibility
- Workstream: packaging
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-28
- Commit: decided private — see D-20260628-stay-private

Decided: keep the repo **private** for now, reassess later. No repo change.

### A-20260625-meta-ci — add validation CI to workspace-os itself
- Workstream: packaging
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-28
- Commit: PR #5

Dependency-free `scripts/validate-plugin.py` (manifests parse + required keys; every `skills/*/SKILL.md` has `name`/`description` frontmatter) run by `.github/workflows/ci.yml` on PRs/pushes to `main` (`contents: read`, SHA-pinned checkout), gated by branch protection requiring the `validate` check.
