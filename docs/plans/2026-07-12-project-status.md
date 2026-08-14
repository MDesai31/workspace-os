# /project-status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/project-status` — a read-only report/brief status view over the current repo's `<data_root>/project-tracking/` files, per `docs/specs/2026-07-12-project-status-design.md`.

**Architecture:** Pure SKILL.md prose skill (no scripts, no runtime code). One new skill directory plus manifest/docs/tracking updates. The skill resolves the data root via `scripts/resolve-data-root.sh` (sidecar-aware, 10th skill), reads the four tracking files leniently, and renders one of two output shapes (report / brief) with an optional workstream-or-priority filter.

**Tech Stack:** Markdown (SKILL.md), JSON manifest, `scripts/validate-plugin.py` as the only automated gate.

## Global Constraints

- **Read-only contract:** the skill writes nothing, anywhere, in any mode — no propose/confirm gate, no sidecar commit step. The SKILL.md must state this explicitly.
- **Data root:** always via `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`; never hardcode `docs/…` as the data path inside the skill's instructions.
- **Lenient parsing:** legacy IDs (`#21`, item `K`) and non-record prose render as found — never rewritten, never warned about.
- **Recent-window output:** decisions/resolved sections show last ~5; never full history.
- **Frontmatter:** `user-invocable: true`, `disable-model-invocation: false` (explicit, matching `skills/project-plan/SKILL.md`), `allowed-tools: Read, Bash, Glob, Grep`.
- **Version:** `.claude-plugin/plugin.json` `version` 0.12.0 → **0.13.0** (description field unchanged).
- **Attribution:** SKILL.md body carries one line crediting zachburke9/keystone-engine's project-status shapes (MIT).
- **Spec:** `docs/specs/2026-07-12-project-status-design.md` is authoritative; on any conflict with this plan, the spec wins and the conflict is reported.

---

### Task 1: The skill — `skills/project-status/SKILL.md`

**Files:**
- Create: `skills/project-status/SKILL.md`

**Interfaces:**
- Consumes: `scripts/resolve-data-root.sh` (existing; prints `key=value` lines incl. `mode=` and `data_root=`), `conventions/project-tracking.md` (record schema SoT), `conventions/data-root.md` (resolver contract).
- Produces: the `/project-status` skill; Task 2's README/ARCHITECTURE text describes exactly the behavior defined here.

- [ ] **Step 1: Create the skill file**

Write `skills/project-status/SKILL.md` with exactly this content:

````markdown
---
name: project-status
description: Read-only status view over the current repo's project tracking — open actions by workstream, ideas by priority, recent decisions and resolved items, plus a brief mode for "what should I work on next". Use on /project-status, or when the user asks "what's next", "where are we", "what's the status", or "what should I work on". Writes nothing.
user-invocable: true
disable-model-invocation: false
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "[workstream | high|mid|low] | brief [workstream | high|mid|low]"
---

# Project Status

A **read-only** view over `<data_root>/project-tracking/` — the only skill in this plugin that
writes nothing, anywhere, in any mode. No propose/confirm gate: there is nothing to confirm.
The record schema and lifecycle live in `conventions/project-tracking.md`; this skill only
renders what the tracking files already say. (Report/brief output shapes adapted from
zachburke9/keystone-engine's project-status skill, MIT — re-founded on per-repo tracking files
instead of its single-workspace project registry.)

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/` in BOTH modes; never hardcode `docs/…`. Announce the
   resolved mode. Reads only — no sidecar commit step applies.
   If `<data_root>/project-tracking/` does not exist: say so, point at `/project-init`
   (greenfield repo) or `/tracking-adopt` (repo with existing work-state docs), and stop.
   Never create anything.

1. **Parse `$ARGUMENTS`.** A leading `brief` selects brief mode. The remaining token (if any)
   is the filter, matched case-insensitively — first against the repo's workstream list (the
   tracking README's `## Workstreams` section, else the tags actually present in records),
   then against the priority enum `high` / `mid` / `low`. Unknown token → say so, list the
   valid workstreams, and stop. No filter → whole-repo view.

2. **Read fresh.** Read all four files — `action-items.md`, `ideas.md`, `decisions-log.md`,
   `resolved.md` — every run; never trust a remembered copy. Parse **leniently**: adopted
   repos carry legacy IDs (`#21`, item `K`) and non-record prose (e.g. a pre-existing resolved
   table). Render what is there as found — never rewrite it, never warn about its format.
   Count only what parses as a record; mention unparsed content in one line (e.g. "plus a
   pre-existing resolved table").

3. **Render** the selected mode (below). Recent-window only — never dump full history. A file
   still showing its italic placeholder line (`_No open items yet._`, `_No ideas captured
   yet._`, …) renders as a one-line empty state; continue with the remaining sections. With a
   filter, scope every section to it and name the filter in the header.

## Report mode (default)

Sections, in order:

1. **Header** — repo name, today's date (`date +%F`), resolved mode, active filter if any.
2. **Open actions** grouped by workstream: `ID — title — age` (age in days from `Created:`),
   oldest first within each workstream. Untagged records group under `(untagged)`; if the repo
   has no workstream enum and no tagged records, use a single untagged group — never invent
   workstreams.
3. **Ideas** by priority, high → mid → low: one title line each (name + a one-phrase hook);
   `someday`-priority ideas collapse to a single count line.
4. **Recent decisions** — last ~5, newest first: `ID — title`. Mark superseded decisions
   (read rule: an appended `Superseded-by:` line wins over `Status:`).
5. **Recent resolved** — last ~5, newest first: `ID — title — completed date`.
6. **Summary** — one line of counts (open actions, ideas by priority tier, decisions,
   resolved).

## Brief mode (`/project-status brief`)

The "what should I work on" view — one sentence per item:

```
PROJECT BRIEF: <date>

IMMEDIATE (high)
- <ID>: one line on state + next action
NEXT (mid)
- ...
LONG-TERM (low)
- ...

Suggested order: <IDs> — priority first, then staleness (oldest Created first).
```

Inputs: open action items plus ideas whose `Priority:` is `high` / `mid` / `low` (skip
`someday`). Action records carry no priority field — place each in a tier by judgment from
its content and age. Within a tier, oldest `Created:` first. Always end with the suggested
order line.
````

- [ ] **Step 2: Run the validator**

Run: `python3 scripts/validate-plugin.py`
Expected: exit 0, no errors (the new SKILL.md has non-empty `name` and `description`).

- [ ] **Step 3: Commit**

```bash
git add skills/project-status/SKILL.md
git commit -m "feat(skills): /project-status — read-only report/brief view over project tracking"
```

---

### Task 2: Ship shape — manifest bump + doc mentions

**Files:**
- Modify: `.claude-plugin/plugin.json` (the `version` line only)
- Modify: `README.md` (one bullet in `## Skills`)
- Modify: `ARCHITECTURE.md` (one line in the data-flow block, after the `/tracking-adopt` line)

**Interfaces:**
- Consumes: the skill behavior defined in Task 1 (the doc text below describes it).
- Produces: v0.13.0 manifest; docs that enumerate the new skill.

- [ ] **Step 1: Bump the manifest version**

In `.claude-plugin/plugin.json`, change the version value:

```json
"version": "0.13.0",
```

(Only this line changes; `description` and all other fields stay as-is.)

- [ ] **Step 2: Add the README skill bullet**

In `README.md`'s `## Skills` list, insert this bullet directly after the `/project-plan` bullet (keeping the tracking-family skills adjacent):

```markdown
- **`/project-status`** — read-only status view: open actions by workstream, ideas by priority, recent decisions/resolved; `brief` mode gives a prioritized "what should I work on next" (filter by workstream or `high`/`mid`/`low`).
```

- [ ] **Step 3: Add the ARCHITECTURE data-flow line**

In `ARCHITECTURE.md`'s data-flow block, insert this line directly after the `/tracking-adopt` line:

```
/project-status ──reads──▶ docs/project-tracking/ (all four files; read-only report/brief)
```

- [ ] **Step 4: Validate and check the diffs**

Run: `python3 scripts/validate-plugin.py`
Expected: exit 0.

Run: `git diff --stat`
Expected: exactly 3 files changed, small line counts (1 line in plugin.json, 1 in README.md, 1 in ARCHITECTURE.md).

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json README.md ARCHITECTURE.md
git commit -m "chore: bump manifest 0.13.0 + doc mentions for /project-status"
```

---

### Task 3: Tracking close-out

**Files:**
- Modify: `docs/project-tracking/ideas.md` (tracking-skills-roundout entry gains a Shipped line)
- Modify: `docs/project-tracking/action-items.md` (remove the A-20260712-project-status record; restore `_No open items yet._` if it becomes empty)
- Modify: `docs/project-tracking/resolved.md` (append the close-out record)

**Interfaces:**
- Consumes: the commit SHAs from Tasks 1–2 (run `git log --oneline -3` to read them).
- Produces: closed tracking state for the slice.

- [ ] **Step 1: Add the Shipped line to the roundout idea**

In `docs/project-tracking/ideas.md`, inside the `### tracking-skills-roundout` entry, insert this line directly before the `- To start, future-us needs:` line:

```markdown
- **Shipped (v0.13.0, 2026-07-12):** `/project-status` (report + brief + workstream/priority filters) — first sub-slice; keystone's registry/set-mode deliberately dropped (per-repo tracking has no project registry). See `resolved.md` A-20260712-project-status. Decision: D-20260712-project-status-design. Remaining: `/work-journal`, extra `/project-log` modes (`discovery`, `meeting-notes`, `release-notes`), `/project-status` portfolio mode (blocked on [[portfolio-registry]]).
```

- [ ] **Step 2: Move the action record to resolved**

Remove the `### A-20260712-project-status — build /project-status per spec` record (heading through its body paragraph) from `docs/project-tracking/action-items.md`. If no records remain, restore the placeholder line `_No open items yet._` in its place.

Append to `docs/project-tracking/resolved.md` (fill `<task1-sha>` / `<task2-sha>` from `git log --oneline -3`):

```markdown

### A-20260712-project-status — build /project-status per spec
- Workstream: skills
- Status: done
- Created: 2026-07-12
- Completed: 2026-07-12
- Commit: <task1-sha> + <task2-sha> (branch project-status; PR pending)

Shipped `/project-status` per docs/specs/2026-07-12-project-status-design.md: read-only
report/brief status view over `<data_root>/project-tracking/` with workstream/priority
filters, sidecar-aware via resolve-data-root.sh, model invocation enabled ("what's next"
triggers). Keystone's report/brief shapes borrowed (MIT); its registry data model dropped.
First sub-slice of tracking-skills-roundout. Plugin v0.13.0. Spawned by
D-20260712-project-status-design.
```

- [ ] **Step 3: Validate nothing broke**

Run: `python3 scripts/validate-plugin.py`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add docs/project-tracking/
git commit -m "chore(tracking): close out A-20260712-project-status (v0.13.0)"
```

---

## Verification (controller-run, after all tasks — not a subagent task)

Success criteria from spec §10, run by the controller in the main session:

1. **(a) Validator:** `python3 scripts/validate-plugin.py` → exit 0.
2. **(b) Self-run on workspace-os:** follow the new SKILL.md against this repo (in-repo mode). Expect: empty-state line for open actions (`_No open items yet._` after Task 3), ideas by priority, last ~5 decisions/resolved, one-line summary.
3. **(c) Run on Options Analyzer:** follow the SKILL.md against `/home/manthan01/Documents/Codebase/Options Analyzer` (in-repo mode). Expect: legacy IDs and the pre-existing resolved table render without complaint (one "plus a pre-existing resolved table" style line); `brief` yields a priority-then-staleness order.
4. **(d) No writes:** `git status --porcelain` in both repos identical before/after the runs (OA's pre-existing uncommitted files unchanged).

Then: push the branch, open the PR, wait for green CI (advisory but load-bearing per repo convention) before merge.
