# /tracking-adopt (slice 1: docs-only) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/tracking-adopt` — an opt-in skill that reshapes a repo's pre-existing work-state docs (roadmaps, TODOs, recorded decisions) into `docs/project-tracking/`.

**Architecture:** A standalone, model-interpreted markdown skill (sibling to `/memory-adopt`). The routing/idempotency rules live in `conventions/project-tracking.md` (single source of truth); the skill references them, never restates them. Contract: propose → confirm → apply; source docs read-only; idempotent; no auto-commit.

**Tech Stack:** Claude Code plugin (markdown skills + conventions docs). No code/runtime; verification is structural checks + a scratch-repo dogfood.

## Global Constraints

- Spec: `docs/specs/2026-06-27-tracking-adopt-design.md`. Every task implicitly includes its invariants.
- **Slice 1 is docs-only.** OUT: git-history archaeology, `resolved.md` routing, inline code TODOs, `/memory-adopt` (c)/(d) hardening.
- Routing targets this slice: `ideas.md`, `decisions-log.md`, `action-items.md` (NOT `resolved.md`).
- Source docs are **read-only** — the skill never edits README/specs/NOTES/`CLAUDE.md`; it writes only under `docs/project-tracking/` (+ bootstrap `.gitattributes` lines).
- Records follow the templates in `conventions/project-tracking.md` verbatim; date-slug IDs; legacy `#`/letter IDs grandfathered.
- No secrets written. No auto-commit (leave staged-ready).
- Plugin version bumps `0.3.0` → `0.4.0` in Task 3.
- BASE for subagent-driven review = the commit recorded before dispatching each implementer (never `HEAD~1`).

---

### Task 1: Conventions adoption subsection (the SoT)

**Files:**
- Modify: `conventions/project-tracking.md` (append a new `## Adopting existing docs (/tracking-adopt)` section before `## Concurrency`)

**Interfaces:**
- Produces: the routing/idempotency/workstream rules that `skills/tracking-adopt/SKILL.md` (Task 2) references. Section heading must be exactly `## Adopting existing docs (\`/tracking-adopt\`)`.

- [ ] **Step 1: Insert the subsection**

Insert immediately before the `## Concurrency` heading in `conventions/project-tracking.md`:

```markdown
## Adopting existing docs (`/tracking-adopt`)

`/tracking-adopt` bulk-applies these record rules to a repo's pre-existing **work-state** docs
(opt-in; the passive default never auto-touches them). It is the tracking-side sibling of
`/memory-adopt`: where `/memory-adopt` extracts durable knowledge and skips work-state,
`/tracking-adopt` claims that work-state. Candidate sources: `README*`, `docs/**/*.md`, `NOTES*`,
`CLAUDE.md`, `TODO*`/`TODOS*`, `CHANGELOG*`/`RELEASES*` — excluding `docs/project-tracking/` (never
re-adopt itself) and `docs/memory/`. Detect tracking-content by section headers (Roadmap, Future,
Post-MVP, Out-of-scope, Backlog, TODO, Key decisions) and checkbox lists (`- [ ]`/`- [x]`). Route
each chunk:

- roadmap / future / post-MVP / someday / out-of-scope → an **idea** in `ideas.md` (Intended-start
  copied verbatim; map obvious priority language, else `mid`);
- explicit decision (a "Key decisions" item, "Supersedes…", "chose X because Y") → a **`D-` record**
  in `decisions-log.md` (the body `[[wikilink]]`s the source doc);
- open TODO / unchecked `- [ ]` / "next up" → an **`A-` record** in `action-items.md`, status `open`;
- completed / checked `- [x]` / changelog "done" → **skip for now** (belongs in `resolved.md`, which
  needs a real commit ref — adopted via git history in a later slice, not from prose);
- durable knowledge / imperative / about-the-person → **out of lane, skip** (knowledge is
  `/memory-adopt`'s job).

**IDs:** new records use date-slug IDs; pre-existing `#`/letter IDs in source docs are legacy —
grandfathered, never rewritten (see IDs above). **Workstreams:** tag against the repo's
`## Workstreams` list; when bootstrapping a repo that has none, propose an inferred set from the
scanned docs for confirmation. **Source docs are read-only** — never modified (not even `CLAUDE.md`).
**Idempotent:** before proposing, skip any record whose slug or content is already in tracking.
**Never write secrets.** Apply only on explicit confirmation.
```

- [ ] **Step 2: Verify it landed and references resolve**

Run: `grep -n "Adopting existing docs" conventions/project-tracking.md && grep -c "resolved.md" conventions/project-tracking.md`
Expected: the heading line prints; `resolved.md` is referenced (the skip-for-now clause).

- [ ] **Step 3: Verify it sits before Concurrency**

Run: `grep -n "^## " conventions/project-tracking.md`
Expected: `## Adopting existing docs (...)` appears immediately before `## Concurrency`.

- [ ] **Step 4: Commit**

```bash
git add conventions/project-tracking.md
git commit -m "docs(tracking): add /tracking-adopt adoption subsection (SoT)"
```

---

### Task 2: /tracking-adopt skill + scratch dogfood

**Files:**
- Create: `skills/tracking-adopt/SKILL.md`

**Interfaces:**
- Consumes: the `## Adopting existing docs (\`/tracking-adopt\`)` section from Task 1; the record templates and `## Workstreams` rule already in `conventions/project-tracking.md`; the templates under `templates/`.
- Produces: the `/tracking-adopt` skill (frontmatter `name: tracking-adopt`, `user-invocable: true`, `disable-model-invocation: true`).

- [ ] **Step 1: Write the skill file**

Create `skills/tracking-adopt/SKILL.md` with exactly:

```markdown
---
name: tracking-adopt
description: Adopt a repo's existing roadmap / TODO / decision docs into docs/project-tracking/. Use when starting workspace-os in a repo that already has work-state docs (a README roadmap, a TODO file, design-doc decisions) and you want them captured as tracking records. Opt-in; propose-confirm-apply; never auto-runs.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[path or glob to limit the scan]   (default: the repo's common doc locations)"
---

# Tracking Adopt

Reshape a repo's **pre-existing work-state** docs — roadmaps, TODOs, and recorded decisions — into
`docs/project-tracking/`, in workspace-os style. The record schema, IDs, workstreams, and the
**adoption routing + idempotency** rules live in this plugin's `conventions/project-tracking.md`
(see "Adopting existing docs") — read it and follow it exactly; do not restate the rules here.

This is **opt-in and non-destructive to source docs**: every source doc (including `CLAUDE.md`) is
read only. The skill writes only under `docs/project-tracking/` (plus the bootstrap `.gitattributes`
lines), and only with your confirmation. It is the tracking-side sibling of `/memory-adopt`, which
owns durable knowledge; the two are complementary.

## Steps

1. **Bootstrap if needed.** If `docs/project-tracking/` does not exist, scaffold it like
   `/project-init`: copy this plugin's `templates/{action-items,ideas,decisions-log,resolved}.md`
   and `templates/README.md` into `docs/project-tracking/`; append the `merge=union` lines from
   `templates/gitattributes` to the repo's `.gitattributes` (if not already present). For the
   workstream enum, **propose a set inferred from the scanned docs** (Step 2) for the user to
   confirm/edit, then write it into the README's `## Workstreams`.
2. **Scan candidates.** Glob `README*`, `docs/**/*.md`, `NOTES*`, `CLAUDE.md`, `TODO*`/`TODOS*`,
   `CHANGELOG*`/`RELEASES*` (honor the optional path/glob argument). **Exclude**
   `docs/project-tracking/` and `docs/memory/`. Detect tracking-content by section headers (Roadmap,
   Future, Post-MVP, Out-of-scope, Backlog, TODO, Key decisions) and checkbox lists. List what
   you'll consider.
3. **Classify** each detected chunk through the routing in `conventions/project-tracking.md`: → an
   idea (`ideas.md`), → a `D-` decision (`decisions-log.md`), → an `A-` action (`action-items.md`),
   → skip-for-now (completed → `resolved.md`, a later slice), or → out-of-lane (durable knowledge →
   `/memory-adopt`).
4. **Dedup.** Read existing `docs/project-tracking/`; if a proposed record's slug already exists or
   its content is clearly already present, mark it "already adopted — skip." Grandfather any
   pre-existing `#`/letter IDs in sources (reference as-is, never rewrite).
5. **Secret-scan** each proposed record — keys/tokens/bearer values/`.env`-style `KEY=value`. If a
   chunk contains a secret, do not write it into a record; flag it for the user instead.
6. **Propose one batch** for review, grouped by target file: each source → proposed records
   (`ID`/name, target, one-line) with the deciding signal and source location; plus the
   proposed/confirmed workstream set; plus what's skipped / out-of-lane, each with a one-line reason.
7. **Confirm.** Wait for the user to approve / edit / drop. Write nothing before this.
8. **Apply.** Append each approved record to its target file using the templates in
   `conventions/project-tracking.md`. When a target file still shows its italic placeholder line
   (`_No ideas captured yet._`, `_No open items yet._`, `_No decisions logged yet._`), replace it.
   **Never modify source docs.**
9. **Report** what was created per file, what was skipped (+ why), and what's out-of-lane for
   `/memory-adopt`. Do **not** commit — leave everything staged-ready.

## Known limitations

- **Slice 1 is docs-only.** Completed work is not adopted (it belongs in `resolved.md`, which needs
  a real commit ref); git-history reconstruction for docs-poor repos is a later slice.
- **Candidate set is fixed** to the globs above (minus `docs/project-tracking/` and `docs/memory/`).
  Other docs are scanned only if named in the path/glob argument. Inline code `// TODO`s are not mined.
```

- [ ] **Step 2: Verify frontmatter + SoT reference**

Run: `grep -nE "disable-model-invocation: true|user-invocable: true|conventions/project-tracking.md" skills/tracking-adopt/SKILL.md`
Expected: all three present.

- [ ] **Step 3: Verify it does not restate rules (references, not duplicates)**

Run: `grep -c "do not restate the rules here" skills/tracking-adopt/SKILL.md`
Expected: `1`. The skill points at the SoT for routing rather than re-listing them.

- [ ] **Step 4: Scratch-repo dogfood (read-only confidence check)**

Set up a throwaway repo (NOT a real project — no real DB / no real tracking dir to mutate):

```bash
D=$(mktemp -d); cd "$D"; git init -q
mkdir -p docs
cat > README.md <<'EOF'
# Demo
## Roadmap (post-MVP)
- Billing + invoices
- Offline sync
EOF
cat > docs/design.md <<'EOF'
## Key decisions
1. One entity with a status field, because one model → one calculation.
## TODO
- [ ] add pagination
- [x] add login
EOF
echo "DEMO_DB=postgres://u:p@localhost/db" > NOTES.md   # secret bait
```

Then, following `skills/tracking-adopt/SKILL.md` against `"$D"`, confirm the **proposal** (do not apply) would route:
- README roadmap (Billing, Offline sync) → 2 ideas in `ideas.md` (priority `someday`/`low` from "post-MVP");
- design "Key decisions" item → a `D-` record in `decisions-log.md`;
- `- [ ] add pagination` → an `A-` record in `action-items.md`;
- `- [x] add login` → **skipped** (completed → resolved, later slice);
- `NOTES.md` `DEMO_DB=...` → **flagged as a secret, not written**;
- `docs/project-tracking/` absent → bootstrap proposed + an inferred workstream set.

Record the outcome in the SDD progress notes. Clean up: `rm -rf "$D"`.

- [ ] **Step 5: Commit**

```bash
git add skills/tracking-adopt/SKILL.md
git commit -m "feat(tracking): add /tracking-adopt skill (slice 1, docs-only)"
```

---

### Task 3: Finalize — manifest, docs, tracking close-out

**Files:**
- Modify: `.claude-plugin/plugin.json` (version + description)
- Modify: `README.md`, `ARCHITECTURE.md`, `PORTABILITY_NOTES.md` (mention `/tracking-adopt`)
- Modify: `docs/project-tracking/decisions-log.md`, `docs/project-tracking/resolved.md`, `docs/project-tracking/ideas.md` (close-out)

**Interfaces:**
- Consumes: the shipped skill (Task 2) + subsection (Task 1).

- [ ] **Step 1: Bump the manifest**

In `.claude-plugin/plugin.json`: set `"version": "0.4.0"` and add `tracking-adopt` to the skills list in the description (alongside `ingest/memory-lint/memory-sync/memory-adopt`).

- [ ] **Step 2: Mention the skill in the three docs**

Add a one-line `/tracking-adopt` description to `README.md`, `ARCHITECTURE.md`, and `PORTABILITY_NOTES.md`, matching how `/memory-adopt` is referenced in each (find with `grep -n "memory-adopt" README.md ARCHITECTURE.md PORTABILITY_NOTES.md` and mirror the placement/format).

- [ ] **Step 3: Tracking close-out**

Append to `docs/project-tracking/decisions-log.md`:

```markdown
### D-20260627-tracking-adopt-design — /tracking-adopt is a standalone docs-only sibling of /memory-adopt
- Workstream: skills
- Created: 2026-06-27
- Rationale: tracking adoption is its own skill (not a /memory-adopt mode) — one skill, one target. Slice 1 is docs-only, routing roadmaps→ideas, recorded decisions→decisions-log (D-), open TODOs→action-items (A-). resolved.md + git-history archaeology deferred to slice 2 (a merged-PR commit ref makes a resolved record legitimate; prose changelog does not). Reuses conventions/project-tracking.md gates — no new schema. Source docs read-only.
- Spawns: A-20260627-tracking-adopt
```

Append to `docs/project-tracking/resolved.md`:

```markdown
### A-20260627-tracking-adopt — build /tracking-adopt slice 1 (docs-only)
- Workstream: skills
- Created: 2026-06-27
- Completed: 2026-06-27
- Commit: <fill the conventions..finalize range on the tracking-adopt branch>

Spec docs/specs/2026-06-27-tracking-adopt-design.md; plan docs/plans/2026-06-27-tracking-adopt.md. Decision D-20260627-tracking-adopt-design.
```

Update the `adoption-import` entry in `docs/project-tracking/ideas.md`: mark sub-slice (b) roadmap/TODO→tracking as **SHIPPED v0.4.0 (docs-only)**; note remaining: git-history + resolved.md (slice 2), and (c)/(d) memory-adopt hardening still pending.

- [ ] **Step 4: Verify manifest + lint**

Run: `grep '"version"' .claude-plugin/plugin.json && grep -c "tracking-adopt" README.md ARCHITECTURE.md PORTABILITY_NOTES.md`
Expected: version `0.4.0`; each doc mentions `tracking-adopt` at least once.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(tracking): finalize /tracking-adopt slice 1 — manifest 0.4.0, docs, tracking close-out"
```

---

## Self-Review (run before execution)

- **Spec coverage:** §2 scope → Tasks 1–3 + Global Constraints; §3 routing → Task 1 subsection + Task 2 Step 1; §4 sources/detection → both; §5 bootstrap/workstreams → Task 2 Steps 1–2; §6 steps → Task 2 Step 1; §7 safety → Global Constraints + skill intro; §8 deferred → Global Constraints + skill Known-limitations; §9 build → Task 3 + dogfood (Task 2 Step 4). No gaps.
- **Placeholder scan:** the only `<...>` is the resolved.md `Commit:` range, filled at finalize after the commits exist (intentional). No TBD/TODO-as-instruction.
- **Type/name consistency:** skill name `tracking-adopt` and the SoT heading `## Adopting existing docs (\`/tracking-adopt\`)` match across Tasks 1–2; placeholder strings match the actual templates verified in the spec.
