---
name: project-init
description: Bootstrap a repository's project tracking. Use when a repo has no docs/project-tracking/ yet and the user wants to start logging actions, decisions, and ideas. Stamps the tracking files, adds the union-merge gitattributes, and seeds the repo's workstream tags.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
---

# Project Init

Bootstrap this repository's workspace-os tracking + memory. Idempotent-safe: refuses if
tracking already exists. Where the data lives is RESOLVED, never assumed — see this plugin's
`conventions/data-root.md`.

The template files live in this plugin's `templates/` directory — i.e. `../../templates/`
relative to this skill's base directory (the plugin root is two levels up from
`skills/project-init/`). Reference them from there.

## Steps

0. **Resolve the data root.** Run and parse (key=value lines):

   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`

   Not in a git repo → stop and say so. Note `mode`, `data_root`, and (sidecar) `workspace_root`.
   Announce the mode to the user before proceeding. In **sidecar** mode, never create, modify,
   or stage any file inside the repo's working tree (`conventions/data-root.md` safety
   invariant) — steps below marked *(in-repo only)* are SKIPPED, and every path is under
   `data_root` (i.e. `_meta/<repo>/`).

1. **Confirm the target.** Confirm with the user that this repo is where they want tracking.

2. **Refuse if already initialized.** If `<data_root>/project-tracking/` already exists, do
   **not** overwrite. Report that it's already set up and stop (offer `/project-log` instead).

3. **Stamp the templates.** Create `<data_root>/project-tracking/` and copy the five `.md`
   templates into it:
   - `templates/README.md` → `<data_root>/project-tracking/README.md`
   - `templates/action-items.md` → `<data_root>/project-tracking/action-items.md`
   - `templates/ideas.md` → `<data_root>/project-tracking/ideas.md`
   - `templates/decisions-log.md` → `<data_root>/project-tracking/decisions-log.md`
   - `templates/resolved.md` → `<data_root>/project-tracking/resolved.md`

3a. **Scaffold memory.** Create `<data_root>/memory/` and copy `templates/memory/MEMORY.md` →
    `<data_root>/memory/MEMORY.md`.

3b. **Wire retrieval** *(in-repo only)*. Add the line `@docs/memory/MEMORY.md` to the repo's
    `CLAUDE.md` — Claude Code's `@`-path import syntax (a bare `@path`, **not** an `@import`
    keyword). If `CLAUDE.md` exists, append the line only if not already present; if it does
    not exist, create it containing that single line plus a one-line comment. Never duplicate
    the line. In sidecar mode this step is replaced by the plugin's SessionStart hook — do
    nothing.

4. **Add the union-merge attributes.** *(in-repo only:)* append the lines from
   `templates/gitattributes` to the repo's `.gitattributes` (create if absent; never duplicate
   lines). *(sidecar:)* append those lines to `<workspace_root>/.gitattributes` instead, with
   each path prefixed by `<repo-folder-name>/` and the `docs/` prefix dropped (e.g.
   `docs/project-tracking/action-items.md merge=union` becomes
   `repo-a/project-tracking/action-items.md merge=union`).

5. **Seed workstreams.** Ask the user: *"What workstreams (areas of work) does this repo
   have?"* (e.g. `data/pipeline, strategy, ML, risk, ops`). Write them as a bullet list into
   the `## Workstreams` section of `<data_root>/project-tracking/README.md`, replacing the
   `<!-- workstream list, seeded by /project-init -->` placeholder.

6. **Commit (sidecar only).** `git -C <workspace_root> add -A` then commit with message
   `project-init: scaffold <repo-folder-name>`. In in-repo mode do **not** commit unless the
   user asks — leave the new files staged-ready for them.

7. **Report.** Print the created trees and the resolved mode, and remind the user they can now
   use `/project-log`, `/project-plan`, `/ingest`, and `/memory-lint`.

## Notes

- All record/schema rules live in this plugin's `conventions/project-tracking.md`; the stamped
  files reference it. Do not restate them here.
- Memory schema/rules live in `conventions/memory.md`; mode rules in `conventions/data-root.md`;
  do not restate them.
