# Tracking-skills roundout remainder — design

Date: 2026-08-29. Status: approved (backlog order approved 2026-08-29). Closes the
tracking-skills-roundout idea's remaining modes (portfolio mode stays blocked on
portfolio-registry). Borrow source: zachburke9/keystone-engine v0.2.0 `/project-log`,
`/work-journal`, `/release-notes` (MIT) — prose adapted, registry/project-code parts dropped
(per-repo tracking has no registry), memory-boundary routing added (keystone has no
memory/tracking split).

## What ships

### `/project-log discovery <finding>`

An investigation finding — lighter than a decision. Routed, not just logged:

- **Durable fact about the codebase** (would survive this effort) → hand off to `/ingest`
  (the memory/tracking boundary rules route it; never duplicate it into work-log).
- **Work-state finding** (scoped to current work) → append a dated entry to
  `<data_root>/project-tracking/work-log.md` (same file `/work-journal log` writes; entry
  heading `## YYYY-MM-DD - discovery: <one-line>`, 1-3 body bullets).
- Then ask keystone's chaining question: does this change anything? → offer to chain into
  `decision` / `action` mode.

### `/project-log meeting <date/notes>`

Structured meeting capture: a meeting file at
`<data_root>/project-tracking/meetings/YYYY-MM-DD-<slug>.md` (attendees, notes), with any
decisions/actions extracted as real `D-`/`A-` records in the ledgers, each linking the
meeting file. The meeting file holds the narrative; the ledgers stay the SoT for records —
no record content lives only in the meeting file. No separate `/meeting-notes` alias skill
(keystone's alias adds a skill slot for no behavior).

### `/project-log release-notes [since:<ref|date>] [audience:team|leadership]`

Git history + the decisions log → grouped, plain-English release notes, appended (newest
first) to `<repo-root>/RELEASES.md` on confirmation (in-repo mode; sidecar: 
`<data_root>/RELEASES.md` — the repo tree is never touched). Keystone's hard rule kept
verbatim: **never invent a change** — every line traces to a real commit or D- record;
cryptic subjects get `git show --stat` before description. Default window: since last git
tag, else last 20 commits. Audience `team` (default) vs `leadership` (outcomes, no jargon).
Renders without writing unless confirmed.

### `/work-journal prep`

Read-only meeting briefing: find the latest `meetings/*.md` (none → fall back to the last
work-log entry date, else 7 days), summarize work since it (summary-mode machinery), status
each A- record that meeting spawned (done/open), list open questions. No write.

## Non-goals

- `/project-status` portfolio mode (blocked on portfolio-registry).
- No new scripts or hooks — these are skill-prose modes over existing files; the only new
  artifacts are `meetings/` files, work-log entries, and `RELEASES.md`.
- No cadence automation for release notes (keystone's own open question; stays manual).

## Conventions

`conventions/project-tracking.md` gains: the `meetings/` file + extraction rule (ledgers
stay SoT), the work-log discovery entry heading, and the `RELEASES.md` location per mode.

## Verification

Skill-prose slice: full suite + validator green; doc-freshness gate covers README/GUIDE
mentions; conventions stay the single SoT (skills point, never restate).
