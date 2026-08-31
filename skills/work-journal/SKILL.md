---
name: work-journal
description: Summarize recent work from git history cross-referenced with project tracking (what shipped, which records closed, what's still open), log this session's accomplishments to the work log, or prep a meeting briefing. Use on /work-journal, or when the user asks "what did I do this week", "summarize recent work", "status update for the last N days", says "log this session", or wants a briefing before a meeting.
user-invocable: true
allowed-tools: Read, Bash, Glob, Grep, Write, Edit
argument-hint: "[since:YYYY-MM-DD] | log | prep"
---

# Work Journal

Three modes over this repo's history and `<data_root>/project-tracking/`. Per-repo - the repo
is the scope (no project codes). The work-log entry shape lives in
`conventions/project-tracking.md` § "Session continuity: handoffs and the work log".
(Summary shape adapted from zachburke9/keystone-engine's work-journal skill, MIT -
re-founded on per-repo tracking files instead of its project registry.)

## Step 0

Resolve the data root: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and
parse its `key=value` output. Tracking lives at `<data_root>/project-tracking/` in BOTH
modes. Announce the resolved mode. Summary mode is read-only; log mode writes, and in
**sidecar** mode commits the sidecar repo after the write.

## Summary mode (default): `/work-journal [since:YYYY-MM-DD]`

Default window: the last 7 days. Read-only; lenient parsing per the house rule.

1. `git log --oneline --since='<date> 00:00'` in the repo. The `00:00` is required, not
   cosmetic — `conventions/project-tracking.md` § "Date windows over git history" (a bare
   date silently truncates the window at the current time of day).
2. Cross-reference the window: `resolved.md` records whose `Completed:` falls in it;
   `decisions-log.md` records whose `Created:` falls in it; open records in
   `action-items.md`.
3. Render:

   ```
   WORK JOURNAL: <repo> - <start date> to today (<N> commits)

   ### Shipped
   <grouped by version markers (v\d+\.\d+) in commit subjects when present, else by theme;
    2-5 bullets of what changed and why - never one line per commit>

   ### Records closed
   - <A-id> - <title> (<Completed date>)

   ### Decisions made
   - <D-id> - <title>

   ### Still open
   - <A-id> - <title>
   ```

   Empty sections render as one line ("no commits in window", "no records closed"). No
   commits AND no records -> say so and stop.

## Log mode: `/work-journal log`

1. Gather: commits since the last entry's date in `work-log.md` (on first use: the last ~2
   hours), the uncommitted diff stat, and the A-/D- ids this session touched. That parsed
   date goes into git as `'<date> 00:00'` per the date-window rule — a same-day log entry is
   exactly the case a bare date drops.
2. Propose a dated entry in the conventions' entry shape (focus phrase, 2-5 bullets,
   `Commits:`, `Records:`) and append it to `<data_root>/project-tracking/work-log.md` only
   on confirmation - create the file with a `# Work log` header line on first use. Sidecar
   auto-commit per Step 0.

## Prep mode: `/work-journal prep`

A read-only briefing for an upcoming meeting - "what happened since we last met, and where
did the meeting's asks land."

1. Anchor date: the newest file in `<data_root>/project-tracking/meetings/` (by filename
   date). No meetings dir or files -> fall back to the last `work-log.md` entry's date, else
   the last 7 days; say which anchor was used.
2. Run the summary-mode machinery since the anchor, passing the anchor as `'<date> 00:00'`
   (the date-window rule applies to a filename-derived date too).
3. If the anchor is a meeting file, status each record it extracted: done (with the
   `Completed:` date from `resolved.md`) or still open.
4. Render:

   ```
   MEETING PREP: <repo> - since <anchor date> (<anchor kind>)

   ### Since last meeting
   <2-5 bullets>

   ### Their asks
   - <A-id> - <title> (done <date> | open)

   ### Open questions / decisions needed
   <open D-shaped items, or "none">
   ```
