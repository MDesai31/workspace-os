# /memory-adopt Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/memory-adopt` resolve `@import`s and scan a wider default doc set, via a single always-loaded "instruction-file" class.

**Architecture:** Pure documentation/skill change — no code. Edit the source-of-truth conventions (`conventions/memory.md`), then the skill that defers to it (`skills/memory-adopt/SKILL.md`), then close out tracking + bump the plugin version. `/memory-adopt` is model-interpreted, so the "implementation" is the rules the model reads; "tests" are grep/consistency checks plus the repo's `scripts/validate-plugin.py`.

**Tech Stack:** Markdown; `scripts/validate-plugin.py` (dependency-free Python validator run by CI).

## Global Constraints

- **No rule duplication.** `conventions/memory.md` is the source of truth; `SKILL.md` references it and must not restate rules in a way that can drift. (Copied from spec §6 + SKILL.md L12-15.)
- **Two file classes, exact membership:** instruction files = `CLAUDE.md`, `AGENTS.md`, resolved `@import` targets (trimmable); free-form = `README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md` (read-only). (Spec §3, §5.)
- **`@import` resolution:** recursive, cycle-guarded, depth cap 5, repo-relative paths only; always skip `@docs/memory/MEMORY.md` and anything under `docs/memory/` or `docs/project-tracking/`. (Spec §4.)
- **Trim policy unchanged in kind:** only non-imperative memory-eligible lines, confirm-first, structure-preserving — only the *set of files it may act on* widens. (Spec §3.)
- **Validator must stay green:** every `skills/*/SKILL.md` keeps `name`/`description` frontmatter; `.claude-plugin/plugin.json` stays valid JSON. (Spec §7.)
- **Do not commit secrets; this repo is private (MDesai31/workspace-os), default branch `main`.** Work happens on branch `memory-adopt-hardening` (already created).

---

### Task 1: Rewrite the "Adopting existing docs" section in the SoT

**Files:**
- Modify: `conventions/memory.md:106-121` (the `## Adopting existing docs (/memory-adopt)` section)

**Interfaces:**
- Produces: the canonical instruction-file class definition, candidate set, `@import` rules, and generalized trim rule that Task 2's `SKILL.md` references.

- [ ] **Step 1: Replace the section.** Replace the entire current section (lines 106-121, from the `## Adopting existing docs (\`/memory-adopt\`)` heading through the line ending `**Never write secrets.**`, stopping before `## Concurrency`) with:

```markdown
## Adopting existing docs (`/memory-adopt`)

`/memory-adopt` bulk-applies the gates above to a repo's pre-existing docs (opt-in; the passive
default never auto-touches them). Route each chunk:

- durable codebase knowledge → a `docs/memory/` fact (`domain|convention|reference`);
- costly-if-unseen imperative → **stays put** (in the instruction file it lives in — see below);
- work-state (goal/status/TODO) → **skip** (belongs in tracking: `ideas.md`/`action-items.md`);
- about the person → **skip**.

**Candidate sources — two classes:**
- **Instruction files (always-loaded, trimmable):** `CLAUDE.md`, `AGENTS.md`, and any file reached
  by resolving `@import`s (below).
- **Free-form docs (read-only, extract-only):** `README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`,
  `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md`.

Always **exclude** `docs/memory/` and `docs/project-tracking/`. An optional path/glob argument
limits the scan to the given paths.

**Resolving `@import`s.** When scanning an instruction file, follow its bare `@path` import lines
(Claude Code import syntax) and scan the targets as further instruction files — **recursively**,
with a cycle guard (each path scanned once) and a **depth cap of 5**. **Repo-relative paths only:**
skip `@~/...`, absolute paths, and any path resolving outside the repo (note them in the report;
don't pull them in). Never follow `@docs/memory/MEMORY.md` or anything under `docs/memory/` /
`docs/project-tracking/`. Instruction-file membership is **sticky**: a file reached via `@import`
is trimmable even if it would otherwise be free-form.

**Trim rule.** Only lines that pass *as memory* (NOT costly-if-unseen) may be removed, only on
explicit confirmation, structure-preserving; imperatives are never trimmed. The trim acts on the
**instruction file the line lives in** — an `@import` target is trimmed in that target, not in
`CLAUDE.md`. **Free-form source docs are read-only** — never modified; adoption never *adds* lines
to an instruction file. **Idempotent:** before proposing, skip any fact whose slug or content is
already in `docs/memory/`. **Never write secrets.**
```

- [ ] **Step 2: Verify the new content is present and the old single-file phrasing is gone.**

Run: `grep -c "instruction file" conventions/memory.md && grep -n "Resolving \`@import\`s\|depth cap of 5\|sticky" conventions/memory.md`
Expected: count ≥ 3, and the three anchor phrases each found.

Run: `grep -n "adoption only trims CLAUDE.md, never adds to it" conventions/memory.md`
Expected: no match (old CLAUDE.md-only phrasing removed).

Run: `awk 'NR>=106 && /## Concurrency/{print NR": "$0}' conventions/memory.md`
Expected: `## Concurrency` still present immediately after the rewritten section (section boundary intact).

- [ ] **Step 3: Commit.**

```bash
git add conventions/memory.md
git commit -m "conventions(memory): instruction-file class + recursive @import resolution

Generalize the CLAUDE.md trim rule to an always-loaded instruction-file
class (CLAUDE.md + AGENTS.md + @import targets) and widen the candidate
set. SoT for the /memory-adopt hardening (spec 2026-06-28).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Update the `/memory-adopt` SKILL.md to match

**Files:**
- Modify: `skills/memory-adopt/SKILL.md` (intro L12-19; step 2 L28-30; step 6 L38-40; step 8 L44-45; delete "Known limitations" L49-57)

**Interfaces:**
- Consumes: the instruction-file class + `@import` rules + candidate set from Task 1's `conventions/memory.md`.
- Produces: a skill whose steps reflect the generalized rules without restating them.

- [ ] **Step 1: Generalize the intro deferral line.** Replace (L14):

```
the **adoption routing + CLAUDE.md trim + idempotency** rules
```

with:

```
the **adoption routing + instruction-file trim + idempotency** rules
```

- [ ] **Step 2: Generalize the non-destructive paragraph.** Replace the paragraph at L16-19:

```
This is **opt-in and non-destructive to source docs**: free-form docs are read only. The only
pre-existing source doc ever edited is `CLAUDE.md`, and only an approved trim, and only with your
confirmation.
```

with:

```
This is **opt-in and non-destructive to free-form docs**: `README`/`NOTES`/`docs/**` are read
only. The only files ever edited are **instruction files** (`CLAUDE.md`, `AGENTS.md`, and resolved
`@import` targets), and only an approved trim, and only with your confirmation.
```

- [ ] **Step 3: Rewrite step 2 (scan).** Replace L28-30:

```
2. **Scan candidates.** Glob `README*`, `docs/**/*.md`, `NOTES*`, and `CLAUDE.md` (honor the
   optional path/glob argument). **Exclude** `docs/memory/` and `docs/project-tracking/`. List
   what you'll consider.
```

with:

```
2. **Scan candidates.** Build the candidate set per `conventions/memory.md` — instruction files
   (`CLAUDE.md`, `AGENTS.md`) and free-form docs (`README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`,
   `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md`), honoring the optional path/glob
   argument. **Resolve `@import`s** in instruction files recursively (cycle-guarded, depth cap 5,
   repo-relative only) and add the targets as instruction files. **Exclude** `docs/memory/` and
   `docs/project-tracking/`. List what you'll consider, marking which are instruction files.
```

- [ ] **Step 4: Generalize step 6 (propose).** In L38-40, replace the single occurrence of:

```
one-line); for `CLAUDE.md`, the lines to extract → memory **and** the exact proposed trim; plus
```

with:

```
one-line); for each instruction file, the lines to extract → memory **and** the exact proposed trim; plus
```

- [ ] **Step 5: Generalize step 8 (apply).** Replace L44-45:

```
8. **Apply.** For each approved fact: write `docs/memory/<slug>.md` (fact schema from conventions)
   and append its index line to `MEMORY.md` under the matching type section (replacing the
   `_No facts yet._` placeholder if present). For the approved CLAUDE.md trim: remove exactly
   those lines, preserving the rest of the file. **Never modify free-form source docs.**
```

with:

```
8. **Apply.** For each approved fact: write `docs/memory/<slug>.md` (fact schema from conventions)
   and append its index line to `MEMORY.md` under the matching type section (replacing the
   `_No facts yet._` placeholder if present). For each approved trim: remove exactly those lines
   from the instruction file they live in (`CLAUDE.md` or the `@import` target), preserving the
   rest of the file. **Never modify free-form source docs.**
```

- [ ] **Step 6: Delete the "Known limitations" section.** Remove the entire block — the `## Known limitations` heading and both bullets under it (current L49-57, through the line ending `... named in the path/glob argument.`). The file should end after step 9.

- [ ] **Step 7: Verify the edits.**

Run: `grep -n "Known limitations" skills/memory-adopt/SKILL.md`
Expected: no match (block deleted).

Run: `grep -n "AGENTS.md\|Resolve \`@import\`s\|instruction file" skills/memory-adopt/SKILL.md`
Expected: matches in the non-destructive paragraph and step 2 (skill now knows the wider class).

Run: `grep -n "the approved CLAUDE.md trim\|and \`CLAUDE.md\`. \*\*Exclude" skills/memory-adopt/SKILL.md`
Expected: no match (old single-file step phrasings replaced).

- [ ] **Step 8: Run the plugin validator.**

Run: `python3 scripts/validate-plugin.py`
Expected: exits 0 / prints success — `skills/memory-adopt/SKILL.md` still has valid `name`/`description` frontmatter.

- [ ] **Step 9: Consistency check conventions ↔ skill.** Confirm both files name the same free-form set.

Run: `grep -o "RUNNING.md\|CONTRIBUTING.md\|ARCHITECTURE.md\|DEVELOPMENT.md" conventions/memory.md | sort -u && echo --- && grep -o "RUNNING.md\|CONTRIBUTING.md\|ARCHITECTURE.md\|DEVELOPMENT.md" skills/memory-adopt/SKILL.md | sort -u`
Expected: the two lists are identical (all four in each).

- [ ] **Step 10: Commit.**

```bash
git add skills/memory-adopt/SKILL.md
git commit -m "skill(memory-adopt): resolve @imports + wider candidate set

Steps now build the instruction-file class (CLAUDE.md + AGENTS.md +
resolved @import targets) and the wider free-form set, deferring rules
to conventions/memory.md. Removes the now-resolved Known limitations.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Tracking close-out + version bump

**Files:**
- Modify: `docs/project-tracking/decisions-log.md` (append decision)
- Modify: `docs/project-tracking/ideas.md` (mark sub-slices (c)/(d) shipped)
- Modify: `docs/project-tracking/action-items.md` (remove the open action)
- Modify: `docs/project-tracking/resolved.md` (append the completed action)
- Modify: `.claude-plugin/plugin.json` (version `0.4.0` → `0.5.0`)

**Interfaces:**
- Consumes: `A-20260628-memory-adopt-hardening` (already open in `action-items.md`).
- Produces: a clean tracking state ready for the PR.

- [ ] **Step 1: Append the decision record** to `docs/project-tracking/decisions-log.md` (append-only — add at the end):

```markdown
### D-20260628-memory-adopt-instruction-file-class — /memory-adopt treats CLAUDE.md + AGENTS.md + @import targets as one trimmable class
- Workstream: skills
- Created: 2026-06-28
- Rationale: trimming CLAUDE.md reduces always-loaded context once knowledge lives in on-demand memory; `@import` targets and `AGENTS.md` are *also* always-loaded (Claude Code via import; sibling agents respectively), so the same rationale and trim rule apply. `@import`s are resolved recursively (cycle-guarded, depth cap 5, repo-relative only) to match how the content is actually loaded. Free-form docs stay read-only.
- Spawns: A-20260628-memory-adopt-hardening

Closes `adoption-import` sub-slices (c) + (d). Spec: `docs/specs/2026-06-28-memory-adopt-hardening-design.md`.
```

- [ ] **Step 2: Mark the idea sub-slices shipped** in `docs/project-tracking/ideas.md`. In the `adoption-import` idea, insert a new bullet immediately **after** the existing `- **Shipped (v0.4.0):**` line:

```markdown
- **Shipped (v0.5.0):** sub-slices (c) + (d) — recursive `@import` resolution + wider candidate set, via the always-loaded **instruction-file class** (`CLAUDE.md` + `AGENTS.md` + `@import` targets, all trimmable). See `resolved.md` A-20260628-memory-adopt-hardening. Decision: D-20260628-memory-adopt-instruction-file-class.
```

  Then replace the existing `- **Remaining sub-slices:**` bullet (the long line listing (a)/(b.2)/(c)/(d)) with:

```markdown
- **Remaining sub-slices:** (a) foreign memory-format conversion (top-level `memory/`, wiki → workspace-os schema); (b.2) git-history + resolved.md import (slice 2).
```

- [ ] **Step 3: Move the action to resolved.** In `docs/project-tracking/action-items.md`, delete the entire `### A-20260628-memory-adopt-hardening` record and restore the file's body to its placeholder:

```markdown
_No open items yet._
```

  Then append the completed record to `docs/project-tracking/resolved.md` (at the end):

```markdown
### A-20260628-memory-adopt-hardening — /memory-adopt: resolve @imports + widen candidate set
- Workstream: skills
- Status: done
- Created: 2026-06-28
- Completed: 2026-06-28
- Commit: PR for branch memory-adopt-hardening

Introduced the always-loaded **instruction-file class** (`CLAUDE.md` + `AGENTS.md` + resolved
`@import` targets, all trimmable), recursive guarded `@import` resolution (cap 5, repo-relative
only), and a wider default candidate set. Closes `adoption-import` (c)+(d). Edited
`conventions/memory.md` (SoT) + `skills/memory-adopt/SKILL.md` (deleted its Known limitations
block). Spec `docs/specs/2026-06-28-memory-adopt-hardening-design.md`; plan
`docs/plans/2026-06-28-memory-adopt-hardening.md`. Decision
D-20260628-memory-adopt-instruction-file-class.
```

- [ ] **Step 4: Bump the plugin version.** In `.claude-plugin/plugin.json`, change `"version": "0.4.0"` to `"version": "0.5.0"`.

- [ ] **Step 5: Verify tracking + version.**

Run: `grep -c "A-20260628-memory-adopt-hardening" docs/project-tracking/action-items.md`
Expected: `0` (moved out).

Run: `grep -c "A-20260628-memory-adopt-hardening" docs/project-tracking/resolved.md && grep -c "D-20260628-memory-adopt-instruction-file-class" docs/project-tracking/decisions-log.md && grep -c "Shipped (v0.5.0)" docs/project-tracking/ideas.md`
Expected: `1` on each line.

Run: `python3 -c "import json;print(json.load(open('.claude-plugin/plugin.json'))['version'])"`
Expected: `0.5.0`

- [ ] **Step 6: Run the validator once more (post version bump).**

Run: `python3 scripts/validate-plugin.py`
Expected: exits 0 / success (manifest still parses with required keys).

- [ ] **Step 7: Commit.**

```bash
git add docs/project-tracking/ .claude-plugin/plugin.json
git commit -m "track+release: memory-adopt hardening shipped (v0.5.0)

Resolve A-20260628-memory-adopt-hardening, log
D-20260628-memory-adopt-instruction-file-class, mark adoption-import
(c)+(d) shipped, bump plugin 0.4.0 -> 0.5.0.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification (after all tasks)

- [ ] `python3 scripts/validate-plugin.py` exits 0.
- [ ] `grep -rn "Known limitations" skills/memory-adopt/SKILL.md` → no match.
- [ ] Conventions and SKILL.md name the same free-form set (Task 2 Step 9 passes).
- [ ] Dogfood reasoning re-check: walk the klapp case `CLAUDE.md → @AGENTS.md` through the updated step 2 — `AGENTS.md` is now reached both as a default candidate and via `@import`, classified, and trimmable. (Manual reasoning check; no klapp write.)
- [ ] `git log --oneline origin/main..HEAD` shows the spec commit + the three task commits.
- [ ] Hand off to `superpowers:finishing-a-development-branch` for the PR (wait for green CI before merge).
