# Decisions Log

Append-only record of *why* we chose X. Added by `/project-log decision` with a `D-YYYYMMDD-slug`
ID. Never rewrite history — only add. Records use the decision template from the conventions doc.

### D-20260626-repo-canonical-memory — repo `docs/memory/` is canonical shared memory; auto-memory is an optional bridge
- Workstream: memory
- Created: 2026-06-26
- Rationale: workspace-os is a general plugin (solo or team, with or without harness auto-memory); the universal store is the repo itself, not a personal `~/.claude`. klapp is collaborative, so shared knowledge must travel with the repo. Inverts the colleague's personal→mirror direction. "Reconcile, don't duplicate" is an operational test — costly-if-unseen → CLAUDE.md, else → `docs/memory/`. Retrieval = import the index only.
- Spawns: A-20260626-sp2b-memory-roundout

Full design: `docs/specs/2026-06-26-sp2-memory-design.md`. Plan: `docs/plans/2026-06-26-sp2-memory.md`.

Closes `SP2-memory` (idea COMPLETE: SP2a + SP2b shipped; resolved.md A-20260626-sp2a-memory-core, A-20260626-sp2b-memory-roundout).

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

Closes adoption-import (idea COMPLETE: all four source types — free-form docs + CLAUDE.md v0.3.0,
tracking docs v0.4.0, instruction-file class v0.5.0, git history v0.12.0, foreign memory stores
v0.30.0 /memory-adopt foreign).


### D-20260627-memory-adopt-claudemd-scope — "never migrate CLAUDE.md" scoped to the passive default
- Workstream: memory
- Created: 2026-06-27
- Rationale: the live klapp dogfood surfaced a contradiction in `conventions/memory.md` — the boundary-rule line "Never migrate existing CLAUDE.md content into memory" read as a blanket ban, contradicting `/memory-adopt`'s own purpose (reshape an overgrown CLAUDE.md) and its trim rule (Adopting existing docs §). Scoped that line to the **passive default** (`/project-init` + day-to-day work): never bulk-migrate; the explicit opt-in `/memory-adopt` is the one exception, extracting non-costly *reference* lines only with confirmation. Trim feature retained. User design call at the dogfood gate.
- Spawns: none

### D-20260627-tracking-adopt-design — /tracking-adopt is a standalone docs-only sibling of /memory-adopt
- Workstream: skills
- Created: 2026-06-27
- Rationale: tracking adoption is its own skill (not a /memory-adopt mode) — one skill, one target. Slice 1 is docs-only, routing roadmaps→ideas, recorded decisions→decisions-log (D-), open TODOs→action-items (A-). resolved.md + git-history archaeology deferred to slice 2 (a merged-PR commit ref makes a resolved record legitimate; prose changelog does not). Reuses conventions/project-tracking.md gates — no new schema. Source docs read-only.
- Spawns: A-20260627-tracking-adopt

### D-20260628-stay-private — keep workspace-os private for now
- Workstream: packaging
- Created: 2026-06-28
- Rationale: Public would give frictionless install (no auth/SSH dance), but the user prefers to keep the repo private and reassess later. Public is read+install-for-anyone / write-for-owner-only and exposes all git history permanently; the user wants to weigh that deliberately, not as a side effect of the packaging sweep. The branch rename and CI are independent of visibility and proceed regardless. Reversal is one `gh repo edit --visibility public` away.
- Spawns: D-20260628-ci-advisory

### D-20260628-ci-advisory — meta-CI is advisory, not an enforced merge gate
- Workstream: packaging
- Created: 2026-06-28
- Rationale: The plan called for branch protection requiring the `validate` check on `main`, but both the classic branch-protection API and the newer rulesets API return `403: Upgrade to GitHub Pro or make this repository public` — GitHub's free plan does not offer branch protection for *private* repos. Given the stay-private decision (D-20260628-stay-private), the user chose advisory CI: the workflow runs on every PR/push to `main` and reports red on failure, but does not block merge. As a solo maintainer the signal is still seen before merging. Revisit enforcement if the repo later goes public or upgrades to Pro.
- Spawns: none

### D-20260628-memory-adopt-instruction-file-class — /memory-adopt treats CLAUDE.md + AGENTS.md + @import targets as one trimmable class
- Workstream: skills
- Created: 2026-06-28
- Rationale: trimming CLAUDE.md reduces always-loaded context once knowledge lives in on-demand memory; `@import` targets and `AGENTS.md` are *also* always-loaded (Claude Code via import; sibling agents respectively), so the same rationale and trim rule apply. `@import`s are resolved recursively (cycle-guarded, depth cap 5, repo-relative only) to match how the content is actually loaded. Free-form docs stay read-only.
- Spawns: A-20260628-memory-adopt-hardening

Closes `adoption-import` sub-slices (c) + (d). Spec: `docs/specs/2026-06-28-memory-adopt-hardening-design.md`.

### D-20260701-guardrail-engine — one guardrail engine, two rule packs (warn-only defaults; deny=exit 2)
- Workstream: workflow
- Created: 2026-07-01
- Rationale: folded hook-starter-library + provenance-guard into ONE portable PreToolUse engine + per-repo `.claude/guardrails.json` (engine/data split, no external-plugin dependency — the "carry the engine job-to-job" premise rejects that coupling). Built-in defaults are warn-only so they never conflict with the user's global `~/.claude/hooks/guard.sh` (which already hard-denies secrets + asks on destructive); workspace-os's value-add is the declarative per-repo rules + provenance `ip_class`, not re-shipping generic denies. Only high-confidence secret patterns deny. `.env`/generic secrets warn (a hard deny bites `.env.example`, local `.env`, fake-key fixtures). deny=exit 2 + stderr (reason fed to Claude); warn=`{"systemMessage": reason}` JSON on stdout + exit 0 (the documented user-facing warning channel, verified against the Claude Code hooks docs — warns deliberately avoid `additionalContext` so routine edits don't pollute Claude's context). Retired `memory-secret-guard.sh` into the engine (broadened docs/memory→all writes). Deferred: PostToolUse lint template, `/guardrails` skill, `project-init` wiring.
- Spawns: A-20260701-guardrail-engine

Full design: `docs/specs/2026-07-01-guardrail-engine-design.md`. Plan: `docs/plans/2026-07-01-guardrail-engine.md`.

Closes `provenance-guard` (idea COMPLETE: the `ip_class` tag + tripwire rules pack ship via this engine, and the standalone `security-patterns.yaml` route was dropped here — the hook-vs-plugin delivery question this idea was waiting on).

### D-20260705-keystone-reposition — reposition workspace-os as the enforcement/adoption layer; borrow-first on keystone overlap
- Workstream: meta
- Created: 2026-07-05
- Rationale: Zach shared his `zachburke9/keystone-*` ecosystem (engine v0.0.1 + catalog + instance-template + hospitality/team/companion modules; private, MIT) on 2026-07-02. A full deep-dive comparison (2026-07-05) found keystone already ships workspace-os's SP3/SP4/tracking-roundout roadmap, extracted from his production workspace — rebuilding those is now negative-value work against a moving target. But the seam is clean and complementary: keystone owns knowledge-side machinery (two-tier memory + graph, module/catalog distribution, written operating models) and has NO policy-enforcement layer; workspace-os owns enforcement (declarative guardrail engine + `ip_class` provenance wall), rigorous opt-in adoption, and the better engine-update model (marketplace plugin vs his fork-on-day-one starter / cp-r drop-in). Decision: (1) overlap ideas (SP3-finish-task, SP4-meta-onboarding, tracking-skills-roundout) demoted to borrow-first — adapt his MIT artifacts, never author from scratch; (2) workspace-os's build effort concentrates on its differentiated core (guardrails/provenance, adoption, cross-repo portfolio); (3) vendor keystone's `memory_graph.py` as `/memory-lint`'s deterministic backbone (first borrow, A-20260705-memory-graph-vendor); (4) new idea `keystone-module-guardrails` — publish our guardrail engine into his catalog as a `kind: utility` module rather than competing.
- Spawns: A-20260705-memory-graph-vendor

Ideas reconciled the same day: SP3-finish-task + SP4-meta-onboarding + tracking-skills-roundout (borrow-first notes), engine-hooks + decision-status + memory-backlinks-search (partial ships via the vendor), continuity-runbook + portfolio-registry (keystone notes), new keystone-module-guardrails + two-tier-memory.

### D-20260705-decision-status-append-only — decision Status/supersession lands as append-only lines, not edits
- Workstream: schema
- Created: 2026-07-05
- Status: accepted
- Consequences: pre-schema D- records are grandfathered (no Status line = accepted); tracking-file wikilinks stay human-contract (memory_graph lints docs/memory only)
- Spawns: A-20260705-decision-status
- Rationale: the decisions log's core invariant is append-only ("never rewrite history"), so superseded state cannot be a Status-line edit. Instead: `Status: accepted` is written once at creation and never touched; supersession = a NEW decision carrying `Supersedes: [[supersedes::D-old]]` plus exactly one line appended to the old record (`- Superseded-by: [[superseded_by::D-new]]`), and the read rule "Superseded-by wins over Status" makes live-vs-dead readable per record without edits. Predicates reuse memory's typed-wikilink vocabulary (D-20260705-keystone-reposition's typed-edge ship) — one vocabulary across tracking and memory, not two.

Closes `decision-status` (idea COMPLETE: the link half and the status half both shipped, v0.8.0).

### D-20260705-continuity-home-root — CONTINUITY.md lives at the repo root, as a human doc, pointer-only from CLAUDE.md
- Workstream: workflow
- Created: 2026-07-05
- Status: accepted
- Consequences: /continuity scaffolds at root; the CLAUDE.md line is a pointer, not an @import (the doc must not load every session — it's for a human stranger, not the model)
- Spawns: A-20260705-continuity-runbook
- Rationale: a bus-factor runbook's single job is to be found by someone who doesn't know the repo — that argues for README-sibling visibility over docs/ tidiness (the idea had flagged root-vs-docs as the open decision). Kept out of the always-loaded context: unlike memory, its audience is a human during an incident, and its content (hosts, cadences, owner names) is dead weight in every model session. Template generalizes the westgate CONTINUITY.md *shape* only (five sections + TODO(owner) convention — patterns, no proprietary content, per the standing reference-repo rule), plus the 2026-06-28 borrow notes: DVC deps→outs framing and a Backstage-style Owner column on the obligations table.

Closes `continuity-runbook` (idea COMPLETE: `templates/CONTINUITY.md` + `/continuity`, v0.9.0).

### D-20260706-model-log-run-layer — model decisions stay in project-log; the run layer is tracker-first with an in-repo ledger fallback
- Workstream: schema
- Created: 2026-07-06
- Status: accepted
- Consequences: workspace-os never becomes a worse MLflow — no per-run auto-logging machinery; the MODEL_LOG ledger is convention-driven (manual rows, evaluated candidates only) and merge=union like the other ledgers
- Spawns: A-20260706-model-decision-log
- Rationale: deliberated whether model logging should be its own layer tracking every build (hyperparams/metrics, JSON-style) or live under project-log. Resolution: split by altitude. Per-build inputs+metrics are RUN-level data — an experiment tracker's job (MLflow/W&B/SageMaker), and git already records what changed when configs live in the repo, so a build log's unique contribution is only the association sha → headline metrics → verdict. Decision-level REASONING (architecture choice, validation protocol, champion/challenger promotion) stays a decisions-log template variant with a `Run:` pointer — same D- IDs, supersession protocol gives model lineage for free. For tracker-less environments (locked-down laptop, small project) the fallback is `templates/MODEL_LOG.md` → `docs/models/<name>.md`: an append-only markdown table (Date | Build sha | What changed | Headline metrics | Verdict), one row per evaluated candidate, which the `Run:` field may point at instead of a tracker run. Markdown over JSON deliberately: the consumer is a human reading diffs/PRs, not a program.

### D-20260707-sidecar-data-layer — sidecar mode: a marked workspace `_meta/` holds the data layer for enterprise repos
- Workstream: meta
- Created: 2026-07-07
- Status: accepted
- Consequences: "where does the data live" becomes resolved (one script), not assumed; ARCHITECTURE.md layer-2 wording ("per-repo, version-controlled") needs updating at implementation; partially answers portfolio-registry's "home above the repos" for the single-workspace case
- Spawns: A-20260707-sidecar-data-layer
- Rationale: the new-job context breaks the in-repo data assumption three ways — personal tracking/memory artifacts can't be committed to enterprise repos, untracked in-tree files risk contaminating PRs, and the data must still persist locally with history. Options weighed: (A) workspace sidecar `_meta/` meta-repo (chosen), (B) hidden central sidecar under `~/.claude` keyed by repo-path slug (rejected: couples data to harness internals, slug breaks on repo moves), (C) in-repo + `.git/info/exclude` (rejected: `git clean -dfx`/re-clone destroys data — fails persistence). Mode rule: **sidecar always wins in a marked workspace** (`_meta/workspace.json` is the switch) — one machine-level declaration, no per-repo config drift; unmarked machines are byte-identical to today, so personal projects keep in-repo mode. `_meta/` is a git repo with no remote: full local history/recovery without pushing anywhere (the local-only constraint). Repos keyed by folder name. Resolution logic lives once in `scripts/resolve-data-root.sh`; skills consume its output and never compute data paths. Spec: docs/specs/2026-07-07-sidecar-data-layer-design.md.

### D-20260711-tracking-adopt-git-design — /tracking-adopt git mode mines history into resolved.md only, prose-driven
- Workstream: skills
- Created: 2026-07-11
- Status: accepted
- Consequences: the SoT's completed-route "skip for now / later slice" wording is replaced; decision/action mining from history remains deferred and must be re-scoped if ever wanted
- Spawns: A-20260711-tracking-adopt-git
- Rationale: slice 2 of adoption-import ships the one route slice 1 couldn't — resolved.md — because git supplies the real `Commit:` ref prose lacks. Scope deliberately narrowed to that single route: decision mining from commit prose is fuzzy (most commits aren't decisions) and open-branch→action inference is noisy; both stay deferred. One record per merged unit (merge commit / squash-PR commit / model-grouped direct commits), bounded default (newest tag, else last ~30 units) with a range override, opportunistic-never-required gh enrichment, and doc-completed `- [x]` items cross-matched to mined units (matched → enrich the one record; unmatched → stay skipped, preserving "prose doesn't legitimize a resolved record"). Dedup keys on the SHA/PR#, which also dedups against organic `/project-log done` records. Delivery is pure SKILL.md prose (no helper script): the mining is 2–3 reproducible `git log` shapes; the hard part is judgment, which a script can't own.

Full design: `docs/specs/2026-07-11-tracking-adopt-git-design.md`.

### D-20260713-lint-hook — PostToolUse advisory-lint is a separate hook feeding additionalContext, pure opt-in
- Workstream: workflow
- Created: 2026-07-13
- Status: accepted
- Consequences: closes `hook-starter-library` (last sub-slice); the engine ships no linters, so a repo with no `.claude/lint.json` is byte-identical in behavior to today; the whole-file/any-diagnostic rule may surface pre-existing or mid-refactor-transient diagnostics (accepted for simplicity; diff-scoping deferred)
- Spawns: A-20260713-lint-hook
- Rationale: the guardrail spec deferred this as a "separate hook, separate concern" — confirmed: it must be PostToolUse (lint runs after the edit lands), so it cannot fold into the PreToolUse `guardrail.sh`. Channel is `additionalContext` (nested under `hookSpecificOutput`, `hookEventName:"PostToolUse"`, exit 0 — confirmed against the Claude Code hooks docs), the deliberate opposite of the guardrail's `systemMessage`: lint output is for the model to act on, guardrail warns are for the user. No built-in linters (unlike the guardrail's warn-only defaults) because a linter executes external tooling that may be absent and is repo-specific — the hook stays inert until a repo opts in. Config lives in its own `.claude/lint.json`, not `guardrails.json`: PreToolUse security-blocking and PostToolUse quality-advice are different concerns with different lifecycles. Opt-in = explicit config (not auto-detection); injection = whole edited file, any diagnostic (not diff-scoped) — matches the OA hook this generalizes. Sidecar fallback (`_meta/<repo>/lint.json`) mirrors the guardrail so enterprise repos keep lint config out of tree.

Full design: `docs/specs/2026-07-13-lint-hook-design.md`. Plan: `docs/plans/2026-07-13-lint-hook.md`.

Closes `hook-starter-library` (idea COMPLETE: final sub-slice, the PostToolUse advisory-lint template).

### D-20260723-memory-search-scope - /memory-search matches name+description only, off the derived graph; property-views deferred
- Workstream: memory
- Created: 2026-07-23
- Rationale: recall is built as two modes on the existing `memory_graph.py` (reusing `scan()` + `wiki_edges`), not a new `memory_search.py` and not logic in the skill - a second parser would drift from the linter's view of the graph. Search scope was narrowed to name + one-line `description` (no body/full-text) so the whole feature runs off the graph the engine already derives, with zero new file-grep data source; `type` is therefore not parsed this slice. Property-views by type/tag and the note-templates set (the idea's other two capabilities) are deferred to later slices. Invocation is user-only (`disable-model-invocation: true`, matching `/memory-lint`; reversible in one line).
- Spawns: none

Full design: `docs/specs/2026-07-19-memory-search-design.md`. Plan: `docs/plans/2026-07-23-memory-search.md`.

### D-20260727-ingest-gotcha-claudemd - /ingest may write a confirmed CLAUDE.md bullet for the explicit gotcha trigger (in-repo only)
- Workstream: memory
- Created: 2026-07-27
- Rationale: completing `/ingest`'s costly-first branch for stale-priors means writing an imperative bullet into CLAUDE.md, the home the boundary rule already assigns to costly-first facts (D-20260626-repo-canonical-memory). This is consistent with D-20260627-memory-adopt-claudemd-scope (the "never migrate CLAUDE.md" ban is scoped to the passive default; explicit confirmed flows may write CLAUDE.md, as `/memory-adopt` already does), so it is an extension, not a reversal. Kept narrow to avoid overreach: the write fires only on the explicit `gotcha:`/`stale-prior:` trigger (a normal costly-first fact still tells-and-stops); it is confirm-before-write; the mechanical insert is a tested idempotent, add-only helper (`scripts/claude-md-upsert.sh`) rather than model-driven editing of an always-loaded file; and it is in-repo only (sidecar workspaces never touch the repo tree, so the day-job/sidecar case gets the `docs/memory/` half only). Property-views by type/tag remain deferred.
- Spawns: none

Full design: `docs/specs/2026-07-27-ingest-gotcha-design.md`. Plan: `docs/plans/2026-07-27-ingest-gotcha.md`.

Closes `stale-priors-memory` (idea COMPLETE: the stale-prior/gotcha flavor landed in `conventions/memory.md` § Recurring flavors, which was that idea's entire stated need).

### D-20260730-agents-md-canonical - AGENTS.md is the canonical always-loaded instruction file; CLAUDE.md bridges to it
- Workstream: memory
- Created: 2026-07-30
- Rationale: portability to a non-Claude successor requires costly-first facts to live where any agent
  reads them. `AGENTS.md` is the cross-vendor always-loaded convention, so it becomes canonical and
  `CLAUDE.md` is reduced to a bridge that imports it (`@AGENTS.md` + `@docs/memory/MEMORY.md`). This
  extends D-20260727-ingest-gotcha-claudemd: the costly-first home moves from `CLAUDE.md` to the
  vendor-neutral `AGENTS.md` (which `CLAUDE.md` now imports), and the `/ingest gotcha:` write retargets
  there in in-repo mode. Sidecar mode is unaffected (repo tree untouched; costly-first stays manual).
- Spawns: none

Full design: `docs/specs/2026-07-30-portable-memory-base-design.md`. Plan: `docs/plans/2026-07-30-portable-memory-base.md`.

### D-20260812-project-init-existing-store-pointer - /project-init emits a pointer, never an empty index over an existing store
- Workstream: memory
- Created: 2026-08-12
- Rationale: an empty `memory/MEMORY.md` stamped over a store already in use (especially a sidecar
  workspace-tier `_meta/memory/`) is an active hazard - it contradicts practice and invites a second
  store. `/project-init` now detects an existing repo-tier or workspace-tier store and writes a
  pointer header (shared facts live in the workspace tier; this index holds only repo-specific facts)
  instead of a competing empty stub. From use-audit feedback (three byte-identical empty stubs).
- Spawns: none

Ships in v0.17.0 (A-20260812-memory-hygiene-lints).

### D-20260812-citation-lint-definition-anchored - the citation lint checks definition blocks, not a line window; basename collisions are ambiguous
- Workstream: memory
- Created: 2026-08-12
- Rationale: a naive "line within +/-N of the symbol" check false-positives on every correct citation
  to a line INSIDE a long function. The lint instead resolves the cited symbol's definition and
  accepts any line within its block; only a backticked token actually DEFINED in the file is
  checkable (a nearby import/exception/literal degrades to UNANCHORED, never STALE); and a bare
  basename matching several files is AMBIGUOUS (disambiguate with a path prefix), not stale. Chosen
  after validating read-only against the real `_meta` base, where the naive rule produced five false
  positives and this rule produced zero.
- Spawns: none

Ships in v0.17.0 (A-20260812-memory-hygiene-lints).

### D-20260812-proactive-capture-cadence - capture + read-only skills go model-invocable; a SessionStart hook drives proactive, batched capture
- Workstream: meta
- Created: 2026-08-12
- Rationale: 11 of 12 skills carried `disable-model-invocation`, so Claude captured records inline
  ("roundabout"), bypassing each skill's ritual (template, boundary test, secret-scan, idempotency).
  The capture skills (`project-log`, `ingest`) and read-only skills (`memory-lint`, `memory-search`)
  become model-invocable so Claude runs the real ritual; a scoped SessionStart hook
  (`hooks/capture-cadence.sh`) injects a capture cadence (note proactively, propose as a batch at a
  stopping point, write on confirmation) only in repos that have workspace-os data. Heavy/one-time
  skills (`project-init`, `workspace-init`, `make-portable`, `memory-adopt`, `tracking-adopt`,
  `memory-sync`, `continuity`) stay manual. Supersedes the blanket `disable-model-invocation` default
  for the four flipped skills.
- Spawns: none

Design: `docs/specs/2026-08-12-proactive-capture-cadence-design.md`. Plan: `docs/plans/2026-08-12-proactive-capture-cadence.md`.

### D-20260712-project-status-design — /project-status as read-only prose skill on per-repo tracking files
- Workstream: skills
- Created: 2026-07-12
- Status: accepted
- Rationale: borrow keystone's report/brief output shapes (MIT) but re-found them on the four per-repo tracking files — keystone's version reads a single-workspace project registry (projects.md + CODEs) that workspace-os deliberately doesn't have (portfolio-registry stays parked). Pure SKILL.md prose, no parser script: records are markdown for humans/LLMs, and lenient judgment-parsing survives adopted repos' legacy formats where a deterministic parser would choke. Read-only contract (writes nothing) → no propose/confirm gate; model invocation enabled since triggers are conversational ("what's next", "status").
- Consequences: first skill in the plugin with model invocation enabled and a pure read-only contract; keystone's set mode (lifecycle/priority mutation) deliberately dropped.
- Spawns: A-20260712-project-status

Spec: docs/specs/2026-07-12-project-status-design.md. First sub-slice of tracking-skills-roundout.

Closes tracking-skills-roundout (idea COMPLETE across v0.19.0 + v0.26.0 + v0.29.0:
/project-status, /work-journal summary+log+prep, /project-log discovery/meeting/release-notes).
The portfolio mode was never this idea's to ship - it lives in portfolio-registry's scope.


### D-20260817-portable-refresh-scope — --refresh covers plugin-owned files only, never AGENTS.md
- Workstream: memory
- Created: 2026-08-17
- Status: accepted
- Rationale: the stamper writes four things and they are not equally safe to re-copy. The vendored
  memory_graph.py and the operator's manual are plugin-owned and version together (the manual
  documents the validator's lint modes), so --refresh re-copies both. AGENTS.md carries
  user-authored content under the managed `## Stale priors` heading, so it is never overwritten;
  the CLAUDE.md bridge is already additive and needs nothing. A finer "refresh only if unmodified"
  rule was rejected as unimplementable: nothing records which shipped version a base was stamped
  from, so an edited file and an older file are indistinguishable. Overwrite is acceptable because
  every base is under git (in-repo, or the sidecar's local-only auto-committed repo), so git is the
  undo. Opt-in, because the add-only default is what makes /project-init re-runnable.
- Consequences: /make-portable gains the first overwriting operation in the skill, hence its first
  confirm gate. The gate classifies three ways (absent / differs / identical) rather than two: a
  plain cmp reports an absent file as a difference and would warn about overwriting a file that
  does not exist. Refresh withholds overwrites, not the initial stamp, so an absent AGENTS.md is
  still created.
- Spawns: A-20260817-portable-layer-refresh

Idea: portable-layer-refresh (ideas.md), surfaced by A-20260812-memory-hygiene-lints.

Closes `portable-layer-refresh` (idea COMPLETE, v0.20.0).

### D-20260819-idea-completion-exit — a fully shipped idea is deleted from ideas.md, never archived in it
- Workstream: schema
- Created: 2026-08-19
- Status: accepted
- Rationale: the Lifecycle section documented only one exit from `ideas.md` (an idea goes active and
  graduates to an action) and was silent on completion, so the only documented-adjacent move for a
  shipped idea was to append a Shipped line and leave the record in place. Seven accumulated that
  way. The cost is not cosmetic: a parked record keeps its `Priority:` line, so `/project-status`
  counted 6 `high` ideas when only 2 were live work. `ideas.md` is a queue, not an archive: the
  terminal home for completed work is the `D-` record (reasoning) plus the `A-` record in
  `resolved.md` (completion), which is where a reader already looks. An archive section inside
  `ideas.md` was considered and rejected: it invents a tier the lifecycle does not have, and the
  same staleness would just accumulate one heading lower. Deletion is safe because `ideas.md` is
  the one tracking file that permits removal (`decisions-log.md` and `resolved.md` are append-only)
  and because git holds the removed prose.
- Consequences: closing an idea is now a 4-step ordered procedure rather than a one-line edit, and
  step 4 (repointing inbound `[[wikilinks]]`) is easy to forget since tracking wikilinks are
  human-contract and no lint catches a dangling one. A `/project-log shipped <idea>` mode would
  automate it; not built.
- Spawns: none

Applied retroactively to 7 ideas in PR #25 before this rule was written down.

### D-20260819-memory-provenance-fields — verified-against (checkable) over a volatility enum (asserted)
- Workstream: schema
- Created: 2026-08-19
- Status: accepted
- Rationale: the `memory-volatility-field` idea offered a fork — a categorical
  `volatility: stable|measured|pinned`, a concrete `verified-against: <sha> <date>`, or both. The
  enum is **rejected**: it is hand-maintained metadata nothing can validate, the same shape as the
  `Priority:` lines that went stale on four shipped ideas and made `/project-status` over-report
  (PR #25 cleaned the data, PR #26 the cause). It would drift *silently*, since staleness is
  invisible by definition. `verified-against` is different in kind because it is checkable: it turns
  "should I re-verify this?" into a computation over `git diff <sha>..HEAD`. The counter-argument is
  real and recorded — not every fact cites code, so the field says nothing about durable domain
  knowledge — but absence already carries that meaning: a fact with no `verified-against` is one
  nobody anchored to code, the same population the enum would have labelled `stable`.
- Consequences: `--check-citations` now shells out to git, so it must degrade (never error) on
  non-git source trees, unknown shas, and malformed fields; all three are pinned by tests. The new
  UNVERIFIED-SINCE bucket is advisory and must never change the exit code, or one upstream commit
  would turn every base's CI red. `applies-to` takes a required `branch:`/`repo:` prefix because the
  idea record's bare `<branch|repo>` could not distinguish a branch named `main` from a repo of the
  same name.
- Spawns: A-20260819-memory-provenance-fields

Spec: `docs/specs/2026-08-19-memory-provenance-fields-design.md`. Plan:
`docs/plans/2026-08-19-memory-provenance-fields.md`.

Closes `memory-volatility-field` (idea COMPLETE, v0.21.0) and `memory-applies-to-field`
(idea COMPLETE, v0.21.0).


### D-20260824-guardrails-canonical-hookify-misfits — guardrails.json stays canonical; hookify gets the misfits
- Workstream: workflow
- Created: 2026-08-24
- Status: accepted
- Rationale: hookify rules are gitignored and personal — they protect one machine, not the repo. The engine's differentiator is rules that travel with the repo (shared, hard deny semantics, ip_class tripwires, sidecar-aware); the 2026-08 audit showed it lost on authoring ergonomics only. So /guardrails authors guardrails.json, and routes misfit hazards (stop/prompt events, explicitly personal scope) to hookify rather than absorbing it or conceding to it.
- Consequences: state-dependent hazards stay out of scope — that is the stateful-guardrail-predicates idea, gated behind this slice by design.
- Spawns: A-20260824-guardrail-conversational-authoring

Considered and rejected: emitting hookify `.local.md` rules (loses repo-shared rules — the
engine's whole point); guardrails.json-only with no routing (recreates the ergonomics gap for
hazards the engine genuinely cannot express). Spec:
`docs/specs/2026-08-24-guardrail-conversational-authoring-design.md` § Decision.

Closes guardrail-conversational-authoring (idea COMPLETE, v0.22.0; the hookify session-mining
borrow spun off as its own idea, guardrails-session-mining). dispatch-ledger closed the same
sweep (v0.23.0; no D- record — its one decision is folded into resolved.md
A-20260824-dispatch-ledger).

### D-20260824-playbook-surface-before-default — playbooks surface via deny-once by default; per-playbook opt-out to after-injection
- Workstream: skills
- Created: 2026-08-24
- Status: accepted
- Rationale: verified against the Claude Code hooks docs (2026-08-24): PreToolUse command hooks CANNOT inject model context non-blockingly — additionalContext is honored there only on "ask" escalations; PostToolUse injects unconditionally but only after the call ran. The audit's plea is literally "read before, not after they fail," and one blocked call + read + retry costs far less than the measured unguided-first-call failure (~484k tokens). So `surface: before` (deny-once, marker-then-deny so the retry passes) is the default, with `surface: after` (PostToolUse injection) as the per-playbook opt-out for advisory procedures.
- Consequences: playbook surfacing depends on hook registration order not at all (parallel hooks); a `before` playbook costs exactly one denied call per session.
- Spawns: A-20260824-procedure-playbooks

Considered and rejected: always-after (first call always unguided — the exact measured failure); UserPromptSubmit injection (prompt-scoped, not tool-scoped — fires on user turns, not at the moment of the matching call); always-before (no soft option for advisory-grade procedures).

Closes procedure-playbooks (idea COMPLETE, v0.24.0 core + v0.28.0 follow-ups: init stamp +
playbook lint). The UDX five-doc adoption is usage on that machine, not plugin work.

### D-20260828-build-only-what-native-wont — evolution rule: build only what native Claude Code can't or won't ship
- Workstream: meta
- Created: 2026-08-28
- Status: accepted
- Rationale: the 2026-08-28 three-lane market survey (tracking/spec frameworks, agent memory, hooks/guardrails) confirmed Anthropic's absorption pattern — native has eaten neutral-convenience categories one at a time (auto mode killed the auto-approver category; auto-memory, hookify, and managed settings each took a pillar's middle). The durable gaps sort into four classes: (1) designs Anthropic already chose against — in-repo PR-reviewable memory (auto-memory is deliberately machine-local) and deterministic auditable policy (their bet is classifier-judged auto mode; native permissions explicitly refuse content-field matching and ship no warn tier); (2) opinionated schemas — append-only decision supersession, capture conventions, adoption that reshapes legacy docs (neutral infrastructure never ships a schema); (3) incentive-inverted seams — vendor neutrality (the AGENTS.md layer) and the `_meta/` sidecar (serves the employee; Anthropic sells to the employer); (4) boundary knowledge only the org holds — `ip_class` provenance walls. Rule: every new surface must be opinionated, deterministic, git-native, or boundary-aware; neutral convenience is never built — it is borrowed, or awaited from native.
- Consequences: extends D-20260705-keystone-reposition's borrow-first logic from keystone to the whole market; idea triage gains the question "would native plausibly ship this?" — a yes demotes the idea to borrow/await.

Survey context (in-session 2026-08-28): tracking/spec is saturated (spec-kit ~132k★, gstack ~130k★,
OpenSpec ~66k★, BMAD ~52k★) but none ship decision-supersession, doc adoption, or ambient capture;
memory is dominated by external DB/services (mem0, claude-mem) with no PR-reviewable+linted+SHA-fresh
combination anywhere and no sidecar analog at all; enforcement's real competitor is first-party
hookify (gitignored rules, no dry-run), and `ip_class` + declarative `lint.json` have no market
analog. No integrated tracking+memory+guardrails per-repo plugin exists. Spawned idea captures (via
/project-plan, same day): [[session-state-records]], [[transcript-mining-ingest]],
[[memory-lint-hardening]]; borrow notes on guardrail-conversational-authoring, portfolio-registry,
tracking-skills-roundout.

### D-20260828-propagation-intent-fact-lines — propagation state = an intent line plus append-only fact lines, grouped by remote URL
- Workstream: schema
- Created: 2026-08-28
- Status: accepted
- Rationale: a single "landed here" line with an implicit all-checkouts target cannot express the audit's real case (a fix relevant to a subset of checkouts), so intent (`- Propagation: all | <folders>`) and fact (`- Propagated-to: <folder> <date> [sha]`) are separate lines — both appended, never edited, the `Superseded-by:` pattern, `merge=union`-safe. Grouping is automatic by normalized `origin` URL (zero config — the audit's automatic-vs-hand-authored adoption finding), keyed by folder basename like the sidecar data roots. `all` is dynamic (every grouped checkout at read time) so the matrix reflects the current workspace. Sidecar-only: in-repo checkouts share tracking files through git itself. A- records only: decisions are reasoning, not deployable diffs.
- Consequences: `/project-status` gains a `matrix` mode and `/project-log` a `propagated` mode; `scripts/checkout-groups.sh` becomes the single grouping source; the record body line-ceiling and boundary rules are untouched.
- Spawns: A-20260828-checkout-propagation

Design: docs/specs/2026-08-28-one-project-many-checkouts-design.md (brainstormed + approved 2026-08-28).

Closes one-project-many-checkouts (idea COMPLETE: link-resolution half v0.22.1, propagation
schema + matrix v0.25.0). See resolved.md A-20260828-checkout-propagation.

### D-20260828-handoff-live-file-lifecycle — handoffs are live files per effort, surfaced by hook, not an append-only history or a /continue verb
- Workstream: skills
- Created: 2026-08-28
- Status: accepted
- Rationale: a handoff is working state, not history — a dead brief has no archive value, so the record is one live file per effort (`handoffs/<effort-slug>.md`), refreshed on re-pause and deleted at completion with a one-line trace on the resolved record (mirroring how action records leave action-items.md). Discovery is automatic: the existing capture-cadence SessionStart hook lists live handoffs (the EC2 audit's automatic-surfaces-get-adopted finding), so no /continue verb ships — resume = read the surfaced file. /handoff is its own model-invocable skill because its trigger language ("let's stop here") is conversational; burying it in a /project-log mode costs discovery. Keystone's checkpoint/draft-PR machinery, registry codes, and _unfiled promotion are deliberately not borrowed.
- Consequences: capture-cadence.sh gains a second output block (still fail-open); /project-log done gains a handoff-deletion proposal; /project-status gains a Live handoffs section; skill count grows by two (/handoff, /work-journal).
- Spawns: A-20260828-session-continuity

Design: docs/specs/2026-08-28-session-continuity-design.md (brainstormed + approved 2026-08-28).

Closes session-state-records (idea COMPLETE, v0.26.0). tracking-skills-roundout ships its
/work-journal half the same release; see that idea's Shipped annotation.

### D-20260828-pack-stamp-ledger — pack provenance = per-rule stamp + a _packs ledger; removal never downgrades ip_class
- Workstream: packaging
- Created: 2026-08-28
- Status: accepted
- Rationale: the keystone anti-borrows enforced by construction — one distribution channel (in-plugin packs/, version = plugin version), machine-read manifests (a pack failing validate-plugin.py fails CI), and imports that are idempotent and scoped: every imported rule carries `"pack": "<name>"` (the engines read named fields only, so the stamp is inert — proven by test), `add` deletes-then-inserts only that pack's stamped rules (hand-authored rules are never touched; no delete-and-recopy), and a `_packs` ledger in guardrails.json records {version, imported} per pack. `remove` deletes the stamped rules + ledger entry but never changes ip_class — silently dropping a provenance boundary is worse than a stale one, so it prints a review note instead. Params ({{placeholders}}) are substituted by the /guardrails skill conversationally; the deterministic script dies on any unsubstituted placeholder, keeping bash template-free.
- Consequences: /guardrails grows a pack mode (list/add/remove); validate-plugin.py gains a packs gate; the starter enterprise-clean-room pack productizes the two measured UDX hazards (employer tripwire content, enterprise remote traffic) that today live in personal hookify rules.
- Spawns: A-20260828-policy-packs

Design: docs/specs/2026-08-28-policy-packs-design.md (brainstormed + approved 2026-08-28).

Closes policy-packs (idea COMPLETE, v0.27.0). The starter-pack half of
keystone-module-guardrails' "engine + pack" contribution now exists; see that idea's note.

### D-20260829-mine-current-session-only — /guardrails mine reads the current session only, never transcript files
- Workstream: workflow
- Created: 2026-08-29
- Status: accepted
- Rationale: the two mining shapes have different economics and different targets. Current-session mining is free (the conversation is already in context), immediate (the near-miss is minutes old and citable), and rule-shaped. Historical transcript mining costs real LLM work over ~/.claude/projects files, needs a dedupe pass against landed rules and facts, and mostly surfaces fact/record-shaped items — that is the transcript-mining-ingest idea's lane. Splitting by source keeps /guardrails mine cheap enough to run at any session end without cost hesitation.
- Consequences: a near-miss from a past session cannot be mined; re-describe it to author mode instead. If transcript-mining-ingest ships, its rule-shaped findings should hand off to the /guardrails author pipeline rather than growing a second proposer.
- Spawns: A-20260829-guardrails-session-mining

Closes guardrails-session-mining (idea COMPLETE, v0.31.0 — the hookify discovery borrow,
landed on our authoring pipeline unchanged).

### D-20260829-awaiting-not-a-verdict — findings close on evidence; ownership is a field, not a verdict
- Workstream: schema
- Created: 2026-08-29
- Status: accepted
- Rationale: the UDX register's legend mixed two axes — what the evidence showed (BUG/BEHAVIOR/LATENT) and who owes it (TEAM). An F- record splits them: the verdict enum (bug|behavior|latent|answered|moot) says what was learned, set once at close; Awaiting: says who/what owes the evidence while open, and Closes-on: names the evidence that settles it. The closing verb is `verdict`, not `done` — nothing was done, something was learned — and closed findings archive to resolved.md so the single-archive invariant (work-journal/status cross-referencing) holds. moot earns its slot because questions get overtaken by events; without it they linger open or close with a dishonest `answered`.
- Consequences: /tracking-adopt maps legend registers onto the enum (settled items close on adoption); memory_graph harvests F- ids so facts can cite findings as provenance; a bug verdict hands its work to a spawned A- record rather than mutating the finding.
- Spawns: A-20260829-finding-record-class

Closes finding-record-class (idea COMPLETE, v0.32.0). The UDX register's actual adoption is
usage on the EC2 machine via /tracking-adopt.

### D-20260829-markdown-stays-canonical — tracking stays markdown-canonical; Projects-canonical rejected; one-way mirror evidence-gated
- Workstream: schema
- Created: 2026-08-29
- Status: accepted
- Rationale: Projects-canonical is structurally incompatible with sidecar mode (the local-only no-remote _meta layer cannot have its canon in GitHub's cloud - the data model would fork in two), inverts D-20260828-build-only-what-native-wont (migrates canon onto the platform-surface class the strategy avoids; GitHub already sunset Projects classic once), and turns the deterministic layer (memory_graph link resolution, merge=union, the AGENTS.md vendor-neutral layer) into PAT-gated network calls - the surface shape the EC2 audit measured at 1-3/10 adoption. User-owned Projects v2 boards additionally need a classic PAT: standing secret surface for a plugin that needs none.
- Consequences: no build now - /project-log release-notes already serves the outward-readable view. The one-way mirror (files -> board, board never an input) is deferred behind recorded re-evaluation triggers: a second regular human reader of a tracked repo's status; portfolio-registry going active (a board is then a candidate RENDERER of its registry, never the registry); GitHub removing the classic-PAT requirement. If built: dormant-by-default with the integrity-auditor cloud-tier hardening, adapted from Zach's workflows.
- Spawns: none

Full weighing: docs/specs/2026-08-29-github-native-tracking-decision.md.

Closes github-native-tracking (idea COMPLETE - it was captured as a decision to deliberate;
deciding was the work).

### D-20260829-finish-task-superseded — SP3-finish-task closed: natives ate the orchestrator, a playbook holds the ritual
- Workstream: workflow
- Created: 2026-08-29
- Status: accepted
- Rationale: the June capture predates two things that consumed its scope from both ends. The generic half (review -> verify -> commit -> PR) is now covered by borrowed/native surfaces (/commit-push-pr, superpowers finishing-a-development-branch + verification-before-completion, /code-review) - building a sequencer over them is the build-alike D-20260828-build-only-what-native-wont forbids. The differentiated half (the tracking close-out: resolved record with merge SHA, Closes line, idea removal, wikilink repoint, memory_graph check, plugin update) is a PROCEDURE, not an orchestrator - and the playbook artifact class (v0.24.0, which postdates the idea) is built for exactly that shape. Codified as docs/playbooks/ship-a-slice.md (trigger: opening or merging a PR via gh, surface before), lint-clean. The keystone /finish-task borrow surface also shrank: their ritual binds to a registry and sequential-ID model our close-out has since diverged from (F- records, ship-close protocol, sidecar commits).
- Consequences: no /finish-task skill will be built; the ship ritual lives as a playbook in this repo (and any repo can author its own). If a future multi-repo release ritual outgrows a playbook, that is a new idea with new evidence, not a revival of this one.
- Spawns: none

Closes SP3-finish-task (idea CLOSED superseded - not shipped; the surviving slice was
captured as the ship-a-slice playbook, first playbook dogfooded in this repo).


### D-20260825-workspace-root-mode — a distinct `workspace-root` mode, not a reused `sidecar`
- Workstream: schema
- Created: 2026-08-25
- Status: accepted
- Rationale: `resolve-data-root.sh` exited 1 whenever CWD was outside a git work tree, which is
  the common layout for a sidecar workspace: several repos side by side, `_meta/` alongside
  them, and the workspace folder itself not under version control. Every hook treats resolver
  failure as "no data here, stay silent" (correct fail-open), so opening a session AT the
  workspace root silently disabled the whole workspace tier. The fix walks up from CWD for
  `<dir>/_meta/workspace.json`. Reporting `sidecar` from there was rejected: `guardrail.sh` and
  `sidecar-memory-context.sh` both gate on `mode = sidecar` and then dereference `data_root`,
  so they would receive a repo-tier path that does not exist. A distinct mode with **`data_root`
  deliberately unset** lets consumers opt in through their existing `[ -n "$ws_root" ]` guards.
  An unmarked non-git dir still errors and exits 1, so the fallback only ever fires on a real
  marker.
- Consequences: `capture-cadence.sh` now fires where it previously stayed silent, injecting a
  session-start block in a context that had none. Intended, but new. `sidecar-memory-context.sh`
  still gates on `sidecar`, so the workspace-tier `MEMORY.md` is NOT injected in `workspace-root`
  mode; extending it would change what loads into every workspace-root session and deserves its
  own decision. The walk-up also had to move below `marker_mode()`/`marker_name()`, since those
  helpers are defined after the old early-exit, keeping one JSON-parsing path.
- Spawns: A-20260831-dogfood-defect-batch

Authored 2026-08-25 on another machine and transferred as a patch; it did not land, and main
reached v0.32.1 without it. Re-verified against the v0.25-v0.32 consumer set before landing,
rather than re-asserting the original "no consumer needed editing" claim, which was true only
of 0.24.1. Every executable consumer of the resolver, classified under `mode=workspace-root`
with `data_root` unset:

- `hooks/guardrail.sh`, `hooks/lint.sh` — gate on `mode = sidecar`; both skip. `data_root` is
  dereferenced only inside those gates. Safe no-op.
- `hooks/sidecar-memory-context.sh` — hard `[ "$mode" = "sidecar" ] || exit 0`. Safe no-op, and
  the documented consequence above.
- `hooks/playbook-surface.sh` — already guards with `[ -n "$ws_root" ]`, so workspace-tier
  playbooks surface correctly; its only writes go to `$TMPDIR`, never `data_root`.
- `scripts/guardrails-upsert.sh`, `scripts/pack-import.sh` — take the non-sidecar branch and
  write. Checked specifically for a write through an empty `data_root`: both compute
  `root="$(git rev-parse --show-toplevel)"` and then `[ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"`,
  so the path is `$PWD/.claude/...`, never `/.claude/...`. The engine reads the same path, so
  write and read agree. Safe.
- `hooks/capture-cadence.sh` — the one consumer that genuinely needed editing; its handoff
  block had a second gate on `data_root`. See D-20260831-workspace-root-handoff-fanout.

### D-20260831-workspace-root-handoff-fanout — handoffs fan out across repo dirs when there is no repo tier
- Workstream: schema
- Created: 2026-08-31
- Status: accepted
- Rationale: `capture-cadence.sh`'s handoff block gates on `[ -n "$data_root" ]`, a second gate
  independent of the resolver fix — so handoffs stayed invisible from the workspace root even
  with `workspace-root` mode working. At the workspace root there is no repo tier to read, and
  no single repo is in scope; the useful answer is every paused effort in the workspace. The
  block now reads `<ws>/<repo-folder>/project-tracking/handoffs/` for each entry plus the
  workspace tier itself, gated on `data_root` being **unset** rather than on the mode string.
  Reading via `checkout-groups.sh` was rejected: that script groups checkouts by `origin` URL,
  so it would skip any repo without a remote, and it would introduce a second source of truth
  about where repo data lives. The plain glob is the exact inverse of the resolver's own
  `data_root=<ws>/<repo-folder-name>` mapping, and it is self-filtering — `_meta/memory` and
  `_meta/sources` cannot match a pattern requiring the `project-tracking/handoffs` suffix.
- Consequences: repo-tier entries are labelled `<folder>/<slug>` because a bare slug is
  ambiguous once more than one repo can contribute; workspace-tier entries stay bare, belonging
  to no repo. Gating on unset `data_root` keeps **sidecar mode repo-scoped** — inside a repo you
  see only that repo's handoffs, pinned by a leak test. `workspace-meta` mode sets
  `data_root == workspace_root` and therefore does **not** fan out; it already surfaces the
  workspace tier through the repo-tier path. Extending the fan-out to `workspace-meta` would
  change an existing mode's behavior and belongs to its own decision, not this batch.
- Spawns: A-20260831-dogfood-defect-batch

### D-20260904-predicate-exit0-fires-fail-open — a guardrail predicate ANDs with `match`, fires on exit 0, runs uncached and trusted
- Workstream: workflow
- Created: 2026-09-04
- Status: accepted
- Rationale: three choices, each picked against a named alternative. (1) **AND with `match`,
  exit 0 = fire.** The predicate is phrased as the hazard condition, mirroring `match`, so an
  erroring or timing-out predicate (non-zero) simply does not fire — the engine's existing
  fail-open contract survives with no second signal. "Non-zero = fire" (predicate as a
  precondition) reads well for the branch case but would fire on every error; "predicate
  replaces match" drops the regex gate and pays a subprocess on every tool call. (2) **No
  caching.** Branch and disk state change mid-session — the whole reason to test state — so a
  per-session cache answers the wrong question; cost is bounded by the regex. (3) **Trusted
  as-is, risk documented.** A predicate is shell in a version-controlled file, the same
  standing as repo-level Claude Code hooks and the existing lint linters that already run
  repo-configured commands. An allowlisted predicate library was rejected because every new
  hazard class would need an engine change (the disease this slice cures); forbidding
  predicates in packs was rejected because packs are the plugin's own rules — a boundary there
  protects nothing the hand-authored path does not already expose.
- Consequences: `guardrails.json` now executes shell on matching tool calls; the template
  comment and GUIDE say so. The `/guardrails` dry-run gate gains a third required case
  (regex hits, state healthy → must not fire). Passing call context to the predicate, a
  per-rule timeout, and the `Task` hook surface are deferred to probe-first-dispatch-gate,
  which this unblocks.
- Spawns: A-20260904-stateful-guardrail-predicates
