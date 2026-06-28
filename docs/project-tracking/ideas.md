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
- **Dogfood (2026-06-27):** ran live (user-triggered) on klapp — adopted 2 domain facts, correctly proposed **no** CLAUDE.md trim (already clean), secret-scan flagged README seed-login passwords, surfaced findings (c)/(d) below + the CLAUDE.md-scope contradiction → D-20260627-memory-adopt-claudemd-scope.
- **Shipped (v0.4.0):** sub-slice (b) **SHIPPED (docs-only)** — `/tracking-adopt` slice 1 routes roadmaps/TODOs → tracking (ideas/decisions-log/action-items). See `resolved.md` A-20260627-tracking-adopt. Decision: D-20260627-tracking-adopt-design. Remaining of (b): git-history archaeology + resolved.md import = slice 2.
- **Remaining sub-slices:** (a) foreign memory-format conversion (top-level `memory/`, wiki → workspace-os schema); (b.2) git-history + resolved.md import (slice 2); (c) resolve CLAUDE.md `@imports` during scan — the klapp dogfood found imported files (e.g. `@AGENTS.md`) are invisible to classification though they're effectively always-loaded; (d) widen/parameterize candidate globs — `AGENTS.md`/`RUNNING.md` aren't scanned unless passed as the path argument. (c)/(d) memory-adopt hardening still pending.
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

### provenance-guard — IP-boundary / cross-repo leakage guard  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: high
- Intended start: next guard/hook slice (pairs with [[SP2-memory]]'s secret-guard)
- Why/context: workspace-os's premise is "carry the engine job-to-job" — which is exactly when proprietary-content leakage is highest-risk. The user's new-job context (BI→Sr/Lead DS, theme-park ops forecasting, Azure→AWS) repeatedly stresses a Westgate↔Universal↔personal IP wall (clean-room blueprints; "skills are yours, code/data are the employer's"). Extend the existing `hooks/memory-secret-guard.sh` into a provenance layer: tag each repo with an `owner`/`ip-class` (personal · employer · clean-room) and warn on writes that look like cross-boundary leakage. Zach's repo shows a clean **zero-cost** mechanism: a dormant `.claude/security-patterns.yaml` read by the official `security-guidance` plugin's free deterministic per-edit regex layer (no model call) — ship a template with IP/secret/cross-repo patterns rather than a bespoke hook. Pairs with a "clean-room blueprint capture" memory/plan flavor (carry *patterns*, not *code* — mirrors the user's `sagemaker_lstm_port.md`).
- To start, future-us needs: a repo-tagging scheme (`ip-class` in the tracking README or a config), a `security-patterns.yaml` template + pattern set, and a hook-vs-plugin delivery decision. Relates to [[SP2-memory]], [[adoption-import]].

### model-decision-log — DS experiment / model-decision tracking record  (brainstorm 2026-06-28)
- Workstream: skills
- Priority: high
- Intended start: incremental, alongside [[tracking-skills-roundout]]
- Why/context: the user's DS work already treats model decisions as first-class artifacts (an "Architecture Decisions" table in `Model_Summary.md`; an `opportunities.md` ranking ML use cases by value vs readiness). Make that a typed tracking record / `/model-decision` mode: dataset/vintage, architecture choice, validation protocol, metric, champion/challenger outcome. Immediate use at the new job (SageMaker forecasting + model registry) and on the Options Analyzer. DS-specific sibling of the generic `D-` decision record.
- To start, future-us needs: a record template added to `conventions/project-tracking.md` + either a `/project-log model-decision` mode or a standalone `/model-decision` skill. Relates to [[tracking-skills-roundout]].

### github-native-tracking — tracking surface in GitHub Issues/Projects (a decision to deliberate)  (brainstorm 2026-06-28)
- Workstream: schema
- Priority: mid
- Intended start: decide before building — this forks the data model
- Why/context: tracking today is markdown-only (append-`union` files). Zach's repo pushes tracking into GitHub-native surfaces: issue templates (`effort`/`task`/`tracking`), a `project-autofill` workflow, and a `project-weekly-update` workflow that posts status to a GitHub **Projects v2** board via GraphQL (`createProjectV2StatusUpdate`). Bigger visibility and a real board, but a heavier model and a potential second source of truth. Capture as a *decision to make*, not a build: stay markdown-canonical (portable, offline, diff-friendly, the current design) or adopt GitHub Projects (richer, needs PATs + online)?
- To start, future-us needs: a decision spec weighing markdown-canonical vs Projects-canonical (or a one-way sync between them); if adopted, issue templates + a Projects-v2 GraphQL workflow (PAT with `project` scope — note: user-owned boards need a classic PAT). Relates to [[portfolio-registry]], [[tracking-skills-roundout]].

### leakage-audit-skill — reusable ML leakage checklist  (brainstorm 2026-06-28)
- Workstream: skills
- Priority: mid
- Intended start: alongside real DS use (work clean-room + Options Analyzer)
- Why/context: leakage discipline is the user's strongest evidenced DS signal (past-only lags, train-only fits, no post-outcome features, a train/serve feature-parity test). The 30/60/90 ramp plan literally lists "establish a team leakage-checklist standard." Codify it as a runnable pre-ship `/leakage-audit` checklist skill — portable across the work clean-room and OA, and a concrete mentorship/team-standard artifact.
- To start, future-us needs: the checklist content (lifted from the user's existing leakage practices) + a `SKILL.md`. Relates to [[model-decision-log]], [[provenance-guard]].

### integrity-auditor — tracking/memory integrity check (free default + dormant cloud tiers)  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: mid
- Intended start: after the core skills see real use (the cloud-cron sibling of [[engine-hooks]])
- Why/context: the append-`union` tracking + memory files silently lose or duplicate entries on bad merges — `conventions/project-tracking.md` already flags "periodically scan for duplicate lines." Zach's `claude-weekly-audit.yml` productizes this as a scheduled cross-PR pass over `master` that names exactly these files (decisions-log, action-items, MEMORY.md) and files findings as a GitHub issue. **Cost framing (verified 2026-06-28):** the headline checks are deterministic — ID uniqueness/monotonicity, index↔file parity, duplicate-line detection — so the **default ships free as a local/in-session script or hook (Tier 0, no LLM)**; an LLM pass is reserved only for the fuzzy residual ("content moved but not landed", semantic regressions). Cloud tiers are opt-in/dormant: Tier 1 bills a Claude Pro/Max OAuth token (`claude_code_oauth_token`); Tier 2 bills Anthropic API credits. GitHub Copilot is **not** a cheaper substitute: as of 2026-06-01 Copilot moved to usage-based AI-Credits + Actions-minutes billing, its code review is PR-diff-scoped (covers a per-PR reviewer, not this cross-PR audit) and is excluded from the Free plan (needs ≥ Pro at $10/mo). Borrow Zach's hardening for any cloud tier: dormant-by-default (no-op until a secret exists), pinned action SHA, and a fail-loud cost/error guard (his caught ~50 PRs that merged "green but unreviewed" on a dead key).
- To start, future-us needs: the deterministic auditor script (ID/index/dup checks) + `Stop`/pre-PR hook wiring; optionally dormant CI workflow templates for the LLM/cloud tiers. Relates to [[engine-hooks]].

### hook-starter-library — reusable per-project hook templates (generic engine + per-repo rules)  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: high
- Intended start: with/after [[SP4-meta-onboarding]] (feeds its hooks-registry)
- Why/context: both OA and klapp already rely on a couple of small `.claude` hooks that generalize. OA's `.claude/settings.json` carries (1) a **PostToolUse advisory lint** — runs `ruff check` on edited `.py` files, non-blocking, injects the result as `additionalContext` ("fix if quick") — and (2) a **PreToolUse command guardrail** — denies raw `duckdb.connect()` and redirects to the sanctioned `mcp__duckdb__query` tool. These are stack-agnostic patterns (ruff→eslint/tsc for klapp; the guardrail = any "use the sanctioned path, not the raw one" rule). Ship a **starter library** of parameterized templates so each repo opts in rather than hand-rolling.
  - **Generic guardrail design (the key bit — must not hardcode duckdb):** engine/data split, same as the rest of workspace-os. ONE plugin-shipped hook script (the engine, updated centrally) + a per-repo `.claude/guardrails.json` (the data, version-controlled). The script reads the rules file and applies whatever's there; the duckdb rule becomes one *entry* in OA's file, not code. Schema: top-level keys per tool (`bash`, `edit`); each rule `{name, match (regex), action: "deny"|"warn", reason}`. `deny` → emit `permissionDecision: "deny"`; `warn` → inject `additionalContext` (same mechanism as the lint hook). **No file / no match → exit 0 (fail open)** so un-opted-in repos are unaffected. Ship a small **universal default** set on by default (warn on `git push --force` to default branch; **deny writing `.env`/secrets** — overlaps + feeds [[provenance-guard]]; warn on `rm -rf` near repo root); per-repo rules stack on top. Registration: `/project-init` (or a `/guardrails` helper) adds the PreToolUse entry to the repo's `.claude/settings.json` pointing at the plugin script.
  - **Division of labor with [[provenance-guard]]:** this hook handles *command-level* deny/redirect (any tool, esp. Bash, can block); `security-patterns.yaml` (the `security-guidance` plugin) handles per-*edit* content tripwires (advisory only). Same "declarative per-repo rules + generic engine" philosophy at two enforcement points.
- To start, future-us needs: the generic hook script + `guardrails.json` schema + the post-edit-lint template (language-parameterized) + a universal-defaults baseline; `/project-init` wiring into `.claude/settings.json`. Relates to [[engine-hooks]], [[SP4-meta-onboarding]], [[provenance-guard]].

### continuity-runbook — operational-continuity doc (CONTINUITY.md + /continuity)  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: high
- Intended start: standalone; motivated now by OA's real setup
- Why/context: the bus-factor doc Zach ships (`CONTINUITY.md`) — "if the maintainer is out for a month, what silently stops and how does someone recover it?" — is now concretely needed by the user's own work, not just a borrowed pattern. OA has **12 systemd service/timer pairs** + a `data-pipeline-guardian` + `agent_docs/cron_schedule.md`: recurring jobs that, if they stop, silently staleness dashboards with no error. That's exactly the risk a continuity runbook captures: a *pointer-map* (never secrets) of each recurring obligation — cadence, host, what breaks if it stops, and **how failure is detected** — plus access/secrets pointers and `TODO(owner)` markers for facts only the owner knows. Doubly relevant to the user's new lead role ("it runs without me babysitting it"). Note the operational/health-guardian generalization (OA's pipeline-guardian) is adjacent: a future `/doctor`-style health check could verify the obligations this doc lists (see [[project-doctor]]).
- To start, future-us needs: a `CONTINUITY.md` template (obligations table + access/secrets pointers + TODO(owner) convention) + a `/continuity` skill to scaffold/update it; decision on where it lives (repo root vs `docs/`). Relates to [[SP4-meta-onboarding]], [[integrity-auditor]], [[project-doctor]].

### project-doctor — verify a repo's setup/runtime preconditions  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: mid
- Intended start: after continuity/onboarding pieces land (overlaps existing ideas — flag, don't rush)
- Why/context: klapp's `RUNNING.md` is a manual setup checklist (Docker up, `.env` set, `prisma migrate dev`, seed run); OA's guardian checks data freshness. Generalize to a `/doctor` skill: each repo declares its preconditions (env vars present, services up, deps installed, data fresh) and the skill reports PASS/FAIL — turning a prose runbook into an executable check, and giving [[continuity-runbook]] an automated counterpart. Overlaps [[integrity-auditor]] (data/tracking checks) and [[SP4-meta-onboarding]] (onboarding) — keep scoped to *environment/runtime preconditions* to stay distinct.
- To start, future-us needs: a per-repo checks declaration (where + schema) + a `/doctor` skill that runs them; decide the boundary vs integrity-auditor (preconditions vs data/tracking integrity). Relates to [[continuity-runbook]], [[integrity-auditor]].

### stale-priors-memory — memory flavor for "training prior is wrong here"  (brainstorm 2026-06-28)
- Workstream: memory
- Priority: low
- Intended start: a `conventions/memory.md` tweak whenever memory schema is next touched
- Why/context: klapp's `CLAUDE.md`/`AGENTS.md` are dominated by "*Prisma 6 / Next 16 breaking changes from your training data*" entries — capturing where the model's priors are actively *wrong* for this repo's stack (e.g. import client from `@/generated/prisma/client`, `searchParams` is now a `Promise`). This is a recurring, high-value knowledge flavor for any fast-moving framework. Formalize a `stale-prior`/`gotcha` memory type (or a CLAUDE.md section convention): "your training prior says X; here it's actually Y." Light — a memory-convention improvement, not a feature.
- To start, future-us needs: add the `stale-prior` flavor to `conventions/memory.md` (type hint + boundary test: does it stay in CLAUDE.md as always-loaded, or move to on-demand `docs/memory/`?). Relates to [[SP2-memory]], [[adoption-import]].
