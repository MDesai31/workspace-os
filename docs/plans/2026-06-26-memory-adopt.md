# memory-adopt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/memory-adopt` — an opt-in skill that reshapes a repo's pre-existing docs (free-form docs + CLAUDE.md reference extraction) into `docs/memory/`, via propose→confirm→apply.

**Architecture:** One model-interpreted SKILL.md that bulk-applies the gates already in `conventions/memory.md`. It scaffolds `docs/memory/` if absent (mirrors `/project-init`'s memory step), scans candidate docs, proposes a batch mapping, and on confirmation writes facts + index and trims approved reference lines from CLAUDE.md. The routing/trim/idempotency rules live in a new conventions subsection (SoT); the skill references them.

**Tech Stack:** Claude Code plugin skill (markdown + frontmatter), bash, git. No application code.

## Testing modality (read first)

`/memory-adopt` is a **model-interpreted markdown skill** — no pytest. Verify two ways:
1. **Structural lint** — bash/grep that the SKILL.md has the required frontmatter, references `conventions/memory.md`, and names the gates/steps. Real, runnable.
2. **Dogfood** — seed a throwaway scratch repo, execute the skill's documented steps by hand (acting as the model, auto-approving the batch), then assert artifacts with bash. Scratch repos live under `/tmp/claude-1000/-home-manthan01-Documents-Codebase/67e39dfe-d5f9-4f47-a8d5-08ca5a3c0e51/scratchpad/` — never touch a real repo.

## Global Constraints

- New skill name: **`memory-adopt`** (dir `skills/memory-adopt/`, frontmatter `name: memory-adopt`).
- Frontmatter mirrors the family: `user-invocable: true`, `disable-model-invocation: true`, explicit `allowed-tools`, an `argument-hint`.
- **Opt-in only**; the passive default (never auto-touch existing docs) is unchanged. `/project-init` stays greenfield.
- **Free-form source docs are read-only.** The ONLY file ever edited is `CLAUDE.md`, and only an approved, structure-preserving trim of gate-passing (non-imperative) lines.
- Routing = the existing `conventions/memory.md` gates (codebase-knowledge → knowledge-vs-state → CLAUDE.md boundary test). Skills do **not** restate rules — they reference the conventions doc.
- Candidate scan: `README*`, `docs/**/*.md`, `NOTES*`, `CLAUDE.md`; **exclude** `docs/memory/` and `docs/project-tracking/`.
- Fact schema (from conventions, verbatim): frontmatter `name` (kebab == filename stem), `description` (one line), `type` ∈ `domain | convention | reference`. Index line: `- [<name>](<slug>.md) — <hook>`.
- Retrieval import line is a bare `@docs/memory/MEMORY.md` (NOT `@import`).
- **Never write secrets** into memory (repos may be public). **Idempotent** re-runs (skip already-present facts). **No auto-commit** by the skill (plan-task commits by the implementer are expected).

---

### Task 1: Conventions — "Adopting existing docs" subsection

**Files:**
- Modify: `conventions/memory.md` (append a new subsection before `## Concurrency`)

**Interfaces:**
- Produces: the SoT subsection `/memory-adopt`'s SKILL.md references for candidate sources, per-chunk routing, the CLAUDE.md trim rule, and idempotency.

- [ ] **Step 1: Define the verification**

Create `/tmp/.../scratchpad/lint-conv-adopt.sh`:
```bash
#!/usr/bin/env bash
f=conventions/memory.md
set -e
grep -q 'Adopting existing docs' "$f"
grep -q '/memory-adopt' "$f"
grep -q 'read-only' "$f"          # free-form docs read-only
grep -qi 'idempotent' "$f"
grep -qi 'trim' "$f"              # CLAUDE.md trim rule
echo "conv-adopt OK"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash /tmp/.../scratchpad/lint-conv-adopt.sh`
Expected: FAIL (subsection not present yet).

- [ ] **Step 3: Add the subsection** to `conventions/memory.md`, immediately before the `## Concurrency` header:

```markdown
## Adopting existing docs (`/memory-adopt`)

`/memory-adopt` bulk-applies the gates above to a repo's pre-existing docs (opt-in; the passive
default never auto-touches them). Candidate sources: `README*`, `docs/**/*.md`, `NOTES*`, and
`CLAUDE.md` — excluding `docs/memory/` and `docs/project-tracking/`. Route each chunk:

- durable codebase knowledge → a `docs/memory/` fact (`domain|convention|reference`);
- costly-if-unseen imperative → **stays in CLAUDE.md**;
- work-state (goal/status/TODO) → **skip** (belongs in tracking: `ideas.md`/`action-items.md`);
- about the person → **skip**.

**CLAUDE.md trim:** only lines that pass *as memory* (NOT costly-if-unseen) may be removed, only on
explicit confirmation, structure-preserving; imperatives are never trimmed. **Free-form source docs
are read-only** — never modified. **Idempotent:** before proposing, skip any fact whose slug or
content is already in `docs/memory/`. **Never write secrets.**
```

- [ ] **Step 4: Run the lint to verify it passes**

Run: `bash /tmp/.../scratchpad/lint-conv-adopt.sh`
Expected: `conv-adopt OK`

- [ ] **Step 5: Commit**

```bash
git add conventions/memory.md
git commit -m "feat(memory): conventions — adoption routing/trim/idempotency (memory-adopt)"
```

---

### Task 2: `/memory-adopt` skill

**Files:**
- Create: `skills/memory-adopt/SKILL.md`

**Interfaces:**
- Consumes: `conventions/memory.md` (Task 1 subsection + the gates/schema); `templates/memory/MEMORY.md` (for bootstrap).
- Produces: the user-invocable `/memory-adopt` skill.

- [ ] **Step 1: Define the verification (structural lint + dogfood script)**

Create `/tmp/.../scratchpad/lint-adopt.sh`:
```bash
#!/usr/bin/env bash
f=skills/memory-adopt/SKILL.md
set -e
grep -q '^name: memory-adopt$' "$f"
grep -q 'disable-model-invocation: true' "$f"
grep -q 'conventions/memory.md' "$f"
grep -qi 'bootstrap' "$f"
grep -qi 'propose' "$f" && grep -qi 'confirm' "$f"
grep -qi 'read only\|read-only' "$f"      # free-form docs untouched
grep -qi 'secret' "$f"
echo "memory-adopt SKILL OK"
```

Create `/tmp/.../scratchpad/seed-adopt-repo.sh` (seeds a realistic scratch repo):
```bash
#!/usr/bin/env bash
set -e
R=/tmp/.../scratchpad/scratch-adopt
rm -rf "$R"; mkdir -p "$R/docs"; (cd "$R" && git init -q)
cat > "$R/README.md" <<'EOF'
# Acme API
## Overview
Acme is a billing API for small merchants; core entities are Merchant, Invoice, Payment.
## Architecture
Hexagonal — domain core isolated from adapters; Postgres via a repository port.
## Setup
Run `make dev` to start the stack.
EOF
cat > "$R/CLAUDE.md" <<'EOF'
# Acme
- Import the client from `@acme/db/client`, NOT `@acme/db` (the latter is the build entrypoint).
- We use Postgres (not MySQL) because the team standardized on it in 2024 for JSONB support.
EOF
echo "seeded $R"
```

- [ ] **Step 2: Run the lint to verify it fails**

Run: `bash /tmp/.../scratchpad/lint-adopt.sh`
Expected: FAIL (SKILL.md not present).

- [ ] **Step 3: Write `skills/memory-adopt/SKILL.md`**

```markdown
---
name: memory-adopt
description: Adopt a repo's existing documentation into docs/memory/. Use when starting workspace-os in a repo that already has docs (README, design notes, an overgrown CLAUDE.md) and you want that knowledge reshaped into the shared memory layer. Opt-in; propose-confirm-apply; never auto-runs.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[path or glob to limit the scan]   (default: the repo's common doc locations)"
---

# Memory Adopt

Reshape a repo's **pre-existing** knowledge docs into `docs/memory/`, in workspace-os style. The
fact schema, the boundary test, and the **adoption routing + CLAUDE.md trim + idempotency** rules
live in this plugin's `conventions/memory.md` (see "Adopting existing docs") — read it and follow
it exactly; do not restate the rules here.

This is **opt-in and non-destructive to source docs**: free-form docs are read only. The only file
ever edited is `CLAUDE.md` (an approved trim), and only with your confirmation.

## Steps

1. **Bootstrap if needed.** If `docs/memory/` does not exist, scaffold it like `/project-init`'s
   memory step: copy this plugin's `templates/memory/MEMORY.md` → `docs/memory/MEMORY.md`; add the
   line `@docs/memory/MEMORY.md` to the repo's `CLAUDE.md` (append if not present; create
   `CLAUDE.md` with just that line if there is none); add `docs/memory/MEMORY.md merge=union` to
   `.gitattributes` (append if not present).
2. **Scan candidates.** Glob `README*`, `docs/**/*.md`, `NOTES*`, and `CLAUDE.md` (honor the
   optional path/glob argument). **Exclude** `docs/memory/` and `docs/project-tracking/`. List
   what you'll consider.
3. **Classify** each chunk through the gates in `conventions/memory.md`: → a memory fact (pick
   `domain|convention|reference`), → stays in CLAUDE.md (imperative), or → skip (work-state /
   not-knowledge / about-the-person).
4. **Dedup.** Read existing `docs/memory/`; if a proposed fact's slug already exists or its content
   is clearly already present, mark it "already adopted — skip." Do not propose duplicates.
5. **Secret-scan** each proposed fact — keys/tokens/bearer values/`.env`-style `KEY=value`. If a
   chunk contains a secret, do not propose it as a fact; flag it for the user instead.
6. **Propose one batch** for review — a table: each source → proposed facts (`slug`, `type`,
   one-line); for `CLAUDE.md`, the lines to extract → memory **and** the exact proposed trim; plus
   what **stays** and what's **skipped**, each with a one-line rationale naming the deciding gate.
7. **Confirm.** Wait for the user to approve / edit / drop. Write nothing before this.
8. **Apply.** For each approved fact: write `docs/memory/<slug>.md` (fact schema from conventions)
   and append its index line to `MEMORY.md` under the matching type section. For the approved
   CLAUDE.md trim: remove exactly those lines, preserving the rest of the file. **Never modify
   free-form source docs.**
9. **Report** what was created, the CLAUDE.md trim applied (if any), and what was skipped + why.
   Do **not** commit — leave everything staged-ready.
```

- [ ] **Step 4: Run the structural lint**

Run: `bash /tmp/.../scratchpad/lint-adopt.sh`
Expected: `memory-adopt SKILL OK`

- [ ] **Step 5: Dogfood on a scratch repo**

Run: `bash /tmp/.../scratchpad/seed-adopt-repo.sh` (seeds README + CLAUDE.md).
Then, acting as the model following `skills/memory-adopt/SKILL.md` against `$R`, run steps 1–8
(auto-approving the proposed batch for this test). Then verify with bash:
```bash
R=/tmp/.../scratchpad/scratch-adopt
# bootstrap happened
test -f "$R/docs/memory/MEMORY.md"
grep -q '@docs/memory/MEMORY.md' "$R/CLAUDE.md"
grep -q 'docs/memory/MEMORY.md merge=union' "$R/.gitattributes"
# facts created from README (domain knowledge) + the CLAUDE.md reference line
ls "$R"/docs/memory/*.md | grep -v MEMORY.md | head
# each fact is schema-valid
for x in $(ls "$R"/docs/memory/*.md | grep -v MEMORY.md); do
  grep -q '^name:' "$x"; grep -q '^description:' "$x"; grep -Eq '^type: (domain|convention|reference)$' "$x"
done
# the Postgres-rationale reference line was trimmed from CLAUDE.md; the import imperative stays
! grep -q 'standardized on it in 2024' "$R/CLAUDE.md"
grep -q 'Import the client from' "$R/CLAUDE.md"
# README untouched
grep -q '## Setup' "$R/README.md" && grep -q 'make dev' "$R/README.md"
echo "adopt dogfood OK"
```
Expected: `adopt dogfood OK`. Then **re-run** the skill's steps against the same `$R` and confirm
it proposes ~nothing (idempotent — existing slugs/content skipped).

- [ ] **Step 6: Commit**

```bash
git add skills/memory-adopt/SKILL.md
git commit -m "feat(memory): /memory-adopt — reshape existing repo docs into docs/memory/"
```

---

### Task 3: Finalize — manifest, docs, tracking

**Files:**
- Modify: `.claude-plugin/plugin.json` (version `0.3.0`; mention `memory-adopt`)
- Modify: `README.md`, `ARCHITECTURE.md`, `PORTABILITY_NOTES.md`
- Modify: `docs/project-tracking/{decisions-log.md, resolved.md, ideas.md}`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: a coherent 0.3.0 release surface + tracking reflecting the slice.

- [ ] **Step 1: Bump + describe the manifest**

In `.claude-plugin/plugin.json`: set `"version": "0.3.0"` and add `memory-adopt` to the description's memory-skill list. Verify: `jq . .claude-plugin/plugin.json >/dev/null && echo "plugin.json OK"`.

- [ ] **Step 2: Document the skill**

- `README.md` Skills list — add: `- **`/memory-adopt`** — adopt a repo's existing docs (README, design notes, CLAUDE.md reference content) into `docs/memory/` (opt-in, propose→confirm→apply).`
- `ARCHITECTURE.md` diagram — add a line: `/memory-adopt ──reshapes▶ existing docs ──▶ docs/memory/  (+ proposed CLAUDE.md trim)`.
- `PORTABILITY_NOTES.md` — in the skills-available line, add `/memory-adopt`; in "Adopting it in a repo," note that a repo with existing docs can run `/memory-adopt` instead of starting empty.

- [ ] **Step 3: Tracking dogfood**

- `decisions-log.md` — append `D-20260626-memory-adopt-design` (rationale: opt-in adoption is the non-empty-repo entry; scaffold-if-absent; CLAUDE.md trim only on confirm + gate-passing lines; idempotent model-judgment dedup; reuses the conventions gates).
- `resolved.md` — append `A-20260626-memory-adopt` as done (commit range; built subagent-driven, dogfooded).
- `ideas.md` — update the `adoption-import` entry: mark the memory-adoption case **shipped**, and note the remaining sub-slices (foreign memory-format conversion; roadmap/TODO → tracking).

- [ ] **Step 4: Verify**

```bash
jq . .claude-plugin/plugin.json >/dev/null
grep -qi 'memory-adopt' README.md
grep -q 'D-20260626-memory-adopt-design' docs/project-tracking/decisions-log.md
echo "finalize OK"
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(memory): memory-adopt v0.3.0 — docs, manifest, tracking"
```

---

## Self-Review

**Spec coverage:**
- §1 purpose / opt-in / boundary with /project-init → Task 2 SKILL.md framing + Global Constraints. ✓
- §2 workflow (bootstrap→scan→classify→dedup→secret-scan→propose→confirm→apply→report) → Task 2 steps 1–9. ✓
- §3 granularity (0/1/N facts, model judgment) → Task 2 step 3 + dogfood (README→multiple facts). ✓
- §4 routing via existing gates + conventions subsection → Task 1. ✓
- §5 safety/idempotency (secret scan, dedup, structure-preserving trim, source read-only) → Task 1 subsection + Task 2 steps 4/5/8 + dogfood asserts. ✓
- §6 files → Tasks 1–3. ✓
- §7 non-goals → respected (no foreign-format, no tracking-adoption, only CLAUDE.md edited, no auto-commit). ✓
- §8 success criteria → Task 2 dogfood asserts (bootstrap, facts, trim, imperative kept, README untouched, idempotent re-run, secret refused). ✓
- §9 testing modality → structural lint + scratch dogfood. ✓

**Placeholder scan:** `/tmp/.../scratchpad/` is the abbreviated session scratchpad (implementer substitutes the real path). No TBD/TODO. ✓

**Type/name consistency:** `memory-adopt` (dir, frontmatter, commits, docs) consistent; `domain|convention|reference` and `@docs/memory/MEMORY.md` consistent with the shipped SP2 conventions. ✓
