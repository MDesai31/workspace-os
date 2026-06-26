# Ideas (unscoped / future)

Future intents — captured by `/project-plan`, not started. Scope before acting; promote to
`action-items.md` when an idea goes active. These are the slices that take `workspace-os` from
SP1 (tracking) to the full workspace plugin discussed in the design.

### SP2-memory — in-repo structured memory + reconciliation
- Workstream: memory
- Priority: high
- Intended start: next slice after SP1
- Why/context: the highest-leverage gap. An in-repo, version-controlled, AI-readable memory layer (read every session) — Zach's `keystone-engine` pairs this with tracking. Must reconcile with the existing `~/.claude` auto-memory (MEMORY.md), not duplicate it.
- To start, future-us needs: a design spec (SP2) deciding the memory home (in-repo `memory/` vs the auto-memory) and the relationship/sync between them; then skills `/ingest` (durable fact → memory), `/memory-lint` (index + wikilink integrity), `/sync-memory`; and guard hooks (memory-write-guard, memory-ingest-guard).

### SP3-finish-task — closing-ritual orchestration
- Workstream: workflow
- Priority: mid
- Intended start: after SP2 (or in parallel — mostly wiring)
- Why/context: a single `/finish-task` that sequences the gates that already exist instead of restating them — review (`/code-review`, `/security-review`) → verify → commit → PR → and the tracking close-out (log `done`, move to resolved, log any decisions) in the same pass.
- To start, future-us needs: most pieces already exist (CI/PR flow + review skills). A `/finish-task` SKILL.md that orchestrates them + a `/branch-cleanup` skill.

### SP4-meta-onboarding — management + extension layer
- Workstream: meta
- Priority: low
- Intended start: only once the engine has enough hooks/skills to be worth managing
- Why/context: makes the plugin self-managing and adoptable. Zach's `/workspace` config panel toggles hooks/skills without hand-editing JSON.
- To start, future-us needs: a `hooks-registry.json` + `manage_hooks.py` engine; a `/workspace` (or `/project-guide`) panel skill; a `workspace-guide` agent + guide/project-detect hooks; and an `examples/blank-module` template showing how to add a per-project module.

### tracking-skills-roundout — fuller tracking surface
- Workstream: skills
- Priority: mid
- Intended start: incremental, alongside real use
- Why/context: SP1 ships action/decision/done + plan; the full set adds visibility and capture modes.
- To start, future-us needs: `/project-status` (summarize open items by workstream), `/work-journal` (what I did this session), and extra `/project-log` modes — `discovery` (→ a `work-log.md`), `meeting-notes`, `release-notes` (→ `RELEASES.md`/CHANGELOG).

### portfolio-registry — cross-repo Layer 3
- Workstream: portfolio
- Priority: someday
- Intended start: when a single cross-project view is actually wanted
- Why/context: a registry spanning OA + klapp + future repos (lifecycle, priority, last-touched). Deferred deliberately (YAGNI). Complicated by separate repos — needs a home above them (a command-center repo or the workspace root).
- To start, future-us needs: a decision on where the registry lives given separate repos; then a `projects.md` schema + a `/project-status` portfolio mode that aggregates across repos.

### engine-hooks — automated upkeep
- Workstream: workflow
- Priority: low
- Intended start: after the core skills see real use
- Why/context: keep the journal honest without manual discipline.
- To start, future-us needs: a `Stop` hook nudging "log what you decided this session," and a CI link-guard that fails a PR breaking an index/wikilink (Zach has one in his `ci.yml`).
