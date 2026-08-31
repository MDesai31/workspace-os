---
name: handoff
description: Write or refresh a handoff record - the live "where was I" file for a paused effort - so a future session resumes in one read instead of a re-derivation. Use when the user says "let's stop here", "pick this up next time", "wrap up for now", "hand this off", or when a session is ending with work clearly unfinished - propose it at the natural stopping point, never write without confirmation.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[effort-slug]"
---

# Handoff

Author the handoff record for a paused effort. The record shape, lifecycle (live file per
effort: refresh on re-pause, delete at completion), and calibration rule live in
`conventions/project-tracking.md` § "Session continuity: handoffs and the work log" - read
it and follow it exactly; the empty shape is `templates/handoff.md` (in this plugin's
directory).

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Handoffs live at
   `<data_root>/project-tracking/handoffs/` in every repo-tier mode.
   With no `data_root` (`workspace-root` mode) see `conventions/data-root.md`
   § "No repo tier". Announce the resolved mode. In
   **sidecar** mode: never touch the repo's working tree, and after the write commit the
   sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).
   If `<data_root>/project-tracking/` is missing entirely, stop and point at
   `/project-init`.

1. **Gather live state.** `git status` + `git diff --stat` + the last few commits; the open
   `A-` records in `action-items.md`; what this conversation actually has in flight. This is
   the content - the record distills decisions, facts, and next steps, never a dump of
   conversation history.

2. **Determine the effort slug.** From the argument if given, else propose a short kebab
   descriptor of the effort. If `handoffs/<slug>.md` already exists, this is a **refresh**
   of that file, not a new one.

3. **Author at calibrated depth** from the template: header lines (`Paused:` today,
   `Resume-by:`, `Records:` with the related A-/D- ids, `Branch:`), the For you block, then
   only the sections the task earns - a small continuation gets Mission + In flight + Next
   steps and nothing else. **Verify every path you name exists before writing it**; drop or
   fix anything you cannot verify. Include "X is DONE - do not re-derive" guards for
   settled work, and an Out of scope line whenever an eager resume could wander.

4. **Propose, then write.** Show the full record (or, on refresh, what changes) and write
   only on confirmation. Create `handoffs/` if absent. Sidecar auto-commit per Step 0.

5. **Report** the file path and the resume line: "resume by saying: pick up <slug>" (the
   SessionStart hook will surface it automatically in this repo's future sessions).
