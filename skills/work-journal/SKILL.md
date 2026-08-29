---
name: work-journal
description: Summarize recent work from git history cross-referenced with project tracking (what shipped, which records closed, what's still open), or log this session's accomplishments to the work log. Use on /work-journal, or when the user asks "what did I do this week", "summarize recent work", "status update for the last N days", or says "log this session".
user-invocable: true
allowed-tools: Read, Bash, Glob, Grep, Write, Edit
argument-hint: "[since:YYYY-MM-DD] | log"
---

# Work Journal

Two modes over this repo's history and `<data_root>/project-tracking/`. Per-repo - the repo
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

1. `git log --oneline --since=<date>` in the repo.
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
   hours), the uncommitted diff stat, and the A-/D- ids this session touched.
2. Propose a dated entry in the conventions' entry shape (focus phrase, 2-5 bullets,
   `Commits:`, `Records:`) and append it to `<data_root>/project-tracking/work-log.md` only
   on confirmation - create the file with a `# Work log` header line on first use. Sidecar
   auto-commit per Step 0.
