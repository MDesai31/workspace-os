# /project-status — single-repo tracking status view

**Date:** 2026-07-12
**Status:** approved
**Decision:** D-20260712-project-status-design
**Idea:** tracking-skills-roundout (first sub-slice)

## 1. What and why

A read-only status view over the current repo's `<data_root>/project-tracking/` files: open
actions grouped by workstream, ideas condensed by priority, recent decisions and resolved
items, plus a `brief` mode answering "what should I work on next."

Borrow-first per D-20260705-keystone-reposition: the output shapes (report / brief) adapt
keystone-engine's `/project-status` (MIT). The data model does **not** carry over — keystone's
skill reads a single-workspace project registry (`projects.md` with project CODEs, lifecycle,
priority per project); workspace-os tracking is per-repo, so this skill is re-founded on the
four tracking files. Keystone's `set` mode (lifecycle/priority mutation) and registry concerns
are out of scope — cross-repo aggregation stays parked in the portfolio-registry idea.

## 2. Invocation

```
/project-status [filter]
/project-status brief [filter]
```

`filter` is one optional token:
- a **workstream tag** (e.g. `risk`, `docs`) — scope every section to that workstream;
- a **priority** (`high` / `mid` / `low`) — scope ideas (and brief tiers) to that priority.

Resolution order: `brief` keyword first; remaining token matched case-insensitively against
the repo's workstream list (the tracking README's `## Workstreams`, else the tags actually
present in records), then against the priority enum. Unknown token → say so, list the valid
workstreams, and stop. No filter → whole-repo view.

## 3. Data and contract

- **Step 0:** resolve the data root via `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
  and announce the mode (`conventions/data-root.md`). Works identically in in-repo and sidecar
  modes; 10th skill with a sidecar branch. Never hardcode `docs/…`.
- **Sources:** `action-items.md`, `ideas.md`, `decisions-log.md`, `resolved.md` under
  `<data_root>/project-tracking/`, read fresh every run.
- **Read-only contract:** this skill writes nothing, anywhere, in any mode — the only skill in
  the plugin with a pure read-only contract; the SKILL.md states it explicitly. No
  propose/confirm gate is needed because there is nothing to confirm.
- **Lenient parsing:** adopted repos carry legacy IDs (`#21`, item `K`) and non-record prose
  (e.g. a pre-existing resolved table). Render what is there as found; never rewrite, never
  warn about format. Count only what is parseable as a record; mention unparsed content in one
  line (e.g. "plus a pre-existing resolved table").

## 4. Report mode (default)

Sections, in order (recent-window only — never full history):

1. **Header:** repo name, today's date, resolved mode, active filter if any.
2. **Open actions** grouped by workstream: `ID — title — age` (age from `Created:`, in days).
   Within a workstream, oldest first.
3. **Ideas** condensed by priority, high → mid → low: title line only (name + one-phrase hook).
   `someday`-priority ideas collapse to a single count line.
4. **Recent decisions:** last ~5, newest first: `ID — title`. Superseded decisions are marked
   (read rule: an appended `Superseded-by:` line wins over `Status:`).
5. **Recent resolved:** last ~5, newest first: `ID — title — completed date`.
6. **Summary line:** one line of counts (open actions, ideas by priority, decisions, resolved).

## 5. Brief mode

The "what should I work on" view, one sentence per item:

```
PROJECT BRIEF: <date>

IMMEDIATE (high)
- <A-ID or idea>: one line on state + next action
NEXT (mid)
- ...
LONG-TERM (low)
- ...

Suggested order: <IDs> — priority first, then staleness (oldest Created first).
```

Inputs: open action items plus ideas whose Priority is `high`/`mid`/`low` (skip `someday`).
Actions without an explicit priority tier are placed by judgment from their content and age.
Ordering within a tier: oldest `Created:` first.

## 6. Empty and missing states

- **No `<data_root>/project-tracking/` dir:** say so and point at `/project-init` (greenfield)
  or `/tracking-adopt` (existing docs). Never create anything.
- **Placeholder files** (italic placeholder line, e.g. `_No open items yet._`): report the
  empty state in one line and continue with the other sections — e.g. an empty action-items
  file with a populated ideas file yields "no open actions; top ideas: …".
- **No workstream enum and no tagged records:** group open actions under a single untagged
  heading rather than inventing workstreams.

## 7. Frontmatter and triggering

- `user-invocable: true`; **model invocation enabled** (no `disable-model-invocation` line) —
  the skill is harmless read-only, and its natural triggers are conversational: the
  description names "what's next", "where are we", "project status", "what should I work on".
- `allowed-tools: Read, Glob, Grep, Bash` (Bash only for the resolver and `date`).

## 8. SoT boundary

Output formats are skill-local views, not cross-skill rules: they live in the SKILL.md.
`conventions/project-tracking.md` is unchanged. No new conventions files.

## 9. Ship shape

- Plugin version 0.12.0 → 0.13.0.
- README skill table gains the `/project-status` row; ARCHITECTURE/PORTABILITY notes only if
  their skill inventories enumerate skills (match existing text, minimal diffs).
- Tracking: D-20260712-project-status-design (decision), A-20260712-project-status (action →
  resolved at close-out); ideas.md tracking-skills-roundout entry gains a Shipped line for
  this sub-slice (remaining: /work-journal, /project-log extra modes, /meeting-notes,
  /release-notes).
- SKILL.md body carries a one-line attribution: report/brief shapes adapted from
  zachburke9/keystone-engine's project-status (MIT).

## 10. Success criteria

(a) `scripts/validate-plugin.py` green (frontmatter + manifest).
(b) Live self-run on workspace-os: empty action-items renders a sensible empty-state report
    (ideas + decisions + resolved still shown).
(c) Live run on Options Analyzer: legacy/mixed formats (legacy IDs, pre-existing resolved
    table, imported records section) render without complaint; `brief` produces a sane
    priority-then-staleness order.
(d) No writes occur in either run (`git status` clean before/after, both repos).
