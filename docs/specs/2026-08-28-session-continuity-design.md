# Session continuity - /handoff records + /work-journal - design

- Date: 2026-08-28
- Status: accepted (design approved; implementation pending)
- Workstream: skills

## Problem

Tracking is durable but mid-task state is not: nothing records "what's in flight, what was I
about to do, what's blocked on what" across sessions, so resuming paused work means
re-deriving context (the session-state-records idea; the 2026-08-28 market survey found
session-surviving state files near table-stakes across the spec-driven majors). Separately,
there is no way to answer "what did I do this week" without hand-reading git log against the
tracking files (the /work-journal half of tracking-skills-roundout). Keystone v0.2.0 ships
both as polished MIT skills (checkpoint/pause/continue/handoff + work-journal) - borrow-first
per D-20260705-keystone-reposition - but his versions lean on machinery workspace-os
deliberately lacks (draft-PR checkpoint model, projects.md registry codes, per-project
handoff folders keyed by CODE).

## Goals

- A handoff record: one live file per paused effort carrying mission, in-flight state,
  traps, and next steps, at calibrated depth - written by a conversational skill, refreshed
  on re-pause, deleted when the work completes.
- Automatic surfacing: a session that starts in a repo with live handoffs sees them without
  asking (the EC2 audit's automatic-vs-hand-authored adoption finding).
- `/work-journal`: a summary mode (git history cross-referenced with tracking over a time
  window) and a log mode (dated session entries in a work-log file).
- Works in BOTH data-root modes; sidecar writes auto-commit as everywhere else.

## Non-goals

- No checkpoint/draft-PR machinery, no registry codes, no `_unfiled/` promotion flow, no
  umbrella-issue offers (keystone's GitHub operating model, not ours).
- No dedicated `/continue` skill - surfacing + "read the file before working" is the resume
  path; an explicit verb can come later if dogfooding demands it.
- No meeting-prep mode, `/meeting-notes`, `/release-notes`, `release_draft.py`, or
  `discovery` mode - they stay in the tracking-skills-roundout idea.
- No `/project-init` template change for the new dirs/files - `handoffs/` and `work-log.md`
  are created on first use, so adopted repos get them lazily and the stamp stays lean.
- No append-only handoff history: a dead brief has no archive value (decided in
  brainstorming 2026-08-28 - live file per effort, not dated superseding records).

## Decisions

- **Live file per effort**, `<data_root>/project-tracking/handoffs/<effort-slug>.md` -
  refreshed in place on re-pause, deleted at completion with a one-line trace on the
  resolved record. Handoffs are working state, not history; this mirrors how action records
  leave `action-items.md` when done.
- **Surfacing rides `capture-cadence.sh`** - the existing SessionStart hook already resolves
  the data root and gates on workspace-os data being present; a handoff block there is
  automatic surfacing with zero new hooks.
- **`/handoff` is its own model-invocable skill** (like `/guardrails`, `/playbook`): its
  trigger language ("let's stop here", "pick this up next time") is conversational and
  distinct; burying it in a `/project-log` mode keyword costs the discovery the audit
  measured.
- **Calibration is part of the contract** (keystone's rule, kept verbatim in spirit): scale
  the brief to the task - a small continuation gets Mission + In-flight + Next steps only;
  never ceremonialize trivia.
- **`/work-journal` is per-repo** - no project-code argument; the repo is the scope. The
  registry-driven parts of keystone's version (CODE -> directory map) are dropped, not
  adapted.

## Design

### 1. The handoff record (`conventions/project-tracking.md`, new section + `templates/handoff.md`)

New conventions section "Session continuity: handoffs and the work log" - skills reference
it and never restate it. The record, one file per paused effort, valid in both modes:

```markdown
# Handoff: <effort title>
- Paused: YYYY-MM-DD
- Resume-by: <date, or "whenever">
- Records: <related A-/D- ids, or "none">
- Branch: <branch, or "main">

## For you
<3-5 plain lines: what this is, where it stands, what happens next, what's waiting on whom>

## Mission
<outcome-shaped paragraph; include "X is DONE - do not re-derive" guards for settled work>

## In flight
<branch state, uncommitted files, open PR #, anything half-applied>

## At start, read
<memory facts BY NAME, files BY PATH - every path verified to exist before this file is written>

## Traps
<what was calibrated the hard way, each with its failing example - or omit the section>

## Next steps
<the ordered short list>

## Out of scope
<what the resuming session must NOT wander into - or omit the section>
```

Lifecycle rules (in the conventions section):
- The slug is a short kebab descriptor of the effort, stable across re-pauses.
- Re-pause refreshes the same file (update `Paused:`, rewrite sections); never a second file
  for the same effort.
- Completion deletes the file: `/project-log done` checks `handoffs/` for a file whose
  `Records:` line names the A-id being closed (fallback: slug match against the record
  title); if found, proposes deleting it and appends `- Handoff: <slug> (closed)` to the
  record being moved to `resolved.md`.
- A handoff names records by plain id (`A-...`); handoff files are not part of the
  machine-linted graph (the tracking-wikilink human contract applies).
- Paths and figures are verified against the live workspace before writing - a handoff that
  transmits a stale path is worse than none (keystone's hard rule, kept).

### 2. `skills/handoff/SKILL.md` - the author verb (new skill)

Frontmatter: `user-invocable: true`, model invocation enabled, `allowed-tools: Read, Write,
Edit, Bash, Glob, Grep`, `argument-hint: "[effort-slug]"`. Description triggers on
/handoff and natural language: "let's stop here for today", "pick this up next time",
"hand this off", "wrap up for now".

Steps:
0. Resolve the data root (standard Step 0; sidecar auto-commit applies).
1. Gather live state: `git status`/`git diff --stat`, recent commits, open `A-` records,
   the current conversation's in-flight work.
2. Determine the effort slug: from the argument, else propose one from the work at hand. If
   `handoffs/<slug>.md` exists, this is a refresh.
3. Author the record from `templates/handoff.md` at calibrated depth (Decisions above);
   verify every named path exists before including it.
4. Propose the full record (or the diff, on refresh) and write only on confirmation - the
   capture-skill contract. Create `handoffs/` on first use.
5. Report the file path and a one-line "resume by saying: pick up <slug>".

### 3. Surfacing (`hooks/capture-cadence.sh` + `/project-status`)

`capture-cadence.sh`: after the existing cadence heredoc, when `<data_root>/project-tracking/handoffs/`
contains `*.md`, emit one block:

```
## Live handoffs
- <slug> (paused <date from the Paused: line, else file mtime date>)
If the user's request matches one of these efforts, READ that handoff file fully before
starting work; refresh it as the work moves, and delete it via /project-log done when the
effort completes.
```

Fail-open as ever: unreadable dir or files -> skip the block silently. The cadence list
itself also gains one line: `- stopping with work unfinished -> /handoff`.

`/project-status`: report mode gains a **Live handoffs** section (one line per file: slug +
paused date) between "Open actions" and "Ideas"; brief mode lists live handoffs at the top
of IMMEDIATE. Matrix mode untouched.

### 4. `skills/work-journal/SKILL.md` - the journal verb (new skill)

Frontmatter: `user-invocable: true`, model invocation enabled, `allowed-tools: Read, Bash,
Glob, Grep, Write, Edit`, `argument-hint: "[since:YYYY-MM-DD] | log"`. Description triggers
on /work-journal, "what did I do this week", "summarize recent work", "log this session".

**Summary mode (default):** `since:` argument, default 7 days back. Read-only.
1. Resolve the data root; `git log --oneline --since=<date>` in the repo.
2. Cross-reference: `resolved.md` records with `Completed:` in the window; `decisions-log.md`
   records with `Created:` in the window.
3. Render: header (repo, period, commit count); **Shipped** (grouped by version markers
   `v\d+\.\d+` in commit subjects when present, else by theme); **Records closed** (A-ids +
   titles); **Decisions made** (D-ids + titles); **Still open** (open A- records, one line
   each). Lenient parsing, recent-window rendering - the house rules.

**Log mode:** `/work-journal log`.
1. Gather: recent commits (since the last work-log entry's date; on first use, the last ~2
   hours), uncommitted diff stat, A-ids touched this session.
2. Propose a dated entry and append on confirmation to
   `<data_root>/project-tracking/work-log.md` (created on first use with a one-line header
   `# Work log` + the entry). Sidecar auto-commit applies.

```markdown
## YYYY-MM-DD - <session focus, one phrase>
- <2-5 bullets of what was done>
- Commits: <shas or "none">
- Records: <A-/D- ids touched, or "none">
```

The conventions section documents the entry shape once; the skill references it.

### 5. Testing

Extend `tests/test-capture-cadence.sh` (existing harness, substring assertions):
- fixture with `project-tracking/handoffs/some-effort.md` containing a `- Paused: 2026-08-20`
  line -> output contains `Live handoffs`, `some-effort`, and `2026-08-20`.
- no `handoffs/` dir -> output does NOT contain `Live handoffs` (existing fixtures cover
  this implicitly; assert it explicitly on one).
- cadence list names `/handoff`.
- unreadable handoff file (chmod 000) -> hook still exits 0.

`/handoff` and `/work-journal` are skill prose - verified by dogfooding this repo (pause an
effort, restart-shape check via running the hook directly, resume, journal the session), the
same posture as every tracking skill.

### 6. Packaging & close-out

- `plugin.json` -> 0.26.0.
- `templates/handoff.md` (the §1 template with placeholder text).
- README feature map: `/handoff` and `/work-journal` rows (Daily section); GUIDE Daily
  workflow: a "Pausing and resuming" paragraph naming the handoff flow and the journal.
- Tracking (dogfood, at each step): idea `session-state-records` graduates to
  `A-20260828-session-continuity` and closes fully on ship; `tracking-skills-roundout` gets
  a Shipped annotation (work-journal summary+log) naming what remains (meeting-notes,
  release-notes, discovery, prep, portfolio mode); decision
  `D-20260828-handoff-live-file-lifecycle` records the live-file-vs-append-only and
  surfacing-over-continue-verb choices.

## Error handling

The hook block is fail-open (any error -> no block, exit 0, matching every hook). `/handoff`
refuses to write unverified paths (drop or fix, never guess) and always proposes before
writing. `/work-journal` summary is read-only and degrades to "no commits in window /
no records in window" lines; log mode proposes before appending. `/project-log done`'s
handoff check is a proposal, never an unconfirmed delete.

## Open questions

None - slice scope (session pair), record shape (live file per effort), resume path
(hook surfacing + /project-status, no /continue verb), and author surface (a dedicated
/handoff skill) decided in brainstorming, 2026-08-28.
