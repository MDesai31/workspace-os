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
- **Shipped (v0.5.0):** sub-slices (c) + (d) — recursive `@import` resolution + wider candidate set, via the always-loaded **instruction-file class** (`CLAUDE.md` + `AGENTS.md` + `@import` targets, all trimmable). See `resolved.md` A-20260628-memory-adopt-hardening. Decision: D-20260628-memory-adopt-instruction-file-class.
- **Shipped (v0.12.0):** sub-slice (b.2) — git-history + resolved.md import via `/tracking-adopt git`. See `resolved.md` A-20260711-tracking-adopt-git. Decision: D-20260711-tracking-adopt-git-design.
- **Remaining sub-slices:** (a) foreign memory-format conversion (top-level `memory/`, wiki → workspace-os schema).
- To start remaining sub-slices, future-us needs: foreign-format detection heuristics + schema mapping. Relates to [[SP2-memory]].

### SP2-memory — in-repo structured memory + reconciliation  (SHIPPED 2026-06-26 — SP2a + SP2b)
- Workstream: memory
- Priority: high
- Intended start: DONE — SP2a + SP2b both in `resolved.md`; decisions D-20260626-repo-canonical-memory / -claude-import-syntax / -memory-skill-family
- Why/context: the highest-leverage gap. An in-repo, version-controlled, AI-readable memory layer (read every session) — Zach's `keystone-engine` pairs this with tracking. Must reconcile with the existing `~/.claude` auto-memory (MEMORY.md), not duplicate it.
- To start, future-us needs: a design spec (SP2) deciding the memory home (in-repo `memory/` vs the auto-memory) and the relationship/sync between them; then skills `/ingest` (durable fact → memory), `/memory-lint` (index + wikilink integrity), `/memory-sync`; and a warn-only secret-guard hook.

### SP3-finish-task — closing-ritual orchestration
- Workstream: workflow
- Priority: low (demoted by D-20260705-keystone-reposition — borrow-first, don't build)
- Intended start: only if adapting keystone's version proves insufficient
- Why/context: a single `/finish-task` that sequences the gates that already exist instead of restating them — review (`/code-review`, `/security-review`) → verify → commit → PR → and the tracking close-out (log `done`, move to resolved, log any decisions) in the same pass.
- Borrow (keystone 2026-07-05): `zachburke9/keystone-engine` ships `/finish-task` + `/branch-cleanup` (MIT, shared with us). Adapt those SKILL.md files to workspace-os conventions rather than authoring from scratch. See D-20260705-keystone-reposition.
- To start, future-us needs: adapt keystone's `/finish-task` + `/branch-cleanup` SKILL.md files (CI/PR flow + review skills already exist here).

### SP4-meta-onboarding — management + extension layer
- Workstream: meta
- Priority: low (borrow-first per D-20260705-keystone-reposition — do NOT build from scratch)
- Intended start: only once the engine has enough hooks/skills to be worth managing
- Why/context: makes the plugin self-managing and adoptable. Zach's `/workspace` config panel toggles hooks/skills without hand-editing JSON.
- Borrow (keystone 2026-07-05): keystone ships this whole layer, polished — `hooks-registry.json` (each hook's FULL definition, so a disabled hook is always restorable), `manage_hooks.py` (matches by script basename across project/user scopes, `--dry-run` everywhere), `manage_skills.py`/`manage_projects.py`, the `/workspace` panel skill, a `workspace-guide` agent, `examples/blank-module/`. All MIT. Vendor/adapt; our `hooks/guardrail.sh` becomes the first registry entry. See D-20260705-keystone-reposition.
- To start, future-us needs: vendor keystone's registry + manage scripts, adapt paths/idioms to the plugin layout, register the guardrail engine as the first entry.

### tracking-skills-roundout — fuller tracking surface
- Workstream: skills
- Priority: mid
- Intended start: incremental, alongside real use
- Why/context: SP1 ships action/decision/done + plan; the full set adds visibility and capture modes.
- To start, future-us needs: `/project-status` (summarize open items by workstream), `/work-journal` (what I did this session), and extra `/project-log` modes — `discovery` (→ a `work-log.md`), `meeting-notes`, `release-notes` (→ `RELEASES.md`/CHANGELOG).
- Borrow (comparison 2026-06-28): give `/project-status` Notion-style **database views** — filter/sort open items by workstream / status / priority.
- Borrow (keystone 2026-07-05): keystone ships `/project-status`, `/work-journal`, `/meeting-notes`, `/release-notes` + a `release_draft.py` (MIT). Adapt that prose instead of writing it; per D-20260705-keystone-reposition this idea is borrow-first (priority stays mid only because the *adaptation* to our schema is still real work).

### portfolio-registry — cross-repo Layer 3
- Workstream: portfolio
- Priority: someday
- Intended start: when a single cross-project view is actually wanted
- Why/context: a registry spanning OA + klapp + future repos (lifecycle, priority, last-touched). Deferred deliberately (YAGNI). Complicated by separate repos — needs a home above them (a command-center repo or the workspace root).
- To start, future-us needs: a decision on where the registry lives given separate repos; then a `projects.md` schema + a `/project-status` portfolio mode that aggregates across repos.
- Borrow (comparison 2026-06-28): reuse Backstage's catalog **entity model** (owner / lifecycle / system / `dependsOn`) for the `projects.md` schema + a per-repo `catalog-info`-style header — don't invent fields; the header also feeds [[continuity-runbook]] (owner) and [[provenance-guard]] (ip-class).
- Note (keystone 2026-07-05): keystone's `projects.md` registry solves the *single-workspace* case only; our cross-**separate-repo** portfolio problem remains unsolved there — this idea stays differentiated, not overlap. See D-20260705-keystone-reposition.
- Note (sidecar 2026-07-07): the "where does it live" blocker is answered for the single-workspace case — workspace-level files under `_meta/` root (D-20260707-sidecar-data-layer). Cross-workspace aggregation remains open.

### engine-hooks — automated upkeep
- Workstream: workflow
- Priority: low
- Intended start: after the core skills see real use
- Why/context: keep the journal honest without manual discipline.
- **Shipped (2026-07-05, partial):** the CI/pre-commit link-guard mechanism exists — `scripts/memory_graph.py --check` fails on broken wikilinks / index-parity drift (vendored from keystone; see `resolved.md` A-20260705-memory-graph-vendor). Remaining: wiring `--check` into *target repos'* CI/pre-commit (a `/project-init` or `/guardrails` concern), and the `Stop` hook nudge.
- To start, future-us needs: a `Stop` hook nudging "log what you decided this session," and target-repo wiring for the `--check` gate.

### provenance-guard — IP-boundary / cross-repo leakage guard  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: high
- Intended start: next guard/hook slice (pairs with [[SP2-memory]]'s secret-guard)
- **Shipped (2026-07-01):** the `ip_class` tag (`personal`/`employer`/`clean-room`) + a tripwire rules pack ship via the shared guardrail engine — same mechanism as [[hook-starter-library]], no external `security-guidance` dependency. `templates/guardrails.json` carries `ip_class` + example `write` tripwire rules (user-filled per repo). See `resolved.md` A-20260701-guardrail-engine; decision D-20260701-guardrail-engine.
- Why/context: workspace-os's premise is "carry the engine job-to-job" — which is exactly when proprietary-content leakage is highest-risk. The user's new-job context (BI→Sr/Lead DS, theme-park ops forecasting, Azure→AWS) repeatedly stresses a Westgate↔Universal↔personal IP wall (clean-room blueprints; "skills are yours, code/data are the employer's"). Extend the existing `hooks/memory-secret-guard.sh` into a provenance layer: tag each repo with an `owner`/`ip-class` (personal · employer · clean-room) and warn on writes that look like cross-boundary leakage. Zach's repo shows a clean **zero-cost** mechanism: a dormant `.claude/security-patterns.yaml` read by the official `security-guidance` plugin's free deterministic per-edit regex layer (no model call) — ship a template with IP/secret/cross-repo patterns rather than a bespoke hook. Pairs with a "clean-room blueprint capture" memory/plan flavor (carry *patterns*, not *code* — mirrors the user's `sagemaker_lstm_port.md`).
- To start, future-us needs: a repo-tagging scheme (`ip-class` in the tracking README or a config), a `security-patterns.yaml` template + pattern set, and a hook-vs-plugin delivery decision. Relates to [[SP2-memory]], [[adoption-import]].


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
- **Shipped (2026-08-12, the memory/tracking boundary check):** `memory_graph.py --check-tracking` flags tracking records over ~40 lines or carrying a `**MEASURED**` block (measured evidence belongs in memory, not a record body); the boundary is documented in `conventions/project-tracking.md` and wired into `/memory-lint`. See `resolved.md` A-20260812-memory-hygiene-lints. Remaining: the ID-uniqueness/index-parity/duplicate-line auditor + the dormant cloud-cron tiers.
- Why/context: the append-`union` tracking + memory files silently lose or duplicate entries on bad merges — `conventions/project-tracking.md` already flags "periodically scan for duplicate lines." Zach's `claude-weekly-audit.yml` productizes this as a scheduled cross-PR pass over `master` that names exactly these files (decisions-log, action-items, MEMORY.md) and files findings as a GitHub issue. **Cost framing (verified 2026-06-28):** the headline checks are deterministic — ID uniqueness/monotonicity, index↔file parity, duplicate-line detection — so the **default ships free as a local/in-session script or hook (Tier 0, no LLM)**; an LLM pass is reserved only for the fuzzy residual ("content moved but not landed", semantic regressions). Cloud tiers are opt-in/dormant: Tier 1 bills a Claude Pro/Max OAuth token (`claude_code_oauth_token`); Tier 2 bills Anthropic API credits. GitHub Copilot is **not** a cheaper substitute: as of 2026-06-01 Copilot moved to usage-based AI-Credits + Actions-minutes billing, its code review is PR-diff-scoped (covers a per-PR reviewer, not this cross-PR audit) and is excluded from the Free plan (needs ≥ Pro at $10/mo). Borrow Zach's hardening for any cloud tier: dormant-by-default (no-op until a secret exists), pinned action SHA, and a fail-loud cost/error guard (his caught ~50 PRs that merged "green but unreviewed" on a dead key).
- To start, future-us needs: the deterministic auditor script (ID/index/dup checks) + `Stop`/pre-PR hook wiring; optionally dormant CI workflow templates for the LLM/cloud tiers. Relates to [[engine-hooks]].

### hook-starter-library — reusable per-project hook templates (generic engine + per-repo rules)  (brainstorm 2026-06-28) (SHIPPED 2026-07-13 — idea COMPLETE)
- Workstream: workflow
- Priority: high
- Intended start: with/after [[SP4-meta-onboarding]] (feeds its hooks-registry)
- **Shipped (2026-07-01):** the generic command/content guardrail engine (`hooks/guardrail.sh`) + per-repo `.claude/guardrails.json` (declarative `bash`/`write` deny/warn rules) + warn-only universal defaults + `templates/guardrails.json`. Registered globally via plugin `hooks.json` (no per-repo `settings.json` wiring). See `resolved.md` A-20260701-guardrail-engine; decision D-20260701-guardrail-engine.
- **Shipped (2026-07-13):** the remaining sub-slice — the PostToolUse advisory-lint template
  (`hooks/lint.sh` + `templates/lint.json`, language-parameterized via `.claude/lint.json`). See
  `resolved.md` A-20260713-lint-hook. Decision D-20260713-lint-hook. **Idea COMPLETE.**
- Why/context: both OA and klapp already rely on a couple of small `.claude` hooks that generalize. OA's `.claude/settings.json` carries (1) a **PostToolUse advisory lint** — runs `ruff check` on edited `.py` files, non-blocking, injects the result as `additionalContext` ("fix if quick") — and (2) a **PreToolUse command guardrail** — denies raw `duckdb.connect()` and redirects to the sanctioned `mcp__duckdb__query` tool. These are stack-agnostic patterns (ruff→eslint/tsc for klapp; the guardrail = any "use the sanctioned path, not the raw one" rule). Ship a **starter library** of parameterized templates so each repo opts in rather than hand-rolling.
  - **Generic guardrail design (the key bit — must not hardcode duckdb):** engine/data split, same as the rest of workspace-os. ONE plugin-shipped hook script (the engine, updated centrally) + a per-repo `.claude/guardrails.json` (the data, version-controlled). The script reads the rules file and applies whatever's there; the duckdb rule becomes one *entry* in OA's file, not code. Schema: top-level keys per tool (`bash`, `edit`); each rule `{name, match (regex), action: "deny"|"warn", reason}`. `deny` → emit `permissionDecision: "deny"`; `warn` → inject `additionalContext` (same mechanism as the lint hook). **No file / no match → exit 0 (fail open)** so un-opted-in repos are unaffected. Ship a small **universal default** set on by default (warn on `git push --force` to default branch; **deny writing `.env`/secrets** — overlaps + feeds [[provenance-guard]]; warn on `rm -rf` near repo root); per-repo rules stack on top. Registration: `/project-init` (or a `/guardrails` helper) adds the PreToolUse entry to the repo's `.claude/settings.json` pointing at the plugin script.
  - **Division of labor with [[provenance-guard]]:** this hook handles *command-level* deny/redirect (any tool, esp. Bash, can block); `security-patterns.yaml` (the `security-guidance` plugin) handles per-*edit* content tripwires (advisory only). Same "declarative per-repo rules + generic engine" philosophy at two enforcement points.
- To start, future-us needs: the generic hook script + `guardrails.json` schema + the post-edit-lint template (language-parameterized) + a universal-defaults baseline; `/project-init` wiring into `.claude/settings.json`. Relates to [[engine-hooks]], [[SP4-meta-onboarding]], [[provenance-guard]].

### continuity-runbook — operational-continuity doc (CONTINUITY.md + /continuity)  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: high
- **Shipped (2026-07-05, v0.9.0 — idea COMPLETE):** `templates/CONTINUITY.md` (5 sections generalized from Zach's shape, patterns only: deps→outs obligations table with Detection + Owner columns, access POINTERS, trusted-source re-verify budget, meta-maintenance budget, bus-factor test; `TODO(owner)` convention) + `/continuity` skill (scaffold mode auto-inventories systemd/cron/CI-schedule jobs and proposes pre-filled rows, propose→confirm→apply; review mode diffs inventory vs doc + lists TODOs by owner + staleness nudges). Home = **repo root** (D-20260705-continuity-home-root). See `resolved.md` A-20260705-continuity-runbook. Next real consumer: OA's 12 systemd timers.
- Intended start: standalone; motivated now by OA's real setup
- Why/context: the bus-factor doc Zach ships (`CONTINUITY.md`) — "if the maintainer is out for a month, what silently stops and how does someone recover it?" — is now concretely needed by the user's own work, not just a borrowed pattern. OA has **12 systemd service/timer pairs** + a `data-pipeline-guardian` + `agent_docs/cron_schedule.md`: recurring jobs that, if they stop, silently staleness dashboards with no error. That's exactly the risk a continuity runbook captures: a *pointer-map* (never secrets) of each recurring obligation — cadence, host, what breaks if it stops, and **how failure is detected** — plus access/secrets pointers and `TODO(owner)` markers for facts only the owner knows. Doubly relevant to the user's new lead role ("it runs without me babysitting it"). Note the operational/health-guardian generalization (OA's pipeline-guardian) is adjacent: a future `/doctor`-style health check could verify the obligations this doc lists (see [[project-doctor]]).
- To start, future-us needs: a `CONTINUITY.md` template (obligations table + access/secrets pointers + TODO(owner) convention) + a `/continuity` skill to scaffold/update it; decision on where it lives (repo root vs `docs/`). Relates to [[SP4-meta-onboarding]], [[integrity-auditor]], [[project-doctor]].
- Borrow (comparison 2026-06-28): frame the obligations table with DVC-style **deps→outs** (per job: inputs it needs, outputs that go stale if it stops); reuse Backstage's `owner` field for the owner column.
- Borrow (keystone 2026-07-05): keystone's engine repos are now shared with us (MIT) — adapt Zach's actual `CONTINUITY.md` shape as the template starting point instead of drafting from a blank page.

### project-doctor — verify a repo's setup/runtime preconditions  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: mid
- Intended start: after continuity/onboarding pieces land (overlaps existing ideas — flag, don't rush)
- Why/context: klapp's `RUNNING.md` is a manual setup checklist (Docker up, `.env` set, `prisma migrate dev`, seed run); OA's guardian checks data freshness. Generalize to a `/doctor` skill: each repo declares its preconditions (env vars present, services up, deps installed, data fresh) and the skill reports PASS/FAIL — turning a prose runbook into an executable check, and giving [[continuity-runbook]] an automated counterpart. Overlaps [[integrity-auditor]] (data/tracking checks) and [[SP4-meta-onboarding]] (onboarding) — keep scoped to *environment/runtime preconditions* to stay distinct.
- To start, future-us needs: a per-repo checks declaration (where + schema) + a `/doctor` skill that runs them; decide the boundary vs integrity-auditor (preconditions vs data/tracking integrity). Relates to [[continuity-runbook]], [[integrity-auditor]].
- Borrow (comparison 2026-06-28): adopt DVC's declarative **deps→outs** mindset for the checks declaration (each precondition = an input the repo asserts).

### stale-priors-memory — memory flavor for "training prior is wrong here"  (brainstorm 2026-06-28)
- Workstream: memory
- Priority: low
- Intended start: a `conventions/memory.md` tweak whenever memory schema is next touched
- Why/context: klapp's `CLAUDE.md`/`AGENTS.md` are dominated by "*Prisma 6 / Next 16 breaking changes from your training data*" entries — capturing where the model's priors are actively *wrong* for this repo's stack (e.g. import client from `@/generated/prisma/client`, `searchParams` is now a `Promise`). This is a recurring, high-value knowledge flavor for any fast-moving framework. Formalize a `stale-prior`/`gotcha` memory type (or a CLAUDE.md section convention): "your training prior says X; here it's actually Y." Light — a memory-convention improvement, not a feature.
- To start, future-us needs: add the `stale-prior` flavor to `conventions/memory.md` (type hint + boundary test: does it stay in CLAUDE.md as always-loaded, or move to on-demand `docs/memory/`?). Relates to [[SP2-memory]], [[adoption-import]].

### decision-status — Status + supersession on decision records (from ADRs)  (comparison 2026-06-28)
- Workstream: schema
- Priority: mid
- Intended start: next time the tracking schema is touched (small, additive)
- Why/context: `decisions-log.md` is effectively ADRs (append-only `D-` records with rationale + Spawns) but lacks two things mature ADRs have — a **`Status`** (accepted / superseded) and explicit **`supersedes`/`superseded-by`** links — plus an optional **`Consequences`** section. Without them the log can't show which decisions are still live without re-reading everything, and never marks a reversal. Add a lightweight `Status:` line + supersession wikilinks to the decision template (append-only: the superseding decision links back; the old record gets a one-line `Superseded-by` appended). Low-risk, high-clarity.
- **Shipped (2026-07-05, the link half):** typed wikilinks — `[[supersedes::target]]`, `[[superseded_by::…]]` etc., targets may be fact slugs or `A-`/`D-` records — are now part of the memory schema (`conventions/memory.md`) and linted/reported by the vendored `scripts/memory_graph.py` (see `resolved.md` A-20260705-memory-graph-vendor).
- **Shipped (2026-07-05, the status half — idea COMPLETE, v0.8.0):** `Status: accepted` (written once) + optional `Consequences:` + `Supersedes:` lines in the decision template; append-only supersession protocol (old record gets one appended `Superseded-by:` line; **read rule: Superseded-by wins over Status**, absent both = accepted, pre-schema records grandfathered); `/project-log decision` taught to set them. Same predicate vocabulary as memory typed links. See `resolved.md` A-20260705-decision-status; decision D-20260705-decision-status-append-only. Relates to [[tracking-skills-roundout]].

### memory-backlinks-search — backlinks + search + note templates for the memory layer (from Notion/wikis)  (comparison 2026-06-28)
- Workstream: memory
- Priority: mid
- Intended start: extend `/memory-lint` incrementally
- Why/context: the memory layer already has `[[wikilinks]]` + an index but no **backlink view** and no **search** beyond grep — the two things wikis/Notion do well. Add (1) backlink awareness to `/memory-lint` (or a `/memory-search`) that, for a given fact, lists what links *to* it; (2) lightweight **note templates** for recurring memory flavors (the [[stale-priors-memory]] gotcha type is the first); (3) optionally Notion-style **property views** over facts (by type/tag). Closes the wiki gap while keeping memory git-native + agent-loaded (the thing Notion can't do).
- **Shipped (2026-07-05, the graph half):** the vendored `scripts/memory_graph.py` (from keystone, MIT) derives the whole link graph — per-note neighbors/degree (the backlink data), orphans, weakly-linked, hubs, `--json` export — and is now `/memory-lint`'s deterministic pass. See `resolved.md` A-20260705-memory-graph-vendor. Remaining: a user-facing `/memory-search`/backlink *view* over that data, and the note-templates set.
- **Shipped (2026-07-23, the search/backlink view):** `scripts/memory_graph.py` gained `--search QUERY` (name + description substring) and `--backlinks NODE` (LINKS OUT + BACKLINKS from the wikilink graph), surfaced by the new `/memory-search` skill. See `resolved.md` A-20260723-memory-search and `decisions-log.md` D-20260723-memory-search-scope. Remaining: the note-templates set, and the optional property-views by type/tag.
- **Shipped (2026-07-27, the note-templates half - gotcha flavor):** `/ingest gotcha:` captures a stale-prior and routes it via the boundary test - a confirmed imperative bullet in a managed CLAUDE.md section (in-repo only, via the idempotent `scripts/claude-md-upsert.sh`) or a `docs/memory/` fact with the gotcha body shape; the flavor is documented in `conventions/memory.md` § Recurring flavors. See `resolved.md` A-20260727-ingest-gotcha and `decisions-log.md` D-20260727-ingest-gotcha-claudemd. Remaining: the optional property-views by type/tag.
- **Shipped (2026-08-12, citation-freshness lint):** `memory_graph.py --check-citations` verifies `file:NNN` and `` `path::symbol` `` citations against the source tree (definition-block containment; nearby non-definition tokens are UNANCHORED not stale; ambiguous basenames flagged), wired into `/memory-lint`. See `resolved.md` A-20260812-memory-hygiene-lints. Pairs with the captured [[memory-volatility-field]] (`verified-against` would give it an exact baseline).
- To start, future-us needs: a `/memory-search` entrypoint reading `memory_graph.py --json` output, a templates set; decide whether templates live in the plugin or `docs/memory/`. Relates to [[SP2-memory]], [[stale-priors-memory]], [[tracking-skills-roundout]].

### keystone-module-guardrails — package the guardrail engine as a keystone utility module  (keystone 2026-07-05)
- Workstream: meta
- Priority: low (backburnered 2026-07-05 by user — solo workspace-os slices first; revisit when a conversation with Zach happens)
- Intended start: after a conversation with Zach (PR #8 prerequisite already merged)
- Why/context: Zach shared his `zachburke9/keystone-*` ecosystem (engine / catalog / instance-template / 3 modules, private, MIT) on 2026-07-02 — a domain-neutral workspace OS with a module catalog + importer (`catalog.json` + `import_module.py`, vendored copies, `module.json` version-compat seam). The 2026-07-05 comparison (D-20260705-keystone-reposition) found keystone has **no policy-enforcement layer**: its hooks are advisory/protective, none declaratively configurable per repo. Our guardrail engine (declarative `.claude/guardrails.json` deny/warn rules + `ip_class` provenance tripwires, tested) fills that hole exactly, and fits his extension contract (a `kind: utility` module whose hook registers into his `hooks-registry.json` panel). Turns duplicated effort into collaboration; we keep authorship + the plugin distribution channel for our own repos.
- To start, future-us needs: Zach's buy-in; a `module.json` (`kind: utility`, `provides.hooks`); a thin keystone-shaped wrapper around `hooks/guardrail.sh` + `templates/guardrails.json`; a registry entry for his `/workspace` panel. Relates to [[hook-starter-library]], [[provenance-guard]], [[SP4-meta-onboarding]].

### vendor-neutral-runtime - ~80% of workspace-os usable from non-Claude agents (MCP + scripts-core)  (brainstorm 2026-07-30)
- Workstream: meta
- Priority: someday (big; the bus-factor SURVIVAL case is already covered by the portable-artifacts slice below, which needs zero MCP)
- **Shipped (2026-07-30, the bus-factor/survival half):** the portable-artifacts slice - each base now carries a self-describing operator's manual + vendored `memory_graph.py`, a vendor-neutral `AGENTS.md` entry point (canonical costly-first home), and a `CLAUDE.md` bridge; `/project-init` stamps it and `/make-portable` retrofits existing bases (both modes). See `resolved.md` A-20260730-portable-memory-base and `decisions-log.md` D-20260730-agents-md-canonical. Remaining (this idea): the ~80% multi-vendor USE via an MCP server + scripts-core refactor.
- Intended start: only if ongoing multi-vendor USE (running workspace-os from Codex/Cursor/Gemini, not just Claude) becomes a real want; first concrete step (scripts-core refactor) is worth doing on its own merits sooner
- Why/context: prompted by the "if I lost Claude, could another AI read/maintain _meta" audit (2026-07-30). Two distinct goals hide in "vendor-neutral": (a) BUS-FACTOR SURVIVAL - the knowledge survives losing the tool; fully covered by the portable-artifacts slice (self-describing base + AGENTS.md + operator's manual, read/maintain by hand, no runtime). (b) ONGOING MULTI-VENDOR USE - actually operate workspace-os from other agents; THIS idea. Realistic ceiling ~80%, and the un-gettable 20% is precise: enforced automation.
  - **The split:** DATA (markdown) + PROCEDURE (what the skills encode) are portable; AUTOMATION/ENFORCEMENT (the hooks) is not. A skill degrades cleanly (its procedure becomes prose/a tool any agent runs); a hook degrades lossily (you can document what it did but cannot reproduce automatic triggering or a hard block without owning the agent lifecycle).
  - **The cross-vendor substrate is MCP** (open standard, consumed by OpenAI/Google/Cursor/etc.), not AGENTS.md. Its three primitives map onto workspace-os: **Tools** = the operations (`ingest_fact`, `memory_lint`, `log_decision`, `search_memory`); **Prompts** = the slash-command ergonomics (`/ingest` equivalent); **Resources** = the index/conventions. Operations layer is ~90% portable via one MCP server. AGENTS.md still carries always-loaded context (prose, soft).
  - **The architecture that avoids a 2x-maintenance second product:** push ALL real logic into vendor-neutral `scripts/` (stdlib python/bash, zero Claude deps), so the Claude plugin, an MCP server, and a bare shell are all THIN adapters over one core. workspace-os is already half-there: `memory_graph.py`, `claude-md-upsert.sh`, `resolve-data-root.sh` are on that bottom row; the gap is that `ingest`/`project-log`/`memory-search` still hold logic in skill prose. Moving that down is the enabling first step and improves the plugin's testability regardless of MCP.
  - **The un-gettable 20% (MCP owns tools, not the agent lifecycle):** SessionStart auto-recall -> a prose/tool-call instruction the agent must choose to obey; PreToolUse guardrail hard-block (exit 2 PREVENTS the action) -> advisory only, because your server does not sit in another client's tool-approval path; PostToolUse auto-lint -> run-on-demand. You can hand another agent the ABILITY to do something, never the guarantee it WILL, or the power to STOP it.
- To start, future-us needs: (1) the scripts-core refactor (extract ingest/project-log/memory-search logic from skill prose into stdlib scripts with CLIs, skills become thin callers); (2) an MCP server exposing those scripts as tools + prompts + the index as a resource; (3) explicit acceptance that hook functions degrade to advisory. Pairs with the near-term portable-artifacts slice (the survival half of the same question). Relates to [[memory-backlinks-search]], [[SP4-meta-onboarding]], [[hook-starter-library]], [[two-tier-memory]].

### two-tier-memory — private authoring source → rendered shared mirror  (keystone 2026-07-05)
- Workstream: memory
- Priority: someday (solo use doesn't need it; becomes real the moment a repo's memory has a second reader)
- Why/context: keystone's memory is two-tier — a private personal source where the maintainer writes freely, rendered to the shared repo `memory/` via a sync manifest (transforms strip private paths / neutralize links on the way out), with **`/ingest backport`** to reconcile mirror-direct edits back into the source and a SessionStart mirror-ahead-of-source guard so a sync never silently clobbers a colleague's edit. Our current model (single-tier `docs/memory/` + `/memory-sync` bridging `~/.claude` auto-memory one fact at a time) is simpler and right for solo repos, but has no answer for a second writer. Borrow the *pattern* (sync manifest + backport + ahead-guard) wholesale from keystone (MIT) if/when needed — don't design it independently.
- To start, future-us needs: a real multi-reader repo to motivate it; then adapt keystone's `sync_memory_to_workspace.py` + ingest-backport + `memory-ingest-guard.sh`/`memory-write-guard.sh` to the `docs/memory/` layout. Relates to [[SP2-memory]], [[memory-backlinks-search]].

### agent-starter-library - preconfigured subagents landed into a project workspace by a command  (brainstorm 2026-08-12)
- Workstream: meta
- Priority: someday
- Intended start: "for future reference" (verbatim; no near-term intent signalled)
- Why/context: the plugin already lands HOOKS into a target repo (the guardrail engine via plugin `hooks.json`; [[hook-starter-library]] stamps per-repo hook templates). Extend the same engine+data / "land artifacts on init" pattern to the SUBAGENT artifact class: a command stamps a curated set of preconfigured subagent definitions (`.claude/agents/*.md`) into a project workspace, so a repo gets a ready agent roster out of the box (e.g. a reviewer, a notebook-surgeon, a schema-discover agent) instead of hand-authoring each. Exact sibling of [[hook-starter-library]] but for the agent artifact class, and feeds [[SP4-meta-onboarding]]'s registry idea (an agents-registry alongside the hooks-registry). Pairs with [[agent-self-improvement]] below, which evolves the landed agents over time.
- To start, future-us needs: an agent-template set + where they live (plugin `templates/agents/` vs a registry), an add-only/idempotent landing command (or a `/project-init` / `/make-portable`-style stamp), and a boundary decision vs SP4's hooks-registry (a parallel agents-registry). Reuse the [[hook-starter-library]] engine/data split. Relates to [[SP4-meta-onboarding]], [[agent-self-improvement]].

### agent-self-improvement - subagent log/memory that promotes to the agent definition over time  (brainstorm 2026-08-12)
- Workstream: memory
- Priority: someday
- Intended start: "for future reference" (verbatim; no near-term intent signalled)
- Why/context: custom subagents are stateless across dispatches - every fresh implementer/reviewer starts cold (as in this repo's own SDD loop). Give each custom subagent a running snapshot log/memory: it records observations/learnings per run; when the store crosses a threshold (~10 items) those items are distilled and PROMOTED into the agent's own definition (its `.md`), so the agent measurably improves over time. A self-improvement loop scoped to a single agent. It is the agent-scoped analog of the memory layer ([[SP2-memory]]) and mirrors [[two-tier-memory]]'s authoring-source -> rendered-mirror shape: the per-run log is the authoring source, the promotion step renders the distilled lesson into the definition. The "10 items -> promote" count is the graduation/compaction heuristic (tunable).
- To start, future-us needs: a per-agent store location + schema (one log per custom agent), a promotion trigger + distillation step (N items -> a summarized edit into the agent definition), and a decision on auto-promote vs confirm-gated (and how to keep promotions add-only so a hand-written definition is never clobbered). Relates to [[SP2-memory]], [[two-tier-memory]], [[memory-backlinks-search]], [[agent-starter-library]].

### memory-volatility-field - re-verification cadence as a first-class axis (type models subject, not volatility)  (feedback 2026-08-12)
- Workstream: schema
- Priority: mid
- Intended start: next time the memory frontmatter schema is touched (design together with the symbol-anchor citation lint)
- Why/context: use-audit feedback (2026-08-12): the `type` field (domain|convention|reference) models SUBJECT, not VOLATILITY. It cannot distinguish a fact stable for years (`scheduling-optimizer.md`) from one pinned to a single production run on one date (`scheduling-model-dimensions-measured.md`) from one citing `file:line` (rots in weeks). Volatility is what should drive re-verification cadence, and today it is invisible to `/memory-lint`. Add a categorical `volatility: stable | measured | pinned` field, or the more concrete `verified-against: <sha> <date>` provenance line, so lint can prioritize what to re-check. The concrete form COMPOUNDS with the citation lint (A-20260812-memory-citation-lint): `verified-against` gives the symbol-anchor check an exact baseline (sha + date) to diff a citation against. A decision-to-make because it forks the frontmatter schema: categorical enum vs concrete `verified-against` line vs both.
- To start, future-us needs: a schema decision (enum vs verified-against vs both) in `conventions/memory.md` frontmatter, then `memory_graph.py` / `/memory-lint` support to sort and report by it. Relates to [[stale-priors-memory]], [[integrity-auditor]], [[memory-backlinks-search]], [[SP2-memory]].

### memory-applies-to-field - branch/repo scoping via frontmatter, not a directory  (feedback 2026-08-12)
- Workstream: schema
- Priority: mid
- Intended start: next time the memory frontmatter schema is touched
- Why/context: use-audit feedback (2026-08-12): the rare genuinely branch-specific fact is already handled well by naming the split INSIDE a shared file (`scheduling-checkout-roles-original-vs-uat.md` does exactly this, and reads better than two divergent copies would). For the remaining cases, an optional `applies-to: <branch|repo>` frontmatter field covers the real need at a fraction of the cost of a per-branch directory, and keeps ONE index. Small, additive, non-breaking (absent = applies to the whole repo). Prefer this over any directory-per-branch scheme.
- To start, future-us needs: add optional `applies-to:` to `conventions/memory.md` frontmatter (default = repo), and decide whether `/memory-lint` surfaces it; no index change. Relates to [[SP2-memory]], [[memory-volatility-field]].
