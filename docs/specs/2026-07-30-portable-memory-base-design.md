# Portable Memory Base - Design Spec

- Date: 2026-07-30
- Status: draft (brainstorm approved; awaiting spec review)
- Related: `docs/project-tracking/ideas.md` [[memory-backlinks-search]], [[vendor-neutral-runtime]];
  interacts with the shipped `/ingest gotcha:` feature (`docs/specs/2026-07-27-ingest-gotcha-design.md`).

## 1. Goal

Make every memory base workspace-os produces self-describing and vendor-neutral, so a cold
non-Claude agent (or a human) can both READ and MAINTAIN it using plain file operations, with no
plugin, no slash commands, and no Claude runtime.

## 2. Motivation

An audit of the EC2 mirror of the user's `_meta` knowledge base asked: "if I could not use Claude
anymore, could another AI read and maintain this?" The content is portable (plain markdown, YAML
frontmatter, file:line provenance), but the SCAFFOLDING is Claude-coupled in a few load-bearing
places:

- The memory schema, the boundary rule, and the maintenance procedure live only in the plugin
  (`conventions/memory.md`), reachable through the runtime. A successor can read every fact and
  still not know how to write one.
- Maintenance verbs are bare slash commands (`/ingest`, `/memory-lint`) with no prose fallback.
- The entry point is `CLAUDE.md` only (in-repo) or a plugin SessionStart hook (sidecar) - both
  vendor-locked. No `AGENTS.md`.
- The wikilink grammar (multiple ID schemes across stores) is undocumented.

The key framing that scopes this work: there are two populations. The MAINTAINER runs Claude Code
plus the plugin (skills, hooks, auto-recall). The SUCCESSOR inherits the base if Claude is gone; it
installs nothing and runs no plugin. "Vendor-neutral" is a property of the ARTIFACTS the plugin
produces, never of the tool. This slice makes the artifacts survive the tool.

## 3. Scope

**In scope:**
- A portable operator's manual stamped into each memory base (the de-skilled procedure).
- A thin vendor-neutral `AGENTS.md` entry point; `CLAUDE.md` reduced to a bridge that imports it.
- Making `AGENTS.md` the canonical home for costly-first ("always-loaded") facts, and retargeting
  the shipped `/ingest gotcha:` write there (in-repo mode) for consistency.
- `/project-init` changes to stamp the above in both data-root modes.
- A small dedicated retrofit skill to add the portable layer to an already-initialized base.
- Vendoring `memory_graph.py` into each base as the runnable validator, plus documenting its checks
  in prose so the rules survive without Python.

**Out of scope / deferred (documented, not built):**
- Skills, hooks, and the plugin itself stay Claude-only. No attempt to make them run elsewhere.
- Ongoing multi-vendor USE (running workspace-os operations from Codex/Cursor/Gemini via an MCP
  server) is the separate `[[vendor-neutral-runtime]]` idea (~80% ceiling; the un-gettable 20% is
  enforced automation). Not this slice.
- **Tracking portability (D1 deferred):** the portable layer covers the MEMORY base only. Making the
  project-tracking records (`A-`/`D-`/action/idea) self-describing for a cold agent is an obvious
  fast-follow with the same pattern, but out of this spec to keep it focused.
- **Safety-caution documentation (D4 deferred):** the `guardrail` deny-rules are enforcement, not
  memory; documenting critical ones as prose cautions in `AGENTS.md` couples it to the guardrail
  config and belongs to the provenance-guard line of work. The manual notes in one line that
  enforcement hooks do not travel; it does not replicate the rules.
- **Sidecar costly-first capture:** in sidecar mode `/ingest gotcha:` remains tell-and-stop (repo
  tree untouched); no auto-write of costly-first facts. Unchanged by this spec.

## 4. Design overview

Three vendor-neutral artifacts per base:

1. **Operator's manual** - the de-skilled procedure (schema, boundary rule, maintenance recipes,
   wikilink grammar, provenance tiers, validator checks). Read on demand.
2. **`AGENTS.md`** - the thin, always-loaded entry point: discovery pointers plus the canonical
   "always-loaded instructions" section for costly-first facts. Kept small.
3. **`CLAUDE.md` bridge** - imports `@AGENTS.md` and `@docs/memory/MEMORY.md`, so Claude and any
   non-Claude agent read one canonical always-loaded file and the same index.

This mirrors the plugin's existing scale discipline: always-load only the small entry point and the
index; read the full manual and the fact files on demand.

## 5. The operator's manual (contents)

A single markdown doc. In-repo it lives at `docs/memory/README.md`; sidecar at
`_meta/conventions/memory-base-guide.md`. Contents:

- **What this base is** - a version-controlled, plain-markdown knowledge base; one fact per file
  plus a hand-curated index; no vector store, no proprietary index.
- **The fact schema** - the frontmatter (`name` matching the filename stem, `description`, `type`
  in `domain|convention|reference`) and body, quoted directly (not by reference to the plugin).
- **The boundary rule, vendor-neutral** - "if an agent would make a costly mistake before it went
  looking, the fact belongs in your ALWAYS-LOADED instruction file (`AGENTS.md`, or `CLAUDE.md` for
  Claude Code); otherwise it belongs in this base, read on demand." Decisions go to the tracking
  log, not memory.
- **Maintenance recipes as prose (the de-skilled verbs):**
  - Add a fact: decide the home with the boundary rule; if this base, write `<slug>.md` with the
    schema frontmatter, then add one line to `MEMORY.md` under the matching type section.
  - Check integrity: run `python memory_graph.py --check` (stdlib Python, no dependencies), OR apply
    the checks by hand (documented below).
  - The recipes note that `/ingest` and `/memory-lint` are the Claude Code shortcuts that automate
    exactly these steps; a successor does not need them.
- **The wikilink grammar** - plain `[[target]]` (edge type "related"); typed predicates
  `[[supersedes::target]]`, `[[blocked_by::target]]`, etc.; aliases `[[type::target|label]]`;
  targets may be fact slugs or `A-`/`D-` tracking records. This is the grammar the audit found
  undocumented.
- **The validator's checks, in prose** - broken wikilink (a link whose target has no fact file and
  is not a known tracking record); index parity (every fact file has exactly one `MEMORY.md` line
  and vice versa); orphans (facts nothing links to); typed-edge coverage. So a successor can validate
  by hand or reimplement even without running the script.
- **Provenance tiers** - source-verified vs attested; the dated-stamp and file:line-evidence
  discipline.

## 6. AGENTS.md and the CLAUDE.md bridge

`AGENTS.md` (in-repo, repo root), stamped skeleton:

```markdown
# Agent Instructions

This repo keeps a durable knowledge base under `docs/memory/`. It is plain markdown,
readable and maintainable by any agent or human without special tooling.

## Before working here
- Read `docs/memory/MEMORY.md` first - the index of what is known about this codebase
  (one line per fact). Open the specific fact files it lists when relevant.
- `docs/memory/README.md` is the operator's manual: the schema, and how to read, verify,
  and add facts with plain file operations (no plugin, no slash commands).

## Maintaining the base
- Add a fact: follow the procedure in `docs/memory/README.md`.
- Check integrity: `python docs/memory/memory_graph.py --check` (stdlib Python, no deps).

## Always-loaded instructions
<!-- Costly-if-unseen facts - ones an agent must see BEFORE acting or it makes a wrong
     move first - go here as imperative bullets. Managed section; see the manual. Empty
     until the first such fact is recorded. -->

## Stale priors (training vs reality)
<!-- Managed by /ingest gotcha:. Bullets: "<topic>: use <Y>, NOT <X> ...". -->
```

The skeleton shows two managed sections in the always-loaded region: a general "Always-loaded
instructions" area and the gotcha-specific "Stale priors (training vs reality)" section that
`/ingest gotcha:` writes to (section 7). Stale-priors is one flavor of always-loaded content; both
live in `AGENTS.md`.

`CLAUDE.md` becomes a bridge. `/project-init` writes (or repoints an existing `CLAUDE.md` to) the
imports:

```
@AGENTS.md
@docs/memory/MEMORY.md
```

so Claude always-loads the canonical `AGENTS.md` instructions plus the index. A non-Claude agent
reads `AGENTS.md` directly. Costly-first facts thus have one home both vendors see.

## 7. Interaction: /ingest gotcha retargets to AGENTS.md (required)

The shipped `/ingest gotcha:` flow writes costly-first stale-prior bullets to a managed
`## Stale priors (training vs reality)` section. With `AGENTS.md` canonical, that write must target
`AGENTS.md` (in-repo mode), not `CLAUDE.md` - otherwise a non-Claude successor, which reads only
`AGENTS.md`, silently misses exactly those costly-first facts (the audit's original complaint).

This is small: `scripts/claude-md-upsert.sh` already takes any file path and any managed heading, so
the change is (a) resolve the `AGENTS.md` path instead of `CLAUDE.md`, and (b) update the skill's
prose and confirm/report text accordingly. The helper's idempotent, add-only, `@import`-preserving
behavior is unchanged. Sidecar mode remains tell-and-stop.

The manual's boundary rule already names `AGENTS.md` as the always-loaded file, so schema and skill
agree.

## 8. Mode handling

- **In-repo:** manual at `docs/memory/README.md`; `AGENTS.md` and the bridged `CLAUDE.md` at repo
  root; `memory_graph.py` vendored at `docs/memory/memory_graph.py` (lives with the memory). True
  auto-discovery.
- **Sidecar (`_meta`):** repo working tree is never touched (data-root safety invariant), so there
  is no repo `AGENTS.md`. The manual lands at `_meta/conventions/memory-base-guide.md` and the
  validator at `_meta/conventions/memory_graph.py` (one shared copy, since sidecar has two memory
  tiers); the entry point stays `_meta/INDEX.md`, enriched with a pointer to the manual and a "Link
  grammar" pointer. Discovery is "correct but the operator must aim the agent at `_meta`" - inherent
  to sidecar. `CLAUDE.md`/`AGENTS.md` bridging and the gotcha retarget (section 7) apply to in-repo
  mode only.

## 9. workspace-os changes

- **New templates:** `templates/memory/README.md` (the manual), `templates/AGENTS.md`. Update
  `templates/memory/MEMORY.md`'s header to point at the local manual (`./README.md`) instead of the
  plugin cache.
- **`/project-init`:** stamp the manual + vendored `memory_graph.py`; write/repoint the `CLAUDE.md`
  bridge (`@AGENTS.md` + `@docs/memory/MEMORY.md`) and stamp `AGENTS.md` (in-repo); in sidecar,
  place the manual + validator under `_meta/` and enrich `INDEX.md`. Preserve idempotency and the
  sidecar no-repo-write invariant.
- **New retrofit skill** (section 10).
- **`/ingest` gotcha retarget** (section 7).
- **Plugin `conventions/memory.md`:** add one line naming the portable manual template as the
  canonical vendor-neutral statement of the schema, to bound drift.

## 10. Retrofit skill (D2)

A small dedicated user-invocable skill named `/make-portable` that adds the portable layer to an
ALREADY-initialized base without touching facts or the index.

- Resolves the data root (same `resolve-data-root.sh` as the other skills); handles both modes.
- Stamps the manual and vendored `memory_graph.py`; stamps/points `AGENTS.md` + `CLAUDE.md` bridge
  (in-repo) or enriches `INDEX.md` (sidecar).
- Idempotent and add-only: if an artifact already exists, it is left as-is (or offered as an update
  with confirmation); facts and `MEMORY.md` are never modified.
- Refuses cleanly if no base exists (points to `/project-init`).

## 11. memory_graph.py vendoring (D3) and drift control

- **Vendor the script** into each base so the validator runs with nothing but Python. Add a header
  comment noting the source path and the plugin version it was copied from.
- **Document the checks in prose** in the manual (section 5), so the validation RULES survive even
  without running the script.
- **Drift control:** the manual is a deliberately-minimal, stable "public contract"; the plugin's
  `conventions/memory.md` points to the manual template as canonical (section 9). Optional future
  `/memory-lint` check that a base's vendored manual/script matches the current plugin version
  (noted, not built here).

## 12. Deferred, documented

Recorded here and in the stamped manual where a cold reader would look:
- Tracking-record portability (D1) - fast-follow, same pattern.
- Safety-caution documentation (D4) - provenance-guard line of work; the manual states in one line
  that enforcement hooks do not travel.
- Sidecar costly-first auto-capture - remains manual/tell-and-stop.
- Multi-vendor runtime via MCP - the `[[vendor-neutral-runtime]]` idea.

## 13. Testing strategy

- **Template presence/content:** the new templates exist and contain the required sections (schema,
  boundary rule naming `AGENTS.md`, maintenance recipes, wikilink grammar, validator checks). Plain
  substring/exit-code bash asserts, matching the house test style.
- **`/project-init` (both modes):** stamps the manual, `AGENTS.md`, the vendored validator, and the
  `CLAUDE.md` bridge (in-repo); places the manual/validator under `_meta/` and enriches `INDEX.md`
  (sidecar); idempotent re-run adds nothing new; sidecar never writes the repo tree.
- **Retrofit skill:** on an initialized base, adds exactly the portable layer, leaves facts and
  `MEMORY.md` byte-unchanged; idempotent; refuses on an uninitialized base.
- **Vendored validator runs from its stamped location:** `python <base>/memory_graph.py --check`
  exits 0 on a clean base and non-zero on a seeded broken wikilink.
- **Gotcha retarget:** `/ingest gotcha:` (in-repo) writes the bullet to `AGENTS.md`'s managed
  section (not `CLAUDE.md`), idempotent on re-run, `@import`/content preserved; the existing
  `claude-md-upsert.sh` tests stay green.
- **No em dashes** in any added line; `validate-plugin.py` passes.

## 14. Resolved (were open questions)

- Retrofit skill name: **`/make-portable`** (verb-first, distinct from the `*-init` family).
- Manual filename: **`docs/memory/README.md`** in-repo; **`_meta/conventions/memory-base-guide.md`**
  sidecar.
- Vendored `memory_graph.py` location: **`docs/memory/memory_graph.py`** in-repo (with the memory);
  **`_meta/conventions/memory_graph.py`** sidecar (one shared copy for both tiers).

## 15. Records to create on completion

- Action record `A-20260730-portable-memory-base`.
- Decision record `D-20260730-agents-md-canonical` - `AGENTS.md` is the canonical always-loaded
  instruction file; `CLAUDE.md` becomes a bridge that imports it; costly-first facts (including the
  `/ingest gotcha:` write) target `AGENTS.md` in in-repo mode. Rationale ties to the boundary rule
  and the portability goal; notes this extends the `/ingest gotcha:` decision
  `D-20260727-ingest-gotcha-claudemd` (the costly-first home moves from `CLAUDE.md` to the
  vendor-neutral `AGENTS.md`, which `CLAUDE.md` now imports).
- Version bump on completion (minor).
- `ideas.md` [[memory-backlinks-search]] and the new `[[vendor-neutral-runtime]]` cross-reference.
