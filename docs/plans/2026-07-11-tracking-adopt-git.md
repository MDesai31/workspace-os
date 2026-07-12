# /tracking-adopt git (slice 2: git-history archaeology) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `git` mode to `/tracking-adopt` — bounded git-history mining into `resolved.md` records (one per merged unit, SHA/PR# dedup), with opportunistic gh enrichment and doc-completed cross-match.

**Architecture:** Pure SKILL.md prose (Approach A, D-20260711-tracking-adopt-git-design) — no helper script. The routing/bound/dedup rules land in `conventions/project-tracking.md` (SoT); the skill references them and spells out only the reproducible `git log` command shapes. Contract unchanged from slice 1: propose → confirm → apply; sources read-only; idempotent; no auto-commit.

**Tech Stack:** Claude Code plugin (markdown skills + conventions docs). No code/runtime; verification is structural checks + a scratch-repo dogfood with real git history + a propose-only self-run on workspace-os.

## Global Constraints

- Spec: `docs/specs/2026-07-11-tracking-adopt-git-design.md`. Every task implicitly includes its invariants.
- **Git mode routes to `resolved.md` ONLY.** OUT: decision mining from commit/PR prose, open branches/issues → actions, inline code TODOs, any change to docs-only mode routing.
- **Plain `/tracking-adopt` behavior stays byte-identical** — all new behavior lives behind the explicit `git` argument (the docs-only skip-route wording may point at the git mode, but the docs-only *behavior* is unchanged: completed items are still not imported by it).
- Record shape: action template + `Completed:` + `Commit:`; ID = `A-<merge-date>-slug`; Status `done`; provenance line `Imported from git history by /tracking-adopt git.`
- Dedup primary key = SHA/PR# against `resolved.md`; secondary = slug/content.
- gh/GitHub-MCP enrichment is opportunistic — any failure degrades silently; never required, never blocks.
- Default bound: newest reachable tag, else last ~30 merged units; explicit range overrides; batch cap ~30 (propose newest, tell user how to continue).
- Sidecar-mode invariants from the current SKILL.md (Step 0) apply to the git mode unchanged.
- No secrets written (commit messages / PR bodies can carry tokens — scan them). No auto-commit in the target repo.
- Plugin version bumps `0.11.0` → `0.12.0` in Task 3.
- BASE for subagent-driven review = the commit recorded before dispatching each implementer (never `HEAD~1`).
- Branch: `tracking-adopt-git` (already exists; spec + D-/A- records committed at `4c7c484`).

---

### Task 1: SoT update — git-mode routing in `conventions/project-tracking.md`

**Files:**
- Modify: `conventions/project-tracking.md` (rewrite one routing bullet inside `## Adopting existing docs (\`/tracking-adopt\`)`; insert a new `### Git-history archaeology (\`/tracking-adopt git\`)` sub-subsection before `## Concurrency`)

**Interfaces:**
- Produces: the git-mode routing/bound/dedup rules that `skills/tracking-adopt/SKILL.md` (Task 2) references. Sub-subsection heading must be exactly `### Git-history archaeology (\`/tracking-adopt git\`)`.

- [ ] **Step 1: Rewrite the completed-route bullet**

In `conventions/project-tracking.md`, replace exactly this bullet (inside the routing list of `## Adopting existing docs`):

```markdown
- completed / checked `- [x]` / changelog "done" → **skip for now** (belongs in `resolved.md`, which
  needs a real commit ref — adopted via git history in a later slice, not from prose);
```

with:

```markdown
- completed / checked `- [x]` / changelog "done" → **docs-only mode: skip** (a resolved record
  needs a real commit ref, which prose cannot supply — run `/tracking-adopt git`); **git mode:
  cross-match** against the mined units (see "Git-history archaeology" below) — matched → enriches
  that unit's single record, unmatched → stays skipped and reported;
```

- [ ] **Step 2: Insert the git-mode sub-subsection**

Insert immediately after the closing paragraph of `## Adopting existing docs` (the paragraph ending `Apply only on explicit confirmation.`) and before `## Concurrency`:

```markdown
### Git-history archaeology (`/tracking-adopt git`)

The explicit `git` mode adds **git history** as a source and produces **`resolved.md` records
only** — the one record type prose cannot legitimize, because a resolved record needs a real
`Commit:` ref. One record per **merged unit**: a merge commit, a squash commit carrying a `(#N)`
PR marker in its subject, or a model-grouped run of related direct-to-main commits;
chore/typo/CI/formatting/version-bump noise is skipped, never recorded.

**Bound:** default = since the newest reachable tag if one exists, else the last ~30 merged
units; an explicit git range argument (`v1.0..HEAD`, `HEAD~50..`, `--all`) overrides. Over ~30
candidates → propose the newest ~30 and report how to continue with an explicit range.

**Record shape:** the action template plus `- Completed:` (merge date) and `- Commit:` (SHA, plus
`(PR #N)` when known); ID = `A-<merge-date>-slug` — dated by when the work **landed**, so imports
sort naturally and re-runs mint identical slugs; `Created:` = the PR open date when enrichment
supplies it, else the merge date; Status `done`; a 2–4 line body from the PR body / commit
messages ending `Imported from git history by /tracking-adopt git.`

**Enrichment is opportunistic:** with a GitHub remote and a working `gh`/GitHub MCP, fetch PR
title/body/open-date; on **any** failure (no remote, no auth, offline) degrade silently to commit
messages. Never required, never blocks.

**Dedup key: the SHA/PR#.** Skip any candidate whose SHA or PR number already appears in
`resolved.md` — covers prior imports *and* organic `/project-log done` records. Slug/content
match is secondary. Re-running the same range proposes nothing new.

**Out of scope (deliberate):** decision mining from commit/PR prose ("chose X because Y" → `D-`)
and open branches/stale issues → `action-items.md` — fuzzy and noisy; deferred, not implied.
```

- [ ] **Step 3: Verify placement and cross-references**

Run: `grep -n "^## \|^### " conventions/project-tracking.md`
Expected: `### Git-history archaeology (\`/tracking-adopt git\`)` appears after `## Adopting existing docs (\`/tracking-adopt\`)` and before `## Concurrency`.

Run: `grep -c "skip for now" conventions/project-tracking.md`
Expected: `0` (the old bullet is gone).

- [ ] **Step 4: Commit**

```bash
git add conventions/project-tracking.md
git commit -m "docs(tracking): git-history archaeology rules for /tracking-adopt git (SoT)"
```

---

### Task 2: SKILL.md git mode + scratch dogfood

**Files:**
- Modify: `skills/tracking-adopt/SKILL.md` (frontmatter `description` + `argument-hint`; one intro sentence; new `## Git mode` section after `## Steps`; rewrite `## Known limitations`)

**Interfaces:**
- Consumes: the `### Git-history archaeology (\`/tracking-adopt git\`)` rules from Task 1; the existing Steps 0–9 (data root, bootstrap, confirm/apply/report machinery) already in the SKILL.md.
- Produces: the `/tracking-adopt git [range]` mode. The existing `## Steps` section is NOT renumbered or edited except where shown.

- [ ] **Step 1: Update the frontmatter**

In `skills/tracking-adopt/SKILL.md`, replace the frontmatter `description:` line with:

```yaml
description: Adopt a repo's existing roadmap / TODO / decision docs into docs/project-tracking/, and (git mode) its merged git history into resolved.md. Use when starting workspace-os in a repo that already has work-state docs or a real commit history you want captured as tracking records. Opt-in; propose-confirm-apply; never auto-runs.
```

and replace the `argument-hint:` line with:

```yaml
argument-hint: "[path or glob to limit the scan] | git [range]   (docs scan by default; git mode mines merged history — default bound: newest tag, else last ~30 merged units)"
```

- [ ] **Step 2: Add one intro sentence**

At the end of the second intro paragraph (the one ending `the two are complementary.`), append this sentence:

```markdown
The explicit **`git` mode** (`/tracking-adopt git [range]`) additionally mines merged git history
into `resolved.md` — see "Git mode" below.
```

- [ ] **Step 3: Insert the Git mode section**

Insert between the end of `## Steps` (after step 9) and `## Known limitations`:

```markdown
## Git mode (`/tracking-adopt git [range]`)

Adds **git history** as a source; routes to **`resolved.md` only**. The routing, record shape,
bound, and dedup rules live in `conventions/project-tracking.md` ("Git-history archaeology") —
read them and follow them exactly; do not restate them here. Steps 0–1 above (data root,
bootstrap) run unchanged; then:

G2. **Bound the walk.** With a `[range]` argument, pass it to `git log` verbatim. Otherwise:
    default branch = `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||'`
    (fallback: the current branch); bound = `$(git describe --tags --abbrev=0)..HEAD` when a tag
    exists, else the last ~30 merged units. Announce the resolved bound.
G3. **Mine candidate units.** Walk
    `git log --first-parent --date=short --pretty=format:'%h%x09%ad%x09%s%x09%b%x1e' <bound>`
    on the default branch. One unit per: **merge commit**; **squash commit with a `(#N)` PR
    marker** in its subject; a **model-grouped run of related direct-to-main commits**
    (judgment). Skip noise — chore/typo/CI/formatting/version-bump — never record it.
G4. **Enrich opportunistically.** If a GitHub remote exists and `gh` (or the GitHub MCP) works,
    fetch `gh pr view <N> --json title,body,createdAt` for candidate PR numbers. On **any**
    failure, degrade silently to commit messages — enrichment never blocks or fails the run.
G5. **Cross-match doc-completed items.** Run the docs scan (Step 2 globs) for **completed items
    only** (checked `- [x]`, changelog "done"); match each against the mined units by content
    similarity. Matched → enrich that unit's single record (the doc phrasing may improve the
    title/body); never a second record. Unmatched → skip and report — prose alone does not
    legitimize a resolved record.
G6. **Dedup.** Primary key = **SHA/PR#**: skip any candidate whose SHA or PR number already
    appears in `resolved.md` (prior imports and organic `/project-log done` records alike).
    Secondary: slug/content, as in Step 4 above.
G7. **Secret-scan** each proposed record — commit messages and PR bodies can carry tokens
    (same rule as Step 5 above).
G8. **Propose one batch:** one `resolved.md` record per unit, per the SoT record shape
    (`A-<merge-date>-slug`, `Created:`/`Completed:`/`Commit:`, Status `done`, workstream from the
    repo enum, 2–4 line body + provenance line). Each proposal shows the SHA/PR# and the
    enrichment/cross-match source. Over ~30 candidates → propose the newest ~30 and say how to
    continue with an explicit range.
G9. **Confirm → Apply → Report** exactly as Steps 7–9 above. `resolved.md`'s italic placeholder
    is `_Nothing resolved yet._` — replace it on first write. All sidecar rules and the
    no-auto-commit rule apply unchanged.
```

- [ ] **Step 4: Rewrite Known limitations**

Replace the entire `## Known limitations` section with:

```markdown
## Known limitations

- **Git mode routes to `resolved.md` only.** Decision mining from commit/PR prose and open
  branches/stale issues → `action-items.md` are deliberately deferred (fuzzy, noisy); inline code
  `// TODO`s are not mined.
- **Candidate set is fixed** to the globs above (minus `<data_root>/project-tracking/` and
  `<data_root>/memory/`). Other docs are scanned only if named in the path/glob argument.
```

- [ ] **Step 5: Verify structure**

Run: `grep -n "^## \|^G[0-9]" skills/tracking-adopt/SKILL.md`
Expected: sections in order `# Tracking Adopt` … `## Steps`, `## Git mode (\`/tracking-adopt git [range]\`)` (with G2–G9), `## Known limitations`. No renumbering of Steps 0–9.

Run: `grep -c "do not restate them here" skills/tracking-adopt/SKILL.md`
Expected: `1` (the git mode points at the SoT).

Run: `grep -c "Slice 1 is docs-only" skills/tracking-adopt/SKILL.md`
Expected: `0` (old limitation wording replaced).

- [ ] **Step 6: Scratch-repo dogfood (propose-only, real git history)**

Set up a throwaway repo (NOT a real project):

```bash
D=$(mktemp -d); cd "$D"; git init -qb main
git commit -q --allow-empty -m "chore: init"
git checkout -qb feat/login
git commit -q --allow-empty -m "add login form" -m "Session cookie auth, /login route."
git checkout -q main
git merge -q --no-ff feat/login -m "Merge branch 'feat/login'"
git commit -q --allow-empty -m "Billing engine: invoices + tax (#7)" -m "Adds invoice generation and tax calculation."
git commit -q --allow-empty -m "chore: bump version"
cat > README.md <<'EOF'
# Demo
## Done
- [x] login form
- [x] search filters
EOF
git add README.md && git commit -q -m "docs: add readme"
```

Then, following `skills/tracking-adopt/SKILL.md` **git mode** against `"$D"` (no range argument), confirm the **proposal** (do not apply) would:
- resolve the bound to "no tags → last ~30 merged units";
- propose the `feat/login` **merge commit** as one record (merge date, merge SHA);
- propose the `(#7)` **squash commit** as one record (`Commit: <sha> (PR #7)`); gh enrichment fails silently (no remote);
- **skip** `chore: bump version` and `docs: add readme` as noise;
- **cross-match** `- [x] login form` → enriches the login record (no second record);
- report `- [x] search filters` as **unmatched → skipped**;
- write nothing (propose-only check).

Also verify plain-mode isolation: run the docs-only mode reading of the SKILL.md against the same repo and confirm the two `- [x]` items are still skipped (not imported) — docs-only behavior unchanged.

Record the outcome in the SDD progress notes. Clean up: `rm -rf "$D"`.

- [ ] **Step 7: Commit**

```bash
git add skills/tracking-adopt/SKILL.md
git commit -m "feat(tracking): /tracking-adopt git mode — history mining into resolved.md (slice 2)"
```

---

### Task 3: Finalize — manifest, docs, self-run check, tracking close-out

**Files:**
- Modify: `.claude-plugin/plugin.json` (version only — description already names `tracking-adopt`)
- Modify: `README.md`, `ARCHITECTURE.md`, `PORTABILITY_NOTES.md` (git-mode mentions)
- Modify: `docs/project-tracking/action-items.md`, `docs/project-tracking/resolved.md`, `docs/project-tracking/ideas.md` (close-out)

**Interfaces:**
- Consumes: the shipped SoT rules (Task 1) + git mode (Task 2); the open record `A-20260711-tracking-adopt-git` in `action-items.md`.

- [ ] **Step 1: Bump the manifest**

In `.claude-plugin/plugin.json`: set `"version": "0.12.0"`. (The description already lists `tracking-adopt`; leave it.)

- [ ] **Step 2: Update the three docs**

In `README.md`, replace the `/tracking-adopt` bullet with:

```markdown
- **`/tracking-adopt`** — adopt a repo's existing roadmaps and TODO docs into `docs/project-tracking/` (routes roadmap entries → ideas, recorded decisions → decisions-log, open TODOs → action-items); the `git` mode mines merged history into resolved.md (one record per merged unit, real commit SHAs, SHA-deduped).
```

In `ARCHITECTURE.md`, replace the `/tracking-adopt` diagram line with:

```
/tracking-adopt ──routes──▶ existing roadmap/TODO docs ──▶ docs/project-tracking/  (git mode: merged history ──▶ resolved.md)
```

In `PORTABILITY_NOTES.md`, find the `/tracking-adopt` sentence (line ~37, `grep -n "tracking-adopt" PORTABILITY_NOTES.md`) and append to it: ` The \`git\` mode additionally mines merged git history into resolved-record proposals (local git is the base; \`gh\` enrichment is optional).` Also update the "remaining adoption sub-slices" sentence (line ~41) to name only sub-slice (a) foreign memory-format conversion.

- [ ] **Step 3: Propose-only self-run on workspace-os (spec success-criterion b)**

Following the updated SKILL.md git mode against the workspace-os repo itself (default bound), verify — **propose-only, apply nothing**:
- candidate units cover the recent merged PRs (#12–#15 era squash commits with `(#N)` markers);
- every unit whose SHA/PR# already appears in `docs/project-tracking/resolved.md` (e.g. `4d9b40a` / PR #14, `0c7ac16` / PR #13, `f99188b` / PR #12) is **skipped by SHA/PR# dedup** — zero duplicate proposals;
- summarize the outcome in the SDD progress notes.

- [ ] **Step 4: Tracking close-out**

Move the whole `A-20260711-tracking-adopt-git` record out of `docs/project-tracking/action-items.md` (restore the `_No open items yet._` placeholder if it becomes empty) and append it to `docs/project-tracking/resolved.md`, changing `- Status: open` to `- Status: done` and appending:

```markdown
- Completed: 2026-07-11
- Commit: <fill the Task1..Task3 commit range on the tracking-adopt-git branch>
```

plus a short body paragraph summarizing what shipped (git mode G2–G9, SoT sub-subsection, v0.12.0, dogfood outcome).

Update the `adoption-import` entry in `docs/project-tracking/ideas.md`:
- add a `**Shipped (v0.12.0):**` line — sub-slice (b.2) git-history + resolved.md import via `/tracking-adopt git`; see `resolved.md` A-20260711-tracking-adopt-git; decision D-20260711-tracking-adopt-git-design;
- update the `**Remaining sub-slices:**` line to name only `(a) foreign memory-format conversion`;
- update the "To start remaining sub-slices, future-us needs:" line accordingly (drop the tracking-doc-import clause).

- [ ] **Step 5: Verify manifest + docs**

Run: `grep '"version"' .claude-plugin/plugin.json && grep -c "git mode\|git\` mode" README.md ARCHITECTURE.md PORTABILITY_NOTES.md`
Expected: version `0.12.0`; each doc ≥ 1 mention.

Run: `bash tests/run-all.sh 2>/dev/null || for t in tests/test-*.sh; do bash "$t"; done`
Expected: all existing suites still pass (this slice touches no scripts, but confirm no accidental breakage).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(tracking): finalize /tracking-adopt git — manifest 0.12.0, docs, close-out"
```

---

## Post-plan gates (not tasks)

- Whole-branch review + single fix wave (SDD rhythm), then PR `tracking-adopt-git` → `main`.
- **Gated live dogfood on Options Analyzer (user-run):** `/tracking-adopt git` over OA's history — doubles as OA's real tracking adoption. **Merge only after the dogfood passes** (slice-1 gate). CI green before merge (advisory but load-bearing — feedback rule).

## Self-Review (run before execution)

- **Spec coverage:** §3 invocation/bound → Task 1 Step 2 + Task 2 Steps 1, 3 (G2); §4 mining → G3; §5 enrichment → G4 + SoT paragraph; §6 record shape/cross-match → SoT + G5, G8; §7 dedup → SoT + G6; §8 safety → Global Constraints + G7, G9; §9 deliverables 1–4 → Tasks 1, 2, 3; §10 success criteria (a) → Task 2 Step 6 isolation check, (b) → Task 3 Step 3, (c) → SHA-dedup rule (G6) exercised in Task 3 Step 3. No gaps; OA dogfood is a post-plan gate by design.
- **Placeholder scan:** the only `<...>` is the resolved.md `Commit:` range filled at finalize (intentional, same as slice 1). No TBD/TODO-as-instruction.
- **Name consistency:** SoT heading `### Git-history archaeology (\`/tracking-adopt git\`)` matches the SKILL.md pointer text; G-step numbering (G2–G9) referenced consistently; provenance line, placeholder `_Nothing resolved yet._`, and `A-<merge-date>-slug` identical across Task 1/Task 2/SoT.
