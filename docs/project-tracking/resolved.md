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

Dependency-free `scripts/validate-plugin.py` (manifests parse + required keys; every `skills/*/SKILL.md` has `name`/`description` frontmatter) run by `.github/workflows/ci.yml` on PRs/pushes to `main` (`contents: read`, SHA-pinned checkout). CI is **advisory** — branch protection to make it a required merge gate is unavailable on a free private repo (see D-20260628-ci-advisory).

### A-20260628-memory-adopt-hardening — /memory-adopt: resolve @imports + widen candidate set
- Workstream: skills
- Status: done
- Created: 2026-06-28
- Completed: 2026-06-28
- Commit: 3cc0f52 (PR #7, branch memory-adopt-hardening)

Introduced the always-loaded **instruction-file class** (`CLAUDE.md` + `AGENTS.md` + resolved
`@import` targets, all trimmable), recursive guarded `@import` resolution (cap 5, repo-relative
only), and a wider default candidate set. Closes `adoption-import` (c)+(d). Edited
`conventions/memory.md` (SoT) + `skills/memory-adopt/SKILL.md` (deleted its Known limitations
block). Spec `docs/specs/2026-06-28-memory-adopt-hardening-design.md`; plan
`docs/plans/2026-06-28-memory-adopt-hardening.md`. Decision
D-20260628-memory-adopt-instruction-file-class.

### A-20260701-guardrail-engine — guardrail engine + provenance rules (hook-starter-library + provenance-guard)
- Workstream: workflow
- Status: done
- Created: 2026-07-01
- Completed: 2026-07-02
- Commit: 87a71dd (PR #8, branch guardrail-engine)

One portable PreToolUse engine (`hooks/guardrail.sh`, bash+jq) applying warn-only built-in defaults
(secret-content, force-push, `rm -rf`) + high-confidence secret denies + declarative per-repo rules
(`.claude/guardrails.json`, `bash`/`write` with `field`/`action`/`match`/`reason`) to Bash + Edit/Write.
deny=exit 2 (stderr to Claude), warn=`{"systemMessage": …}` JSON on stdout + exit 0, fail-open throughout. Registered on `Bash|Edit|Write` in
`hooks/hooks.json`; retired `hooks/memory-secret-guard.sh` into the engine; shipped
`templates/guardrails.json` (provenance `ip_class` + example rules). 14-case bash test harness wired
into CI. Spec `docs/specs/2026-07-01-guardrail-engine-design.md`; plan
`docs/plans/2026-07-01-guardrail-engine.md`. Decision D-20260701-guardrail-engine.

### A-20260705-memory-graph-vendor — vendor keystone's memory_graph.py as /memory-lint's deterministic pass
- Workstream: memory
- Status: done
- Created: 2026-07-05
- Completed: 2026-07-05
- Commit: 09b3ca6 (PR #10, branch memory-graph-vendor; supersedes closed #9)

Vendored `scripts/memory_graph.py` from `zachburke9/keystone-engine`
(`starter/scripts/memory_graph.py` @ cecb4b9, MIT, Zach Burke — courtesy attribution in the
docstring). Adaptations: `docs/memory` default root; `[[wikilink]]` targets resolve against fact
files AND `A-`/`D-` records harvested from `docs/project-tracking/` headings; index-parity checks
(unindexed files + dangling MEMORY.md entries) added to the `--check` fail gate; MEMORY.md excluded
from orphan noise; trimmed upstream modes we don't use (--html/--relink/--suggest-hublinks/
--recency — re-vendor if wanted). Typed wikilink edges (`[[supersedes::target]]`) documented in
`conventions/memory.md` (SoT). `/memory-lint` SKILL.md restructured: script = deterministic pass,
model = frontmatter/slug judgment. 9-case bash test harness (`tests/test-memory-graph.sh` +
clean/broken fixtures) wired into CI; verified clean against klapp's live `docs/memory/`.
Plugin v0.7.0. Decision D-20260705-keystone-reposition.

### A-20260705-decision-status — Status + append-only supersession on decision records
- Workstream: schema
- Status: done
- Created: 2026-07-05
- Completed: 2026-07-05
- Commit: 4b5d68c (PR #11, branch decision-status)

Added `Status: accepted` (written once, never edited) + optional `Consequences:` + conditional
`Supersedes: [[supersedes::D-old]]` to the decision template in `conventions/project-tracking.md`,
with an append-only supersession protocol: the old record gets exactly one appended
`- Superseded-by: [[superseded_by::D-new]]` line; read rule = Superseded-by wins over Status;
records with neither (pre-schema) are grandfathered as accepted. `/project-log decision` taught to
set the new lines and perform the one permitted append to an old record. Same typed-link predicate
vocabulary as `conventions/memory.md`. Closes the `decision-status` idea. Plugin v0.8.0.
Decision D-20260705-decision-status-append-only.
