---
name: project-init
description: Bootstrap a repository's project tracking. Use when a repo has no docs/project-tracking/ yet and the user wants to start logging actions, decisions, and ideas. Stamps the tracking files, adds the union-merge gitattributes, and seeds the repo's workstream tags.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
---

# Project Init

Bootstrap `docs/project-tracking/` in the current repository. Idempotent-safe: refuses if
tracking already exists.

The template files live in this plugin's `templates/` directory — i.e. `../../templates/`
relative to this skill's base directory (the plugin root is two levels up from
`skills/project-init/`). Reference them from there.

## Steps

1. **Confirm the target.** Run `git rev-parse --show-toplevel` and confirm with the user that
   this repo is where they want tracking. If not in a git repo, stop and say so.

2. **Refuse if already initialized.** If `docs/project-tracking/` already exists, do **not**
   overwrite. Report that it's already set up and stop (offer `/project-log` instead).

3. **Stamp the templates.** Create `docs/project-tracking/` and copy the five `.md` templates
   into it:
   - `templates/README.md` → `docs/project-tracking/README.md`
   - `templates/action-items.md` → `docs/project-tracking/action-items.md`
   - `templates/ideas.md` → `docs/project-tracking/ideas.md`
   - `templates/decisions-log.md` → `docs/project-tracking/decisions-log.md`
   - `templates/resolved.md` → `docs/project-tracking/resolved.md`

3a. **Scaffold memory.** Create `docs/memory/` and copy `templates/memory/MEMORY.md` →
    `docs/memory/MEMORY.md`. (The `docs/memory/MEMORY.md merge=union` line is already in
    `templates/gitattributes`, applied by the gitattributes step below.)

3b. **Wire retrieval.** Add the line `@import docs/memory/MEMORY.md` to the repo's `CLAUDE.md`:
    if `CLAUDE.md` exists, append the line only if not already present; if it does not exist,
    create it containing that single line plus a one-line comment. Never duplicate the line.

4. **Add the union-merge attributes.** Append the lines from `templates/gitattributes` to the
   repo's `.gitattributes` (create it if absent; if it exists, append only lines not already
   present — do not duplicate).

5. **Seed workstreams.** Ask the user: *"What workstreams (areas of work) does this repo have?"*
   (e.g. `data/pipeline, strategy, ML, risk, ops`). Write them as a bullet list into the
   `## Workstreams` section of `docs/project-tracking/README.md`, replacing the
   `<!-- workstream list, seeded by /project-init -->` placeholder.

6. **Report.** Print the created trees (`ls docs/project-tracking/` and `ls docs/memory/`) and
   remind the user they can now use `/project-log`, `/project-plan`, `/ingest`, and
   `/memory-lint`. Do **not** commit unless the user asks — leave the new files staged-ready for
   them to commit as they see fit.

## Notes

- All record/schema rules live in this plugin's `conventions/project-tracking.md`; the stamped
  files reference it. Do not restate them here.
- Memory schema/rules live in `conventions/memory.md`; do not restate them.
