# /tracking-adopt git — Design Spec (slice 2: git-history archaeology)

**Date:** 2026-07-11
**Status:** Approved design, ready for plan
**Idea:** `adoption-import` sub-slice (b.2), `ideas.md`
**Relates to:** slice 1 (D-20260627-tracking-adopt-design, `docs/specs/2026-06-27-tracking-adopt-design.md`), `conventions/project-tracking.md` (SoT)

---

## 1. Summary

Slice 2 adds **git history as a source** for `/tracking-adopt`, behind an explicit new mode:
`/tracking-adopt git [range]`. It mines the repo's merged work (merge commits, squash-merged
PRs, grouped direct-to-main commits) and files it as **`resolved.md` records** — the one record
type slice 1 could not legitimately produce, because a resolved record needs a real `Commit:`
ref and prose does not supply one. Git history does.

Same contract as slice 1: **propose → confirm → apply**, sources read-only, never commits (the
target repo), idempotent re-runs. The plain docs-only invocation `/tracking-adopt` is
**byte-identical in behavior** to slice 1; all new behavior lives behind the `git` mode.

Delivery is **pure SKILL.md prose** (Approach A) — no helper script. The mining commands are
spelled out exactly in the skill so runs are reproducible; the judgment work (noise filtering,
grouping, summarizing) is the model's, which is where a script adds nothing. This matches how
every adopt skill has shipped.

## 2. Scope

**In (slice 2):**
- The `git` mode: bounded history mining → proposed `resolved.md` records, one per merged unit.
- Opportunistic `gh`/GitHub-MCP enrichment of PR titles/bodies (never required).
- Doc-completed **cross-match**: checked `- [x]` / changelog-done items matched against mined
  units enrich the matching record; unmatched items stay skipped (the "resolved.md import" half
  of the idea).
- SHA/PR#-based dedup so re-runs and organically-logged records never duplicate.
- SoT update: `conventions/project-tracking.md` completed-route rewritten from "skip for now /
  later slice" to the git-mode routing + dedup rule.

**Out (this slice):**
- **Decision mining** from commit/PR prose ("chose X because Y" → `D-` records) — fuzzy; most
  commits are not decisions. Deferred; noted in Known limitations.
- **Open branches / stale issues → `action-items.md`** — noisy inference. Deferred.
- **Inline code `// TODO`/`# FIXME` mining** — still deferred (unchanged from slice 1).
- Any change to the docs-only mode's routing or output.

## 3. Invocation & history bound

`/tracking-adopt git [range]`:

- `[range]` is an optional git revision range passed through to `git log` (e.g. `v0.9.0..HEAD`,
  `HEAD~50..`, `--all`).
- **Default bound** (no range given): since the newest tag reachable from the default branch
  (`git describe --tags --abbrev=0`) if one exists; otherwise the **last ~30 merged units**.
- **Batch cap:** if the bound yields more than ~30 candidate units, propose the newest 30 and
  report how to continue with an explicit range (keeps the confirm gate reviewable).

The skill's `argument-hint` is updated to surface both modes.

## 4. Mining (local git is the base)

The SKILL.md states the exact command shapes — reproducible run-to-run, no script:

1. **Default branch:** `git symbolic-ref refs/remotes/origin/HEAD` (fallback: current branch).
2. **History walk:** `git log --first-parent <bound> <branch>` with a fixed pretty-format
   (sha, date, subject, body).
3. **Candidate units,** in priority order per commit:
   - a **merge commit** (merge-commit workflow) → one unit;
   - a **squash commit carrying a `(#N)` PR marker** in its subject (squash workflow) → one unit;
   - remaining **direct-to-main commits** → the model groups them into coherent units of work
     (judgment, not a rule);
   - **noise** — chore/typo/CI/version-bump/formatting commits — is skipped, never recorded.
4. Local-only/unpushed commits participate normally; nothing requires a remote.

## 5. Opportunistic gh enrichment

If a GitHub remote exists **and** `gh` (or the GitHub MCP) is available and authenticated, fetch
PR title/body/open-date for the candidate PR numbers to enrich summaries and the `Created:`
field. **Any** failure — no remote, no `gh`, no auth, offline — degrades silently to commit
messages alone. Enrichment can never fail or block the run, and is never a prerequisite.

## 6. Record shape & routing

Each candidate unit → exactly one proposed `resolved.md` record, using the SoT action template
plus the two resolution lines:

- **ID:** `A-<merge-date>-slug` — dated by when the work **landed**, so imported records sort
  naturally among organically-resolved ones and re-runs mint identical slugs (idempotency).
- **`Created:`** the PR open date when gh enrichment supplies it; else the merge date.
- **`Completed:`** the merge date. **`Commit:`** the merge/squash SHA, plus `(PR #N)` when known.
- **Status:** `done`. **Workstream:** tagged from the repo's `## Workstreams` enum; bootstrap /
  inference rules are unchanged from slice 1 (§5 there).
- **Body:** a 2–4 line summary from the PR body / commit messages, ending with the provenance
  line `Imported from git history by /tracking-adopt git.`

**Doc-completed cross-match:** in git mode, slice 1's completed-item detection (checked `- [x]`,
changelog "done") runs over the docs scan. Each completed doc item is matched against the mined
units by content similarity. **Matched** → it enriches that unit's single record (doc phrasing
may improve the title/body); never a second record. **Unmatched** → stays skipped and is
reported — prose alone still does not legitimize a resolved record (slice 1's rule stands).

## 7. Dedup & idempotency

- **Primary key: the commit SHA / PR#.** Skip any candidate whose SHA or PR number already
  appears in `resolved.md` — this covers both prior imports and records logged organically via
  `/project-log done` (whose `Commit:` field carries the same SHA/PR#).
- **Secondary:** slug/content match, as in slice 1.
- Re-running the same range proposes nothing new.

## 8. Safety & invariants (inherited)

- Propose one batch → **confirm** → apply; nothing written before confirmation.
- Sources read-only: git history is inherently read-only; source docs untouched.
- **Secret-scan every proposed record** — commit messages and PR bodies can carry tokens.
- **Sidecar mode:** records written to `<data_root>/project-tracking/resolved.md` only; sidecar
  repo committed after each write; the target repo's tree is never touched.
- **No auto-commit** in in-repo mode — staged-ready.
- Replace `resolved.md`'s italic placeholder line on first write (match the italic line, not a
  fixed string).

## 9. Deliverables

Docs-only slice, like slice 1:

1. `conventions/project-tracking.md` — the "Adopting existing docs" completed-route becomes the
   git-mode routing (one record per merged unit, SHA dedup, cross-match rule); a short
   `git` mode paragraph.
2. `skills/tracking-adopt/SKILL.md` — the `git` mode steps (§§3–7 here), updated
   `argument-hint`, updated Known limitations (decision/action mining from history and inline
   TODO mining stay deferred; "slice 1 is docs-only" wording replaced).
3. Plugin version bump; README / ARCHITECTURE touch-ups where they describe `/tracking-adopt`.
4. Tracking close-out: resolve the `A-` record, update the `adoption-import` idea entry.

## 10. Build & verification

- **Subagent-driven development:** per-task implement + review, whole-branch review, single fix
  wave — same rhythm as prior slices.
- **Live dogfood (gated, user-run): Options Analyzer** — rich real history and already queued to
  adopt workspace-os tracking; the import both tests this slice and delivers OA's adoption.
  Merge **after** the dogfood passes, the same gate slice 1 used.
- Success criteria: (a) plain `/tracking-adopt` behavior unchanged; (b) `git` mode on
  workspace-os itself proposes sensible units for the last ~10 PRs with correct SHAs and zero
  duplicates against the existing hand-written `resolved.md`; (c) re-run proposes nothing.
