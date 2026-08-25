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

### A-20260705-continuity-runbook — CONTINUITY.md template + /continuity skill
- Workstream: workflow
- Status: done
- Created: 2026-07-05
- Completed: 2026-07-05
- Commit: f99188b (PR #12, branch continuity-runbook)

Shipped `templates/CONTINUITY.md` — the bus-factor runbook template: (1) recurring-obligations
table framed deps→outs (Needs / Goes-stale) with load-bearing Detection column + Owner; (2)
access & secrets as POINTERS ONLY (never values) + escalation; (3) trusted-for-now source budget
with re-verify cadences; (4) meta-layer maintenance budget (doc caps, /memory-lint, union-file
dup scan, skills audit); (5) the bus-factor test (a non-owner proves the doc works). `TODO(owner)`
marks named gaps. And `skills/continuity/SKILL.md`: scaffold mode auto-inventories systemd timers,
cron, CI `on: schedule`, app schedulers + maintenance docs and proposes pre-filled rows
(propose→confirm→apply, never inventing a Detection that doesn't exist); review mode diffs the
inventory against the doc, lists TODOs by owner, nudges stale re-verify dates. Home = repo root
(D-20260705-continuity-home-root). Plugin v0.9.0. First real consumer: OA's 12 systemd
service/timer pairs.

### A-20260706-model-decision-log — model-decision record variant + MODEL_LOG run-layer fallback
- Workstream: skills
- Status: done
- Created: 2026-07-06
- Completed: 2026-07-06
- Commit: 0c7ac16 (PR #13, branch model-decision-log)

Shipped the DS/ML tracking slice (D-20260706-model-log-run-layer): (1) **model-decision template
variant** in `conventions/project-tracking.md` — same D- ID and decisions-log.md home, plus typed
fields (Model, Dataset vintage/cutoff, Architecture vs alternatives, Validation protocol + leakage
guards, ONE headline metric, `Run:` pointer, Outcome); champion/challenger lifecycle rides the
existing supersession protocol, so the log holds model lineage for free. (2) **`/project-log
model-decision` mode** — asks only for Dataset/Validation/Run, never copies metrics tables;
promotion applies supersession against the old champion. Quick-add infers from model vocabulary.
(3) **Run layer, tracker-first with fallback**: `Run:` points at an MLflow/W&B run ID/URL; with no
tracker, `templates/MODEL_LOG.md` → `docs/models/<name>.md` — append-only merge=union table,
sha → headline metrics → verdict, one row per evaluated candidate (git owns "what changed").
Plugin v0.10.0. Graduated from the model-decision-log idea (brainstorm 2026-06-28).

### A-20260707-sidecar-data-layer — build sidecar data-layer mode per spec
- Workstream: meta
- Status: done
- Created: 2026-07-07
- Completed: 2026-07-07
- Commit: 4d9b40a (PR #14, squash of feat/sidecar-data-layer 0f1c0ff..5f96dbd)

Implemented docs/specs/2026-07-07-sidecar-data-layer-design.md (v0.11.0), built subagent-driven
per docs/plans/2026-07-07-sidecar-data-layer.md: `scripts/resolve-data-root.sh` resolver +
`/workspace-init` + sidecar branches in all 9 skills + SessionStart two-tier memory hook +
`guardrail.sh` sidecar fallback/backstop + `memory_graph.py --link-root` +
`conventions/data-root.md` + 54 test checks across 4 suites. Final whole-branch review fixes
landed in 5f96dbd. Spawned by D-20260707-sidecar-data-layer.

### A-20260711-tracking-adopt-git — build /tracking-adopt git mode per spec
- Workstream: skills
- Status: done
- Created: 2026-07-11
- Completed: 2026-07-11
- Commit: 5b8bf56 (PR #16, squash of tracking-adopt-git 382311d..862c4ce)

Shipped the `git` mode on `/tracking-adopt` (G2–G9): bounded history mining (newest tag, else
last ~30 merged units) → one `resolved.md` record per merged unit (merge commit, squash `(#N)`,
or grouped direct-to-main run), opportunistic `gh` enrichment that degrades silently, doc-completed
cross-match, and SHA/PR#-primary dedup. New "Git-history archaeology" sub-subsection in
`conventions/project-tracking.md` is the SoT for bound/record-shape/dedup rules. Plugin v0.12.0.
Propose-only self-run against workspace-os's own history confirmed zero duplicate proposals
(4d9b40a/PR #14, 0c7ac16/PR #13, f99188b/PR #12 all correctly skipped). Graduated adoption-import
sub-slice (b.2). Decision D-20260711-tracking-adopt-git-design.

### A-20260713-lint-hook — PostToolUse advisory-lint hook + template
- Workstream: workflow
- Status: done
- Created: 2026-07-13
- Completed: 2026-07-13
- Commit: c8f2b80 (PR #17, squash of lint-hook 6e693e1..264c18e)

Shipped `hooks/lint.sh` (PostToolUse `Edit|Write|MultiEdit`): runs each linter a repo declares in
`.claude/lint.json` (`{name, match, command}`) whose `match` regex matches the edited file's path, as
`<command> <file_path>`, and injects non-empty output as `additionalContext` (nested under
`hookSpecificOutput`; truncated to ~9,500 chars); clean/absent-config/absent-linter → silent,
fail-open throughout. Sidecar fallback to `_meta/<repo>/lint.json`. Registered in `hooks/hooks.json`;
`templates/lint.json` (inert until edited); 11-case bash harness (`tests/test-lint.sh` + stub
`fake-linter.sh`) wired into CI. Plugin v0.13.0. Closes `hook-starter-library` (last sub-slice).
Decision D-20260713-lint-hook.

### A-20260723-memory-search - /memory-search: search + backlink view over the memory graph (v0.14.0)
- Workstream: memory
- Status: done
- Created: 2026-07-23
- Completed: 2026-07-23
- Commit: 8d2197e (squash-merge of PR #18; pre-squash branch feature/memory-search 0eb80a5^..cffce14)

Extended `scripts/memory_graph.py` with two read-only query modes reusing `scan()`/`wiki_edges`: `--search QUERY` (case-insensitive substring over each fact's name + frontmatter description; added a `description:` parse) and `--backlinks NODE` (LINKS OUT + BACKLINKS with real spellings + typed edges). New `/memory-search` skill dispatches `--links <fact>`→backlinks, else query→search; read-only, no commit, mirrors `/memory-lint`. Tests added to `tests/test-memory-graph.sh` (all green, existing modes unchanged). Spec: `docs/specs/2026-07-19-memory-search-design.md`. Plan: `docs/plans/2026-07-23-memory-search.md`. Decision: D-20260723-memory-search-scope. Closes the search/backlink half of `memory-backlinks-search` (property-views + note-templates remain).

### A-20260727-ingest-gotcha - /ingest gotcha: stale-prior capture routing to both homes (v0.15.0)
- Workstream: memory
- Status: done
- Created: 2026-07-27
- Completed: 2026-07-27
- Commit: 553d88b, 853a3b9, a42a589, e9825e3 (branch feature/ingest-gotcha; squash-merged to main as 6d0c93c via PR #19)

Added a `gotcha:`/`stale-prior:` branch to `/ingest`: it reuses the existing boundary test and routes a stale-prior to a confirmed imperative bullet in a managed `## Stale priors (training vs reality)` CLAUDE.md section (in-repo only) or a `docs/memory/` fact with the gotcha body shape. The CLAUDE.md write is a deterministic, idempotent, add-only helper `scripts/claude-md-upsert.sh` (plain-bash tests in `tests/test-claude-md-upsert.sh`), confirm-before-write in the skill. Sidecar mode falls back to tell-and-stop. Non-gotcha `/ingest` unchanged. Flavor documented in `conventions/memory.md` § Recurring flavors. Spec: `docs/specs/2026-07-27-ingest-gotcha-design.md`. Plan: `docs/plans/2026-07-27-ingest-gotcha.md`. Decision: D-20260727-ingest-gotcha-claudemd. Ships the note-templates half of `memory-backlinks-search` (property-views remain). Final-review fixes (e9825e3): the section-present append path now keeps a trailing `@import` last, and the in-repo CLAUDE.md write path now runs the secret scan the Global Constraints required (the plan's Task-3 text had omitted it).

Closes the `stale-priors-memory` idea: its stated need (add the stale-prior flavor to `conventions/memory.md`) is satisfied by § Recurring flavors.

### A-20260730-portable-memory-base - portable (vendor-neutral) memory base (v0.16.0)
- Workstream: memory
- Status: done
- Created: 2026-07-30
- Completed: 2026-07-30
- Commit: 01f80bb, 409e5b7, ad756d1, 0ecf24c, 75dee74, 797d38c (branch feature/portable-memory-base)

Made every memory base workspace-os produces self-describing and vendor-neutral: a de-skilled
operator's manual (`templates/memory/README.md`) + vendored `memory_graph.py` + a thin `AGENTS.md`
entry point + a `CLAUDE.md` bridge, stamped by a shared tested helper `scripts/stamp-portable-layer.sh`.
`/project-init` stamps it (both modes) and `/make-portable` retrofits existing bases. `AGENTS.md` is
now the canonical always-loaded home; the `/ingest gotcha:` write retargets there (D-20260730-agents-md-canonical).
Skills/hooks/plugin stay Claude-only. Spec: `docs/specs/2026-07-30-portable-memory-base-design.md`.
Plan: `docs/plans/2026-07-30-portable-memory-base.md`. Ships the survival half of `[[vendor-neutral-runtime]]`;
multi-vendor USE (MCP) remains.

### A-20260812-memory-hygiene-lints - citation-freshness + boundary lints and a project-init store guard (v0.17.0)
- Workstream: memory
- Status: done
- Created: 2026-08-12
- Completed: 2026-08-12
- Commit: 2f27803 (PR #21, merged to main)

From use-audit feedback on the memory base. Three quick wins: `memory_graph.py --check-citations`
(definition-anchored block containment + `path::symbol` anchors; bare-basename collisions reported
AMBIGUOUS, not stale) catches `file:NNN` citations that rot; `--check-tracking` flags tracking
records over ~40 lines or carrying a `**MEASURED**` block (the memory/tracking boundary, now in
`conventions/project-tracking.md`); and `/project-init` no longer stamps an empty index over an
existing store, emitting a pointer instead (D-20260812-project-init-existing-store-pointer). Both
lints wired into `/memory-lint` and documented in the portable operator's manual. Validated
read-only against the real `_meta` base: zero false-positive stales. Heuristic:
D-20260812-citation-lint-definition-anchored. Two schema follow-ups captured as ideas:
[[memory-volatility-field]], [[memory-applies-to-field]].

### A-20260812-proactive-capture-cadence - proactive, batched capture via model-invocable skills + a cadence hook (v0.18.0)
- Workstream: meta
- Status: done
- Created: 2026-08-12
- Completed: 2026-08-13
- Commit: a8ac1d5 (PR #22, merged to main)

Made `project-log`, `ingest`, `memory-lint`, `memory-search` model-invocable and added a scoped
SessionStart hook `hooks/capture-cadence.sh` that injects a proactive, batch-at-boundaries capture
cadence only in workspace-os repos. `project-log`/`ingest` descriptions reworded to invite proactive
use. Heavy/one-time skills stay manual. Decision: D-20260812-proactive-capture-cadence. Spec:
`docs/specs/2026-08-12-proactive-capture-cadence-design.md`.

### A-20260712-project-status — build /project-status per spec
- Workstream: skills
- Status: done
- Created: 2026-07-12
- Completed: 2026-08-14
- Commit: 3f06e8c (PR #23, merged to main)

Shipped `/project-status` per docs/specs/2026-07-12-project-status-design.md: read-only
report/brief status view over `<data_root>/project-tracking/` with workstream/priority
filters, sidecar-aware via resolve-data-root.sh, model invocation enabled ("what's next"
triggers). Keystone's report/brief shapes borrowed (MIT); its registry data model dropped.
First sub-slice of tracking-skills-roundout. Plugin v0.19.0 (spec targeted v0.13.0; five
releases landed between spec and build). Spawned by D-20260712-project-status-design.

### A-20260817-portable-layer-refresh — opt-in --refresh on the portable-layer stamper (v0.20.0)
- Workstream: memory
- Status: done
- Created: 2026-08-17
- Completed: 2026-08-17
- Commit: f9cacb2 (PR #24, merged to main)

Shipped `--refresh` on `scripts/stamp-portable-layer.sh`, wired through as `/make-portable
refresh` with a confirm gate. Re-copies the vendored `memory_graph.py` and the operator's manual
so a base stamped at an older version can pick up new validator modes; `AGENTS.md` reports
`skipped`, facts and the index are never written. `copy_if_absent` became `stamp_file` with a
`refreshable` parameter; status vocabulary grew to created/exists/refreshed/current/skipped. The
add-only default is byte-identical, so `/project-init` is unaffected. Tests 20 → 36 (incl. facts
and index md5-unchanged across a refresh); full suite 185 pass; validate-plugin clean.
Decision: D-20260817-portable-refresh-scope.

Note: the motivating example was not reproducible locally. `Codebase\_meta` has no portable layer
at all (no `tools/memory_graph.py`, no `conventions/memory-base-guide.md`), so it needs plain
`/make-portable`, not `refresh`. No genuinely stale base was available to test against.

### A-20260819-memory-provenance-fields — verified-against + applies-to frontmatter fields (v0.21.0)
- Workstream: schema
- Status: done
- Created: 2026-08-19
- Completed: 2026-08-24
- Commit: 3adde70 (PR #27, merged to main)

Two optional additive fact fields, absent = today's behaviour byte-identical. `verified-against:
<sha> <date>` records the **source** repo's commit a fact was last confirmed at, consumed as a
fourth, advisory **UNVERIFIED-SINCE** bucket in `--check-citations`: the citation still resolves but
a cited file changed after that sha, so nobody has confirmed the claim since the code moved. That is
the gap the existing lint is structurally blind to (it validates the anchor, not the claim).
`applies-to: branch:<name>|repo:<name>` scopes a fact; reported, never gated. Closes both
`memory-volatility-field` and `memory-applies-to-field`. Decision:
D-20260819-memory-provenance-fields.

Tests 185 → 200 across nine harnesses: all three degradation paths pinned to exit 0, and a guard
that a fact *quoting* the schema in its body (past a `---` rule) yields no phantom field. Verified
end-to-end that `/make-portable refresh` propagates the revised manual to a base stamped before this
change, which is the delivery path the spec depends on.
Two implementation constraints the spec missed, both caught while reading code: `git diff
--name-only` prints repo-root-relative paths (rejoined onto the repo root, since `--src-root` may be
a subdirectory where raw output silently never matches), and the freshness test builds a git repo at
test time because a nested `.git` cannot live in a static fixture. One plan prediction was wrong:
the report prints norm stems (`fact_scoped`), not the literal filename.

### A-20260824-guardrail-conversational-authoring — /guardrails: conversational guardrail rule authoring
- Workstream: workflow
- Status: done
- Created: 2026-08-24
- Completed: 2026-08-24
- Commit: 5c740be (PR #29, merged to main, v0.22.0)

Promoted from the guardrail-conversational-authoring idea (EC2 audit 2026-08-24). Shipped
`scripts/guardrails-upsert.sh` (deterministic add/remove/list over the resolved guardrails.json —
fail-loud, atomic, jq-dialect regex validation, sidecar-aware), the `/guardrails` skill
(elicit → route → draft → dry-run through `hooks/guardrail.sh` → propose-confirm → apply), a
capture-cadence nudge line, and `tests/test-guardrails-upsert.sh` (37 cases, incl. an engine
round-trip proving a script-written sidecar rule denies through the real hook). Decision:
D-20260824-guardrails-canonical-hookify-misfits. Spec + plan: docs/specs+plans 2026-08-24.

### A-20260824-multi-tracking-root — cross-tier A-/D- link resolution in memory_graph.py
- Workstream: schema
- Status: done
- Created: 2026-08-24
- Completed: 2026-08-24
- Commit: f5972a6 (PR #30, merged to main, v0.22.1 — link-resolution half of one-project-many-checkouts)

`--tracking-root` is now repeatable (union harvest; `--check-tracking` aggregates across roots;
default unchanged when omitted), so workspace-tier facts resolve `A-`/`D-` records living in any
repo tier. Kills the 10 permanently-reported false-positive "broken links" the EC2 audit measured
at the UDX workspace tier — the noise that trains you to ignore lint output. `/memory-lint`
workspace-tier instructions now pass one `--tracking-root` per `<workspace_root>/*/project-tracking`
via glob. Remaining halves of the idea stay open: `propagated-to:` schema line, `/branch-matrix`.

### A-20260824-dispatch-ledger — local-only subagent dispatch ledger + summary
- Workstream: meta
- Status: done
- Created: 2026-08-24
- Completed: 2026-08-24
- Commit: f52790e (PR #31, merged to main, v0.23.0)

Promotes the dispatch-ledger idea (EC2 audit 2026-08-24; the ~484k-token re-derivation).
Ships `hooks/dispatch-ledger.sh` (PostToolUse on `Task|Agent`: one JSONL entry per dispatch —
agent, desc≤120, prompt/response sizes, est_tokens, opportunistic harness tokens/duration —
fail-open everywhere, no prompt/response text ever stored) writing to
`~/.claude/workspace-os/dispatch-ledger.jsonl` (user-global: outside every repo by
construction, satisfying the never-ships-to-an-employer-repo constraint without per-mode
paths — the location decision, folded here rather than a D- record), plus
`scripts/dispatch-ledger-summary.sh` (fail-loud read-back: totals, per-agent, top-N,
--repo filter, torn lines skipped+counted). Spec:
`docs/specs/2026-08-24-dispatch-ledger-design.md`.
