# Ideas (unscoped / future)

Future intents — captured by `/project-plan`, not started. Scope before acting; promote to
`action-items.md` when an idea goes active. These are the slices that take `workspace-os` from
SP1 (tracking) to the full workspace plugin discussed in the design.

### adoption-import — reshape existing repo docs into workspace-os style  (memory-adoption case SHIPPED 2026-06-26)
- Workstream: skills
- Priority: high
- Intended start: next slice, after SP2a is dogfooded
- Why/context: everything built so far is greenfield-only — `/project-init` refuses if the dirs exist, `/ingest` authors one new fact at a time. Repos adopting workspace-os usually already have docs. Need an explicit, **opt-in** adoption command. This reconciles with SP2's boundary rule (§3) by splitting two behaviors: the **passive default stays "never auto-touch existing docs"**; adoption is a **deliberate, confirmed** reshaping. Must handle four source types: (1) free-form docs (README/NOTES/design docs) → `docs/memory/` facts; (2) a different memory format (top-level `memory/`, a wiki) → workspace-os schema + index; (3) CLAUDE.md reference content → pulled into memory, **boundary test applied per item** (imperatives stay in CLAUDE.md); (4) prior tracking/roadmap docs → action-items/ideas/decisions.
- **Shipped (v0.3.0):** source type (1) + (3) — free-form docs + CLAUDE.md reference content → `docs/memory/`. See `resolved.md` A-20260626-memory-adopt. Decision: D-20260626-memory-adopt-design.
- **Remaining sub-slices:** (a) foreign memory-format conversion (top-level `memory/`, wiki → workspace-os schema); (b) roadmap/TODO → tracking (prior tracking docs → action-items/ideas/decisions).
- To start remaining sub-slices, future-us needs: foreign-format detection heuristics + schema mapping; a `/project-adopt-tracking` skill or a new mode on `/memory-adopt` for tracking-doc import. Relates to [[SP2-memory]].

### SP2-memory — in-repo structured memory + reconciliation  (SHIPPED 2026-06-26 — SP2a + SP2b)
- Workstream: memory
- Priority: high
- Intended start: DONE — SP2a + SP2b both in `resolved.md`; decisions D-20260626-repo-canonical-memory / -claude-import-syntax / -memory-skill-family
- Why/context: the highest-leverage gap. An in-repo, version-controlled, AI-readable memory layer (read every session) — Zach's `keystone-engine` pairs this with tracking. Must reconcile with the existing `~/.claude` auto-memory (MEMORY.md), not duplicate it.
- To start, future-us needs: a design spec (SP2) deciding the memory home (in-repo `memory/` vs the auto-memory) and the relationship/sync between them; then skills `/ingest` (durable fact → memory), `/memory-lint` (index + wikilink integrity), `/memory-sync`; and a warn-only secret-guard hook.

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
