# /tracking-adopt — Design Spec (slice 1: docs-only)

**Date:** 2026-06-27
**Status:** Approved design, ready for plan
**Idea:** `adoption-import` sub-slice (b), `ideas.md`
**Relates to:** `/memory-adopt` (sibling skill, D-20260626-memory-adopt-design), `conventions/project-tracking.md` (SoT)

---

## 1. Summary

`/tracking-adopt` is an opt-in, model-interpreted skill that reshapes a repo's pre-existing
**work-state** documentation into `docs/project-tracking/`. It is the tracking-side sibling of
`/memory-adopt`: where `/memory-adopt` extracts durable *knowledge* into `docs/memory/` and
**skips** work-state, `/tracking-adopt` **claims** that work-state — roadmaps, TODOs, and recorded
decisions — and files it as tracking records.

Same contract as `/memory-adopt`: **propose → confirm → apply**, source docs are **read-only**, the
skill **never commits**, and re-runs are **idempotent**. The passive default is unchanged: nothing
auto-touches existing docs; adoption is a deliberate, confirmed action the user invokes.

This spec covers **slice 1 (docs-only)**. Git-history archaeology and `resolved.md` routing are
deferred to slice 2 (see §8).

## 2. Scope

**In (slice 1):**
- Scan a repo's doc files for tracking-content and route it to `ideas.md`, `decisions-log.md`, and
  `action-items.md`.
- Bootstrap `docs/project-tracking/` if absent (mirrors `/project-init`), including seeding the
  workstream enum.
- Dedup, secret-scan, legacy-ID grandfathering, propose/confirm/apply, report.
- A new "Adopting existing docs" subsection in `conventions/project-tracking.md` (the SoT the skill
  references).

**Out (this slice):**
- **Git-history archaeology** (reconstructing tracking from `git log` / merged PRs / releases) → slice 2.
- **`resolved.md` routing** → slice 2, where a merged-PR commit SHA makes a `resolved` record's
  `Commit:` field legitimate. Importing a doc's changelog into `resolved.md` would manufacture
  "completed" records that were never tracked actions — inconsistent with the SoT's definition of
  `resolved.md` ("actions that were opened then completed").
- **Inline code `// TODO`/`# FIXME` mining** → slice 2 (high volume, better managed in-code).
- **`/memory-adopt` (c)/(d) hardening** (resolve CLAUDE.md `@imports`; widen globs) → a separate,
  small memory-adopt change, not bundled here.

## 3. Routing

Each detected chunk is classified by signal and routed to exactly one target file. Records follow
the templates in `conventions/project-tracking.md` (the skill does not restate them).

| Source signal | Target | Record |
|---|---|---|
| roadmap / "future" / "post-MVP" / "someday" / "out of scope" | `ideas.md` | Idea (Workstream, Priority, Intended-start *verbatim*, Why/context, "to start, future-us needs") |
| explicit decision — a "Key decisions" item, "Supersedes…", "we chose X because Y" | `decisions-log.md` | `D-YYYYMMDD-slug` (Workstream, Rationale, Spawns; body `[[wikilink]]`s the source doc) |
| open TODO / unchecked `- [ ]` / "next up" | `action-items.md` | `A-YYYYMMDD-slug`, Status `open` |
| checked `- [x]` / changelog "done" / completed | **skip (slice 1)** — deferred to `resolved.md` in slice 2 |
| not work-state (durable knowledge, an imperative, about-the-person) | **skip** — out of this skill's lane (knowledge is `/memory-adopt`'s) |

**Priority inference for ideas:** map source language to the enum (`high|mid|low|someday`) when the
doc signals it (e.g. "post-MVP"/"later" → `someday` or `low`); otherwise default `mid` and surface
it in the proposal for the user to adjust.

**IDs:** new `A-`/`D-` records use date-slug IDs (creation date = adoption date). Any pre-existing
`#`/letter IDs in source docs are **legacy** — grandfathered, referenced as-is, never rewritten
(per the SoT's ID rule).

## 4. Sources & detection

Candidate globs: `README*`, `docs/**/*.md`, `NOTES*`, `CLAUDE.md`, `TODO*`/`TODOS*`,
`CHANGELOG*`/`RELEASES*`. **Excluded:** `docs/project-tracking/` (never re-adopt itself) and
`docs/memory/`. Honors an optional path/glob argument to limit the scan.

Detection within a candidate file:
- **Section headers** whose title matches tracking intent: Roadmap, Future / Future Phases,
  Post-MVP, Out of scope, Backlog, TODO, Key decisions, Changelog/Releases.
- **Checkbox lists** anywhere: `- [ ]` (open) and `- [x]` (done).
- A chunk that is clearly durable knowledge (not work-state) is **left for `/memory-adopt`** and
  reported as out-of-lane, not routed.

## 5. Bootstrap & workstreams

If `docs/project-tracking/` does not exist, scaffold it exactly as `/project-init` does: stamp the
four files from the plugin's `templates/`, add the `merge=union` lines to `.gitattributes`, and
create `README.md` with the index + `## Workstreams`.

**Workstreams** are a per-repo enum (SoT §Workstreams). Because adoption has just scanned the repo's
docs, the skill **proposes an inferred workstream set** (derived from the docs' apparent areas of
work) as part of the confirmation batch, for the user to edit/confirm — rather than `/project-init`'s
cold "what workstreams?" prompt. If `docs/project-tracking/` already exists, tag records against its
existing `## Workstreams` list; any record that fits none is flagged with a proposed new workstream
(or parked) for the user to decide.

## 6. Steps (skill flow)

Mirrors `/memory-adopt`:

1. **Bootstrap if needed** (§5) — scaffold `docs/project-tracking/` + propose workstreams if absent.
2. **Scan candidates** (§4) — list what will be considered; honor the optional path/glob arg.
3. **Classify** each detected chunk through the routing table (§3).
4. **Dedup** — read existing tracking files; skip any record whose slug or content is already present.
5. **Secret-scan** — never write secrets into a record; flag the chunk instead.
6. **Propose one batch** — grouped by target file; each proposed record shows the deciding signal
   and source location; include the proposed/confirmed workstream set.
7. **Confirm** — wait for approve/edit/drop. Write nothing before this.
8. **Apply** — append records per the SoT templates. When a target file still shows its italic
   placeholder line, **replace** it (the wording differs per file — `_No ideas captured yet._`,
   `_No open items yet._`, `_No decisions logged yet._` — so match the italic placeholder line, not
   a fixed string; mirrors the `/memory-adopt` placeholder fix). **Never modify source docs.**
9. **Report** what was created per file + what was skipped/out-of-lane + why. **Do not commit.**

## 7. Safety & invariants

- **Source docs read-only.** The skill only ever writes under `docs/project-tracking/` (and, at
  bootstrap, the `.gitattributes` union lines + the scaffolded files). It never edits README, specs,
  NOTES, or CLAUDE.md.
- **Idempotent.** Re-running proposes nothing new once content is adopted (dedup by slug/content).
- **No secrets** written into records.
- **No auto-commit** — everything left staged-ready for the user.
- **Stays in its lane** — durable knowledge is not routed here; it's `/memory-adopt`'s job. The two
  skills are complementary and may be run back-to-back over the same repo.

## 8. Deferred to slice 2 (git-history archaeology)

A later slice adds git-history as a source for **docs-poor** repos: bounded `git log` (since last
tag / last N) + GitHub PRs/releases via the MCP/`gh` **if available** (portable: local git is the
base). Merged work → `resolved.md` (real `Commit:` SHA makes the record legitimate), commit/merge
rationale → `decisions-log.md`, open branches/issues → `action-items.md`. Grouped/summarized, not
one-record-per-commit. This is isolated because it is the harder, fuzzier problem (most commits are
not decisions) and warrants its own review + dogfood gate.

## 9. Build & verification

- **Subagent-driven development**: per-task implement + review, then an opus whole-branch review,
  then a single fix wave; plugin bumped to **0.4.0**; README / ARCHITECTURE / PORTABILITY updated;
  tracking close-out (`D-`/`A-` records, idea entry updated).
- **Live dogfood on klapp** (gated, user-run): klapp is an ideal target — a README "Roadmap
  (post-MVP)" section, a `docs/ideas.md` brainstorm, and a design spec with a "Key decisions"
  section (6 items) that `/memory-adopt` deliberately skipped. Merge **after** the dogfood passes,
  same gate as `/memory-adopt`.
- **Tasks (provisional):** T1 conventions adoption subsection; T2 `/tracking-adopt` SKILL.md +
  scratch dogfood; T3 finalize (manifest, docs, tracking). Confirmed when the plan is written.
