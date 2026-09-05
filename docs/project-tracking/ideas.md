# Ideas (unscoped / future)

Future intents — captured by `/project-plan`, not started. Scope before acting; promote to
`action-items.md` when an idea goes active. These are the slices that take `workspace-os` from
SP1 (tracking) to the full workspace plugin discussed in the design.


### SP4-meta-onboarding — management + extension layer
- Workstream: meta
- Priority: low (borrow-first per D-20260705-keystone-reposition — do NOT build from scratch)
- Intended start: only once the engine has enough hooks/skills to be worth managing
- Why/context: makes the plugin self-managing and adoptable. Zach's `/workspace` config panel toggles hooks/skills without hand-editing JSON.
- Borrow (keystone 2026-07-05): keystone ships this whole layer, polished — `hooks-registry.json` (each hook's FULL definition, so a disabled hook is always restorable), `manage_hooks.py` (matches by script basename across project/user scopes, `--dry-run` everywhere), `manage_skills.py`/`manage_projects.py`, the `/workspace` panel skill, a `workspace-guide` agent, `examples/blank-module/`. All MIT. Vendor/adapt; our `hooks/guardrail.sh` becomes the first registry entry. See D-20260705-keystone-reposition.
- To start, future-us needs: vendor keystone's registry + manage scripts, adapt paths/idioms to the plugin layout, register the guardrail engine as the first entry.

### portfolio-registry — cross-repo Layer 3
- Workstream: portfolio
- Priority: someday
- Intended start: when a single cross-project view is actually wanted
- Why/context: a registry spanning OA + klapp + future repos (lifecycle, priority, last-touched). Deferred deliberately (YAGNI). Complicated by separate repos — needs a home above them (a command-center repo or the workspace root).
- To start, future-us needs: a decision on where the registry lives given separate repos; then a `projects.md` schema + a `/project-status` portfolio mode that aggregates across repos.
- Borrow (comparison 2026-06-28): reuse Backstage's catalog **entity model** (owner / lifecycle / system / `dependsOn`) for the `projects.md` schema + a per-repo `catalog-info`-style header — don't invent fields; the header also feeds continuity-runbook (shipped) (owner) and provenance-guard (shipped) (ip-class).
- Note (keystone 2026-07-05): keystone's `projects.md` registry solves the *single-workspace* case only; our cross-**separate-repo** portfolio problem remains unsolved there — this idea stays differentiated, not overlap. See D-20260705-keystone-reposition.
- Note (sidecar 2026-07-07): the "where does it live" blocker is answered for the single-workspace case — workspace-level files under `_meta/` root (D-20260707-sidecar-data-layer). Cross-workspace aggregation remains open.
- Note (keystone v0.2.0, 2026-08-28): still single-workspace only (`projects.md` registry + `manage_projects.py`); the cross-separate-repo problem remains unsolved on both sides — differentiation holds.
- Note (2026-08-29): per D-20260829-markdown-stays-canonical, if this builds, a GitHub Projects board is a candidate RENDERER of the registry, never the registry itself; that decision also lists portfolio-registry going active as a mirror re-evaluation trigger.
- Note (market survey 2026-08-28): the lane is opening — OpenSpec "Stores" (beta) does cross-repo planning via a **shared git repo** (= the `_meta/` sidecar pattern with a remote; a candidate answer to the remaining where-does-it-live blocker), and gstack's GBrain puts per-repo **trust tiers** on cross-repo knowledge (`ip_class` thinking applied to the memory tier — adopt that concept if this builds). Two mainstream moves in one season is the demand signal this idea was parked to wait for.

### engine-hooks — automated upkeep
- Workstream: workflow
- Priority: low
- Intended start: after the core skills see real use
- Why/context: keep the journal honest without manual discipline.
- **Shipped (2026-07-05, partial):** the CI/pre-commit link-guard mechanism exists — `scripts/memory_graph.py --check` fails on broken wikilinks / index-parity drift (vendored from keystone; see `resolved.md` A-20260705-memory-graph-vendor). Remaining: wiring `--check` into *target repos'* CI/pre-commit (a `/project-init` or `/guardrails` concern), and the `Stop` hook nudge.
- **Shipped (2026-08-13, the capture nudge):** a scoped SessionStart hook (`hooks/capture-cadence.sh`) injects a proactive, batch-at-boundaries capture cadence in workspace-os repos, paired with making the capture skills model-invocable. See `resolved.md` A-20260812-proactive-capture-cadence. Remaining: the `Stop`-hook variant and target-repo CI wiring of the `--check` gate.
- To start, future-us needs: a `Stop` hook nudging "log what you decided this session," and target-repo wiring for the `--check` gate.


### leakage-audit-skill — reusable ML leakage checklist  (brainstorm 2026-06-28)
- Workstream: skills
- Priority: mid
- Intended start: alongside real DS use (work clean-room + Options Analyzer)
- Why/context: leakage discipline is the user's strongest evidenced DS signal (past-only lags, train-only fits, no post-outcome features, a train/serve feature-parity test). The 30/60/90 ramp plan literally lists "establish a team leakage-checklist standard." Codify it as a runnable pre-ship `/leakage-audit` checklist skill — portable across the work clean-room and OA, and a concrete mentorship/team-standard artifact.
- To start, future-us needs: the checklist content (lifted from the user's existing leakage practices) + a `SKILL.md`. Relates to [[model-decision-log]], provenance-guard (shipped).

### integrity-auditor — tracking/memory integrity check (free default + dormant cloud tiers)  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: mid
- Intended start: after the core skills see real use (the cloud-cron sibling of [[engine-hooks]])
- **Shipped (2026-09-04, the Tier 0 auditor — v0.36.0, PR #47):** `memory_graph.py --audit-tracking`
  (duplicate/invalid record IDs, dangling references, placeholder-beside-records, append-only
  shrink vs a git baseline; duplicate lines as WARN), wired into /memory-lint, the ship-a-slice
  close-out, CI, and this repo's own guardrails.json as a predicate-gated deny on `git commit`.
  See `resolved.md` A-20260904-integrity-auditor and
  D-20260904-tracking-audit-in-graph-script-gated-commit. **Remaining:** only the dormant
  cloud-cron LLM tiers (Tier 1 OAuth / Tier 2 API) — likely moot under
  D-20260828-build-only-what-native-wont; decide, don't build by default.
- **Shipped (2026-08-12, the memory/tracking boundary check):** `memory_graph.py --check-tracking` flags tracking records over ~40 lines or carrying a `**MEASURED**` block (measured evidence belongs in memory, not a record body); the boundary is documented in `conventions/project-tracking.md` and wired into `/memory-lint`. See `resolved.md` A-20260812-memory-hygiene-lints. Remaining: the ID-uniqueness/index-parity/duplicate-line auditor + the dormant cloud-cron tiers.
- Why/context: the append-`union` tracking + memory files silently lose or duplicate entries on bad merges — `conventions/project-tracking.md` already flags "periodically scan for duplicate lines." Zach's `claude-weekly-audit.yml` productizes this as a scheduled cross-PR pass over `master` that names exactly these files (decisions-log, action-items, MEMORY.md) and files findings as a GitHub issue. **Cost framing (verified 2026-06-28):** the headline checks are deterministic — ID uniqueness/monotonicity, index↔file parity, duplicate-line detection — so the **default ships free as a local/in-session script or hook (Tier 0, no LLM)**; an LLM pass is reserved only for the fuzzy residual ("content moved but not landed", semantic regressions). Cloud tiers are opt-in/dormant: Tier 1 bills a Claude Pro/Max OAuth token (`claude_code_oauth_token`); Tier 2 bills Anthropic API credits. GitHub Copilot is **not** a cheaper substitute: as of 2026-06-01 Copilot moved to usage-based AI-Credits + Actions-minutes billing, its code review is PR-diff-scoped (covers a per-PR reviewer, not this cross-PR audit) and is excluded from the Free plan (needs ≥ Pro at $10/mo). Borrow Zach's hardening for any cloud tier: dormant-by-default (no-op until a secret exists), pinned action SHA, and a fail-loud cost/error guard (his caught ~50 PRs that merged "green but unreviewed" on a dead key).
- To start, future-us needs: the deterministic auditor script (ID/index/dup checks) + `Stop`/pre-PR hook wiring; optionally dormant CI workflow templates for the LLM/cloud tiers. Relates to [[engine-hooks]].

### project-doctor — verify a repo's setup/runtime preconditions  (brainstorm 2026-06-28)
- Workstream: workflow
- Priority: mid
- Intended start: after continuity/onboarding pieces land (overlaps existing ideas — flag, don't rush)
- Why/context: klapp's `RUNNING.md` is a manual setup checklist (Docker up, `.env` set, `prisma migrate dev`, seed run); OA's guardian checks data freshness. Generalize to a `/doctor` skill: each repo declares its preconditions (env vars present, services up, deps installed, data fresh) and the skill reports PASS/FAIL — turning a prose runbook into an executable check, and giving continuity-runbook (shipped) an automated counterpart. Overlaps [[integrity-auditor]] (data/tracking checks) and [[SP4-meta-onboarding]] (onboarding) — keep scoped to *environment/runtime preconditions* to stay distinct.
- To start, future-us needs: a per-repo checks declaration (where + schema) + a `/doctor` skill that runs them; decide the boundary vs integrity-auditor (preconditions vs data/tracking integrity). Relates to continuity-runbook (shipped), [[integrity-auditor]].
- Borrow (comparison 2026-06-28): adopt DVC's declarative **deps→outs** mindset for the checks declaration (each precondition = an input the repo asserts).

### memory-backlinks-search — backlinks + search + note templates for the memory layer (from Notion/wikis)  (comparison 2026-06-28)
- Workstream: memory
- Priority: mid
- Intended start: extend `/memory-lint` incrementally
- Why/context: the memory layer already has `[[wikilinks]]` + an index but no **backlink view** and no **search** beyond grep — the two things wikis/Notion do well. Add (1) backlink awareness to `/memory-lint` (or a `/memory-search`) that, for a given fact, lists what links *to* it; (2) lightweight **note templates** for recurring memory flavors (the stale-priors-memory (shipped) gotcha type is the first); (3) optionally Notion-style **property views** over facts (by type/tag). Closes the wiki gap while keeping memory git-native + agent-loaded (the thing Notion can't do).
- **Shipped (2026-07-05, the graph half):** the vendored `scripts/memory_graph.py` (from keystone, MIT) derives the whole link graph — per-note neighbors/degree (the backlink data), orphans, weakly-linked, hubs, `--json` export — and is now `/memory-lint`'s deterministic pass. See `resolved.md` A-20260705-memory-graph-vendor. Remaining: a user-facing `/memory-search`/backlink *view* over that data, and the note-templates set.
- **Shipped (2026-07-23, the search/backlink view):** `scripts/memory_graph.py` gained `--search QUERY` (name + description substring) and `--backlinks NODE` (LINKS OUT + BACKLINKS from the wikilink graph), surfaced by the new `/memory-search` skill. See `resolved.md` A-20260723-memory-search and `decisions-log.md` D-20260723-memory-search-scope. Remaining: the note-templates set, and the optional property-views by type/tag.
- **Shipped (2026-07-27, the note-templates half - gotcha flavor):** `/ingest gotcha:` captures a stale-prior and routes it via the boundary test - a confirmed imperative bullet in a managed CLAUDE.md section (in-repo only, via the idempotent `scripts/claude-md-upsert.sh`) or a `docs/memory/` fact with the gotcha body shape; the flavor is documented in `conventions/memory.md` § Recurring flavors. See `resolved.md` A-20260727-ingest-gotcha and `decisions-log.md` D-20260727-ingest-gotcha-claudemd. Remaining: the optional property-views by type/tag.
- **Shipped (2026-08-12, citation-freshness lint):** `memory_graph.py --check-citations` verifies `file:NNN` and `` `path::symbol` `` citations against the source tree (definition-block containment; nearby non-definition tokens are UNANCHORED not stale; ambiguous basenames flagged), wired into `/memory-lint`. See `resolved.md` A-20260812-memory-hygiene-lints. Pairs with the captured memory-volatility-field (shipped) (`verified-against` would give it an exact baseline).
- To start, future-us needs: a `/memory-search` entrypoint reading `memory_graph.py --json` output, a templates set; decide whether templates live in the plugin or `docs/memory/`. Relates to SP2-memory (shipped), stale-priors-memory (shipped), tracking-skills-roundout (shipped).

### keystone-module-guardrails — package the guardrail engine as a keystone utility module  (keystone 2026-07-05)
- Workstream: meta
- Priority: low (backburnered 2026-07-05 by user — solo workspace-os slices first; revisit when a conversation with Zach happens)
- Intended start: after a conversation with Zach (PR #8 prerequisite already merged)
- Why/context: Zach shared his `zachburke9/keystone-*` ecosystem (engine / catalog / instance-template / 3 modules, private, MIT) on 2026-07-02 — a domain-neutral workspace OS with a module catalog + importer (`catalog.json` + `import_module.py`, vendored copies, `module.json` version-compat seam). The 2026-07-05 comparison (D-20260705-keystone-reposition) found keystone has **no policy-enforcement layer**: its hooks are advisory/protective, none declaratively configurable per repo. Our guardrail engine (declarative `.claude/guardrails.json` deny/warn rules + `ip_class` provenance tripwires, tested) fills that hole exactly, and fits his extension contract (a `kind: utility` module whose hook registers into his `hooks-registry.json` panel). Turns duplicated effort into collaboration; we keep authorship + the plugin distribution channel for our own repos.
- To start, future-us needs: Zach's buy-in; a `module.json` (`kind: utility`, `provides.hooks`); a thin keystone-shaped wrapper around `hooks/guardrail.sh` + `templates/guardrails.json`; a registry entry for his `/workspace` panel. Relates to hook-starter-library (shipped), provenance-guard (shipped), [[SP4-meta-onboarding]].
- Refresh (keystone v0.2.0, 2026-08-28): de-risked — the extension contract is now concrete (marketplace `git-subdir` → the module repo's `plugin/` subtree; `module.json` at root with the enforced `depends_on.engine` semver gate; hooks hand-registered into `hooks-registry.json` — his own team module ships dormant/unregistered, so dormant-by-default is the norm). v0.2.0 still has no policy-enforcement layer; the fit is unchanged. Wrapper est. ~a day once buy-in exists. Compounds with policy-packs (active as A-20260828-policy-packs; our engine + a starter pack beats the bare engine as a contribution).
- Note (2026-08-28): policy-packs shipped v0.27.0 — the "engine + starter pack" contribution shape now exists (packs/enterprise-clean-room.json is the demonstrator); the keystone wrapper remains gated on Zach's buy-in.

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
- To start, future-us needs: (1) the scripts-core refactor (extract ingest/project-log/memory-search logic from skill prose into stdlib scripts with CLIs, skills become thin callers); (2) an MCP server exposing those scripts as tools + prompts + the index as a resource; (3) explicit acceptance that hook functions degrade to advisory. Pairs with the near-term portable-artifacts slice (the survival half of the same question). Relates to [[memory-backlinks-search]], [[SP4-meta-onboarding]], hook-starter-library (shipped), [[two-tier-memory]].

### two-tier-memory — private authoring source → rendered shared mirror  (keystone 2026-07-05)
- Workstream: memory
- Priority: someday (solo use doesn't need it; becomes real the moment a repo's memory has a second reader)
- Why/context: keystone's memory is two-tier — a private personal source where the maintainer writes freely, rendered to the shared repo `memory/` via a sync manifest (transforms strip private paths / neutralize links on the way out), with **`/ingest backport`** to reconcile mirror-direct edits back into the source and a SessionStart mirror-ahead-of-source guard so a sync never silently clobbers a colleague's edit. Our current model (single-tier `docs/memory/` + `/memory-sync` bridging `~/.claude` auto-memory one fact at a time) is simpler and right for solo repos, but has no answer for a second writer. Borrow the *pattern* (sync manifest + backport + ahead-guard) wholesale from keystone (MIT) if/when needed — don't design it independently.
- To start, future-us needs: a real multi-reader repo to motivate it; then adapt keystone's `sync_memory_to_workspace.py` + ingest-backport + `memory-ingest-guard.sh`/`memory-write-guard.sh` to the `docs/memory/` layout. Relates to SP2-memory (shipped), [[memory-backlinks-search]].

### agent-starter-library - preconfigured subagents landed into a project workspace by a command  (brainstorm 2026-08-12)
- Workstream: meta
- Priority: someday
- Intended start: "for future reference" (verbatim; no near-term intent signalled)
- Why/context: the plugin already lands HOOKS into a target repo (the guardrail engine via plugin `hooks.json`; hook-starter-library (shipped) stamps per-repo hook templates). Extend the same engine+data / "land artifacts on init" pattern to the SUBAGENT artifact class: a command stamps a curated set of preconfigured subagent definitions (`.claude/agents/*.md`) into a project workspace, so a repo gets a ready agent roster out of the box (e.g. a reviewer, a notebook-surgeon, a schema-discover agent) instead of hand-authoring each. Exact sibling of hook-starter-library (shipped) but for the agent artifact class, and feeds [[SP4-meta-onboarding]]'s registry idea (an agents-registry alongside the hooks-registry). Pairs with [[agent-self-improvement]] below, which evolves the landed agents over time.
- To start, future-us needs: an agent-template set + where they live (plugin `templates/agents/` vs a registry), an add-only/idempotent landing command (or a `/project-init` / `/make-portable`-style stamp), and a boundary decision vs SP4's hooks-registry (a parallel agents-registry). Reuse the hook-starter-library (shipped) engine/data split. Relates to [[SP4-meta-onboarding]], [[agent-self-improvement]].

### agent-self-improvement - subagent log/memory that promotes to the agent definition over time  (brainstorm 2026-08-12)
- Workstream: memory
- Priority: someday
- Intended start: "for future reference" (verbatim; no near-term intent signalled)
- Why/context: custom subagents are stateless across dispatches - every fresh implementer/reviewer starts cold (as in this repo's own SDD loop). Give each custom subagent a running snapshot log/memory: it records observations/learnings per run; when the store crosses a threshold (~10 items) those items are distilled and PROMOTED into the agent's own definition (its `.md`), so the agent measurably improves over time. A self-improvement loop scoped to a single agent. It is the agent-scoped analog of the memory layer (SP2-memory (shipped)) and mirrors [[two-tier-memory]]'s authoring-source -> rendered-mirror shape: the per-run log is the authoring source, the promotion step renders the distilled lesson into the definition. The "10 items -> promote" count is the graduation/compaction heuristic (tunable).
- To start, future-us needs: a per-agent store location + schema (one log per custom agent), a promotion trigger + distillation step (N items -> a summarized edit into the agent definition), and a decision on auto-promote vs confirm-gated (and how to keep promotions add-only so a hand-written definition is never clobbered). Relates to SP2-memory (shipped), [[two-tier-memory]], [[memory-backlinks-search]], [[agent-starter-library]].

### memory-restamp-flow — /memory-lint offers to re-stamp a re-verified fact  (spec deferral 2026-08-19)
- Workstream: memory
- Priority: mid
- Intended start: after UNVERIFIED-SINCE has produced findings on a real base
- Why/context: UNVERIFIED-SINCE tells you a fact's cited code moved after its `verified-against`
  sha, but the fix is manual: re-read the code, decide the claim still holds, hand-edit the sha and
  date. That last step is mechanical and easy to skip, and a skipped re-stamp leaves the fact
  reported forever, which trains people to ignore the bucket. A confirm-gated re-stamp
  (`/memory-lint` proposes `sha -> HEAD, date -> today` per confirmed fact) closes the loop. Held
  back from the v0.21.0 slice deliberately: build the signal first, then automate responding to it
  once we know how often it actually fires.
- To start, future-us needs: a decision on whether re-stamping is per-fact confirm or a batch, and
  whether `/memory-lint` (read-only today for the citation pass) should gain a write path at all.
  Relates to memory-provenance-fields (shipped).

### deliverable-provenance — bind a published figure to the fact or run that produced it  (EC2 audit 2026-08-24)
- Workstream: memory
- Priority: mid
- Intended start: when a deliverable first goes stale in a way that matters
- Why/context: `_meta/visuals/` dashboards and `_meta/briefings/` decks go to a VP. There are
  critical passes over them (an `htmlcheck.py`, a `dashboard-reviewer` agent) but nothing binds a
  figure on a page to the fact or run that produced it, so when a fact is revised no artifact knows
  it is now stale. A claim-to-source stamp per figure, plus a lint flagging deliverables whose
  backing facts changed since publication, is the productive counterpart to the reviewer agent. A
  second mode (generate explainers only from sourced facts, refusing unsourced claims) serves the
  teach-back half of the job directly. Note this is the same shape as the shipped `verified-against`
  field, one layer out: there it binds a fact to code, here it binds a deliverable to a fact.
- To start, future-us needs: the stamp format (inline comment? sidecar manifest?), and a decision on
  whether the lint reads rendered HTML or the generator's inputs.

### fact-reverification-runner — store the command that established a fact, then re-run and diff  (EC2 audit 2026-08-24)
- Workstream: memory
- Priority: mid
- Intended start: after UNVERIFIED-SINCE has fired on a real base (same gate as [[memory-restamp-flow]])
- Why/context: v0.21.0 shipped the *label* half of freshness (`verified-against: <sha> <date>` and
  the advisory UNVERIFIED-SINCE bucket), which answers "has the cited code moved since anyone
  confirmed this?" It does not re-confirm anything: the fix is still a human re-read. But many facts
  in the real base were established by a **deterministic command** (an `sfq.py` query, a
  `run_diff.sh`, a grep), so re-verification is mechanizable rather than a re-read. Store the
  establishing command in the fact, re-execute it, diff against the recorded result. This is the
  third strand of one thread: `verified-against` is the label, [[memory-restamp-flow]] closes the
  loop by hand, this closes it automatically where a command exists.
- To start, future-us needs: a frontmatter field for the establishing command, a decision on whether
  re-execution is ever automatic (running arbitrary stored shell on a lint pass is a real hazard, so
  it likely must be explicit and confirm-gated), and a way to record the expected result to diff
  against.

### lint-conversational-authoring — decide lint.json's future (author, fold, or retire)  (EC2 audit 2026-08-24)
- Workstream: workflow
- Priority: mid
- Intended start: after /guardrails has real-use evidence
- Why/context: the advisory lint hook scored 1/10 in the EC2 audit — the same hand-authored-JSON disease as guardrails (zero `.claude/lint.json` in any real workspace). But the right fix may differ: capture the QUESTION (conversational authoring like /guardrails, fold linting into the guardrail engine, or retire the hook) rather than presuppose a build. D-20260824-guardrails-canonical-hookify-misfits settles the guardrail half only.
- To start, future-us needs: /guardrails adoption evidence (did conversational authoring actually light up the dark surface?), then a short decision spec across the three options.

### transcript-mining-ingest — batch-mine session transcripts for uncaptured facts  (market survey 2026-08-28)
- Workstream: memory
- Priority: low
- Intended start: opportunistic, after the roundout
- Why/context: capture today is proactive-in-session (capture-cadence hook + model-invocable
  skills), but whatever slips past a session is gone. claude-memory-compiler (~1.3k★) runs a
  nightly "compiler" over session logs producing cross-referenced knowledge articles; the
  transferable half is the *mining*, not the compiling — a batch mode that reads recent transcripts
  (`~/.claude/projects/<project>/`), extracts uncaptured decision/fact-shaped moments, and proposes
  them as `/ingest` / `/project-log` candidates. Confirm-gated like every capture skill — the
  proposal batch is the output, never direct writes.
- To start, future-us needs: transcript format handling, a dedupe pass against existing
  facts/records, and cost bounds (mining is LLM work — relates to dispatch-ledger (shipped)'s cost
  discipline). Relates to [[integrity-auditor]] (same batch-cadence shape).

### memory-lint-hardening — path-existence + contradiction checks  (market survey 2026-08-28)
- Workstream: memory
- Priority: low
- Intended start: path-existence fits any memory_graph.py touch (an afternoon); contradiction pass with the next /memory-lint slice
- Why/context: two survey borrows, one deterministic and one judged. (a) agents-lint verifies that
  file paths referenced in memory/instruction files actually exist — cheap, deterministic, catches
  "a stale fact names a dead file", and belongs in `memory_graph.py --check`. (b)
  claude-memory-compiler's linter includes a fact-vs-fact **contradiction** check — LLM-judged, so
  it belongs in the `/memory-lint` skill layer, never the deterministic script (same
  script-vs-judgment split the plugin already uses everywhere).
- To start, future-us needs: (a) a path-reference extractor + existence check with an opt-out for
  illustrative paths; (b) a contradiction-pass prompt shape and where its findings land (advisory
  bucket like UNVERIFIED-SINCE?). Relates to [[fact-reverification-runner]],
  [[memory-restamp-flow]].

