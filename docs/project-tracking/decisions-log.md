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

### D-20260705-continuity-home-root — CONTINUITY.md lives at the repo root, as a human doc, pointer-only from CLAUDE.md
- Workstream: workflow
- Created: 2026-07-05
- Status: accepted
- Consequences: /continuity scaffolds at root; the CLAUDE.md line is a pointer, not an @import (the doc must not load every session — it's for a human stranger, not the model)
- Spawns: A-20260705-continuity-runbook
- Rationale: a bus-factor runbook's single job is to be found by someone who doesn't know the repo — that argues for README-sibling visibility over docs/ tidiness (the idea had flagged root-vs-docs as the open decision). Kept out of the always-loaded context: unlike memory, its audience is a human during an incident, and its content (hosts, cadences, owner names) is dead weight in every model session. Template generalizes the westgate CONTINUITY.md *shape* only (five sections + TODO(owner) convention — patterns, no proprietary content, per the standing reference-repo rule), plus the 2026-06-28 borrow notes: DVC deps→outs framing and a Backstage-style Owner column on the obligations table.
