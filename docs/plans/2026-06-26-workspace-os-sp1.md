# workspace-os SP1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `workspace-os`, a portable Claude Code plugin providing command-driven project tracking (`/project-log`, `/project-plan`, `/project-init`) across separate repos.

**Architecture:** A standalone git repo structured as a Claude Code plugin (manifest + marketplace + skills + templates + a single conventions doc). Skills write typed, date-slug-ID'd records into a per-repo `docs/project-tracking/` data layer. Installed once per machine via `/plugin`, carried job-to-job.

**Tech Stack:** Markdown (SKILL.md, templates, docs), JSON (plugin/marketplace manifests), bash/`jq` for validation, `gh` for the remote. No application runtime — skills are model-interpreted instructions.

## Global Constraints

- Plugin repo name: `workspace-os`; GitHub remote `MDesai31/workspace-os`.
- New repo lives at `/home/manthan01/Documents/Codebase/workspace-os/`.
- IDs: `A-YYYYMMDD-slug` (actions), `D-YYYYMMDD-slug` (decisions) — assigned at creation, never renumbered. Pre-existing `#`/letter IDs are grandfathered, never rewritten.
- The four append-heavy data files (`action-items.md`, `decisions-log.md`, `resolved.md`, `ideas.md`) carry `merge=union` in the target repo's `.gitattributes`.
- Single source of truth for schema/lifecycle: `conventions/project-tracking.md`. Skills reference it; they do not restate rules.
- Lifecycle: `action`→open in `action-items.md`; `done`→stamp completion date + commit ref, **move** record to `resolved.md`; `plan`→`ideas.md`.
- No proprietary content from any external repo. Generic patterns only.
- Full spec: `docs/superpowers/specs/2026-06-26-workspace-os-design.md` (relocates with this plan into `workspace-os` at build start).

---

## File Structure

```
workspace-os/
  .claude-plugin/plugin.json        # T1 — plugin manifest
  .claude-plugin/marketplace.json   # T1 — marketplace entry
  README.md                         # T1 — what it is / install
  conventions/project-tracking.md   # T2 — schema, IDs, lifecycle (SoT)
  templates/                        # T3 — stamped by /project-init
    README.md  action-items.md  ideas.md  decisions-log.md  resolved.md  gitattributes
  skills/project-init/SKILL.md      # T4
  skills/project-log/SKILL.md       # T5
  skills/project-plan/SKILL.md      # T6
  ARCHITECTURE.md  PORTABILITY_NOTES.md   # T7
```

Dependency order: T1 (shell) → T2 (conventions) → T3 (templates) → T4 (init) → T5/T6 (log/plan) → T7 (docs + remote + end-to-end).

---

### Task 1: Repo + installable plugin shell

**Files:**
- Create: `workspace-os/.claude-plugin/plugin.json`
- Create: `workspace-os/.claude-plugin/marketplace.json`
- Create: `workspace-os/README.md`

**Interfaces:**
- Produces: an installable (skill-less) plugin named `workspace-os` that `/plugin marketplace add` recognizes.

- [ ] **Step 1: Create the repo and relocate the spec/plan**

```bash
mkdir -p /home/manthan01/Documents/Codebase/workspace-os/.claude-plugin
cd /home/manthan01/Documents/Codebase/workspace-os
git init -q
mkdir -p docs/specs docs/plans
# move the design spec + this plan in from the OA repo (they were housed there temporarily)
cp "/home/manthan01/Documents/Codebase/Options Analyzer/docs/superpowers/specs/2026-06-26-workspace-os-design.md" docs/specs/
cp "/home/manthan01/Documents/Codebase/Options Analyzer/docs/superpowers/plans/2026-06-26-workspace-os-sp1.md" docs/plans/
```

- [ ] **Step 2: Write `plugin.json`**

```json
{
  "name": "workspace-os",
  "version": "0.1.0",
  "description": "Portable, command-driven project tracking across repos (project-log / project-plan / project-init).",
  "author": { "name": "MDesai31" }
}
```

- [ ] **Step 3: Write `marketplace.json`**

```json
{
  "name": "workspace-os",
  "owner": { "name": "MDesai31" },
  "plugins": [
    { "name": "workspace-os", "source": "./", "description": "Project-OS: tracking skills + per-repo journal schema." }
  ]
}
```

- [ ] **Step 4: Write `README.md`** — sections: what it is (portable project-OS), install (`/plugin marketplace add MDesai31/workspace-os` then `/plugin install workspace-os`), the three skills one-liner each, and a link to `conventions/project-tracking.md`.

- [ ] **Step 5: Validate both manifests parse**

Run: `cd /home/manthan01/Documents/Codebase/workspace-os && jq -e . .claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: both echo their JSON (exit 0), no parse error.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/ README.md docs/
git commit -m "feat: workspace-os plugin shell (manifest + marketplace + spec/plan)"
```

---

### Task 2: Conventions doc (schema source of truth)

**Files:**
- Create: `workspace-os/conventions/project-tracking.md`

**Interfaces:**
- Produces: the canonical schema the three skills reference — entry templates (action/decision/idea), the ID rule, the lifecycle state machine, workstream-tag rule, union-merge rule.

- [ ] **Step 1: Write `conventions/project-tracking.md`** containing, verbatim, these record templates and rules:

```
ACTION (in action-items.md, status open):
### A-YYYYMMDD-slug — <title>
- Workstream: <tag>
- Status: open
- Created: YYYY-MM-DD
<body>

DECISION (append-only in decisions-log.md):
### D-YYYYMMDD-slug — <title>
- Workstream: <tag>
- Created: YYYY-MM-DD
- Rationale: <why>
- Spawns: <A-IDs or none>

IDEA (in ideas.md):
### <name> — <one-line>
- Workstream: <tag>
- Priority: high|mid|low|someday
- Intended start: <verbatim, fuzzy ok>
- Why/context: <…>
- To start, future-us needs: <key files / open question / dependency>

DONE (move action record to resolved.md, append these two lines to its body):
- Completed: YYYY-MM-DD
- Commit: <sha or PR#>
```

Rules to state explicitly: IDs are date-slug, assigned once, never renumbered; legacy `#`/letter IDs are grandfathered and never rewritten; `slug` is short kebab-case; workstream is one tag from the target repo's `README.md` workstream list; the four append-heavy files are `merge=union`.

- [ ] **Step 2: Verify completeness**

Run: `grep -cE "A-YYYYMMDD-slug|D-YYYYMMDD-slug|Priority: high|Completed:" workspace-os/conventions/project-tracking.md`
Expected: ≥ 4 (all four record shapes present).

- [ ] **Step 3: Commit**

```bash
git add conventions/project-tracking.md
git commit -m "feat: project-tracking conventions (schema + lifecycle SoT)"
```

---

### Task 3: Per-repo templates (what /project-init stamps)

**Files:**
- Create: `workspace-os/templates/{README.md, action-items.md, ideas.md, decisions-log.md, resolved.md, gitattributes}`

**Interfaces:**
- Consumes: the record formats from `conventions/project-tracking.md` (Task 2).
- Produces: the six template files `/project-init` (Task 4) copies into a target repo's `docs/project-tracking/`.

- [ ] **Step 1: Adapt the OA tracking files into generic templates.** Base them on `Options Analyzer/docs/project-tracking/{README,action-items,ideas,decisions-log,resolved}.md`, stripping OA-specific items so each is an empty, header-only scaffold. `templates/README.md` must include a `## Workstreams` section with a `<!-- workstream list, seeded by /project-init -->` placeholder, plus the file-roles table and the conventions summary.

- [ ] **Step 2: Write `templates/gitattributes`** (stamped as `.gitattributes`):

```
docs/project-tracking/action-items.md   merge=union
docs/project-tracking/decisions-log.md  merge=union
docs/project-tracking/resolved.md       merge=union
docs/project-tracking/ideas.md          merge=union
```

- [ ] **Step 3: Verify the set is complete and header-only**

Run: `ls workspace-os/templates/ && grep -rL "###" workspace-os/templates/*.md`
Expected: 5 `.md` + `gitattributes` present; each `.md` listed by `grep -L` (no record entries — they're empty scaffolds).

- [ ] **Step 4: Commit**

```bash
git add templates/
git commit -m "feat: per-repo project-tracking templates"
```

---

### Task 4: `/project-init` skill

**Files:**
- Create: `workspace-os/skills/project-init/SKILL.md`

**Interfaces:**
- Consumes: `templates/` (Task 3).
- Produces: a target repo with `docs/project-tracking/` (5 files), `.gitattributes` union lines, and a seeded workstream list.

- [ ] **Step 1: Define the acceptance check (expected result first).** In an empty scratch dir, after running the skill's documented steps with workstreams `data/pipeline, strategy, ML, risk, ops`: the 5 tracking files + `.gitattributes` exist, and `README.md`'s `## Workstreams` lists those five tags.

- [ ] **Step 2: Write `skills/project-init/SKILL.md`.** Frontmatter: `name: project-init`, `description` (bootstrap a repo's project-tracking), `user-invocable: true`, `disable-model-invocation: true` (side-effecting), `allowed-tools: Read, Write, Bash, Glob`. Body — ordered steps: (1) confirm CWD is the target repo root; (2) refuse if `docs/project-tracking/` already exists (offer no-op); (3) copy the six templates from the plugin's `templates/` into `docs/project-tracking/` (with `gitattributes`→`.gitattributes`, merging if one exists); (4) ask the user for the repo's workstream tags and write them into `README.md`'s `## Workstreams` section; (5) print the created tree.

- [ ] **Step 3: Run the acceptance check**

```bash
T=$(mktemp -d); cd "$T"; git init -q
# follow SKILL.md steps manually with the test workstreams, then:
ls docs/project-tracking/ && cat .gitattributes && grep -A6 "## Workstreams" docs/project-tracking/README.md
```
Expected: 5 `.md` files listed; `.gitattributes` shows 4 union lines; Workstreams section lists the 5 tags.

- [ ] **Step 4: Commit**

```bash
git add skills/project-init/SKILL.md
git commit -m "feat: /project-init skill (bootstrap a repo's project-tracking)"
```

---

### Task 5: `/project-log` skill

**Files:**
- Create: `workspace-os/skills/project-log/SKILL.md`

**Interfaces:**
- Consumes: `conventions/project-tracking.md` (Task 2); a repo already initialized by Task 4.
- Produces: typed records appended/moved across `action-items.md` / `decisions-log.md` / `resolved.md`.

- [ ] **Step 1: Define acceptance (expected results first).** In a repo initialized by Task 4:
  - `action data/pipeline "test item"` → an `A-<today>-test-item` record (status open) in `action-items.md`.
  - `decision strategy "use X over Y"` → a `D-<today>-…` record in `decisions-log.md`.
  - `done A-<today>-test-item abc123` → that record is gone from `action-items.md` and present in `resolved.md` with `Completed:` + `Commit: abc123`.

- [ ] **Step 2: Write `skills/project-log/SKILL.md`.** Frontmatter: `name: project-log`, `description`, `user-invocable: true`, `disable-model-invocation: true`, `allowed-tools: Read, Write, Edit, Bash, Glob, Grep`. Body — `## Modes` for `action`, `decision`, `done`, each citing the exact template from `conventions/project-tracking.md` and the target file. `done` must: locate the `A-id` in `action-items.md`, append `Completed:`/`Commit:` lines, remove it from `action-items.md`, append it to `resolved.md`. Include a "validate workstream against `README.md` list" step and a quick-add fallback (infer mode from verbs) per the conventions.

- [ ] **Step 3: Run the acceptance check** (in the Task-4 scratch repo): execute the three invocations per SKILL.md, then:

```bash
grep "A-.*-test-item" docs/project-tracking/action-items.md   # expect: nothing (moved)
grep -A4 "A-.*-test-item" docs/project-tracking/resolved.md    # expect: record + Completed/Commit
grep "D-.*" docs/project-tracking/decisions-log.md             # expect: the decision record
```
Expected: action record only in `resolved.md` with completion lines; decision in `decisions-log.md`.

- [ ] **Step 4: Commit**

```bash
git add skills/project-log/SKILL.md
git commit -m "feat: /project-log skill (action/decision/done lifecycle)"
```

---

### Task 6: `/project-plan` skill

**Files:**
- Create: `workspace-os/skills/project-plan/SKILL.md`

**Interfaces:**
- Consumes: `conventions/project-tracking.md` (idea template); a Task-4-initialized repo.
- Produces: an idea record in `ideas.md`.

- [ ] **Step 1: Define acceptance.** `/project-plan "someday: validate the X pre-filter"` → an entry in `ideas.md` using the idea template, with `Priority: someday` (no timing given) and a filled `Why/context` + `To start, future-us needs` line.

- [ ] **Step 2: Write `skills/project-plan/SKILL.md`.** Frontmatter mirrors project-log (`user-invocable: true`, `disable-model-invocation: true`, `allowed-tools: Read, Write, Edit, Glob, Grep`). Body: parse the intent; capture name/workstream/why/context; secure timing (ask if absent) and map near-term→high / on-deck→mid / slow-burn→low / none→someday; write the idea record to `ideas.md`. State the contract: **plans, does not execute** (no task list, no code).

- [ ] **Step 3: Run the acceptance check**

```bash
grep -A5 "validate the X pre-filter" docs/project-tracking/ideas.md
```
Expected: idea record with `Priority: someday` and the why/start lines populated.

- [ ] **Step 4: Commit**

```bash
git add skills/project-plan/SKILL.md
git commit -m "feat: /project-plan skill (future capture)"
```

---

### Task 7: Plugin docs, remote, install + end-to-end acceptance

**Files:**
- Create: `workspace-os/ARCHITECTURE.md`, `workspace-os/PORTABILITY_NOTES.md`

**Interfaces:**
- Consumes: everything above.
- Produces: an installed, working plugin verified end-to-end via real skill invocations.

- [ ] **Step 1: Write `ARCHITECTURE.md`** (the three layers + how skills/data/conventions relate) and `PORTABILITY_NOTES.md` (install on a new machine, update flow, that data lives per-repo).

- [ ] **Step 2: Create the GitHub remote and push**

```bash
cd /home/manthan01/Documents/Codebase/workspace-os
gh repo create MDesai31/workspace-os --private --source=. --remote=origin --push
```
Expected: repo created, branch pushed.

- [ ] **Step 3: Install the plugin locally**

```bash
# in a Claude Code session:
/plugin marketplace add MDesai31/workspace-os
/plugin install workspace-os
```
Expected: `/project-log`, `/project-plan`, `/project-init` appear in the skills list.

- [ ] **Step 4: End-to-end acceptance via REAL invocations** (the §7 walkthrough), targeting a throwaway repo first:

```bash
T=$(mktemp -d); cd "$T"; git init -q
```
Then invoke: `/project-init` (workstreams `a, b`) → `/project-log action a "smoke"` → `/project-log done A-… smoke-sha` → `/project-plan "someday: thing"`. Verify: `action-items.md` empty of the item, `resolved.md` has it with completion lines, `ideas.md` has the idea, `.gitattributes` has 4 union lines.

- [ ] **Step 5: Commit + push**

```bash
git add ARCHITECTURE.md PORTABILITY_NOTES.md
git commit -m "docs: architecture + portability notes"
git push
```

- [ ] **Step 6: First real bootstrap (optional, confirm with user):** run `/project-init` in the klapp repo to adopt tracking there.

---

## Self-Review

**Spec coverage:** §2 architecture→T1/T2 + ARCHITECTURE.md(T7); §3 packaging/portability→T1 + T7; §4 schema→T2/T3; §5 skills→T4/T5/T6; §6 conventions→T2; §7 verification→T4–T7 acceptance steps; §8 scope→Global Constraints + plan stops at SP1 (no memory/finish-task/meta); §9 fit→T3 reuses OA files, auto-memory/CI untouched. No gaps.

**Placeholder scan:** no TBD/TODO; each skill task carries concrete frontmatter, exact target files, and a runnable acceptance check with expected output. The one literal placeholder (`<!-- workstream list -->` in the template) is intentional content, filled by `/project-init`.

**Type/name consistency:** ID forms (`A-YYYYMMDD-slug`/`D-YYYYMMDD-slug`), the 5 data files, `merge=union` set, and the done→resolved move are referenced identically across T2–T7 and the Global Constraints.
