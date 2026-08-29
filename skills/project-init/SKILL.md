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

   Also stamp the playbooks scaffold: create `<data_root>/playbooks/` and copy
   `templates/playbooks/README.md` into it. If `<data_root>/playbooks/` already exists,
   skip it silently (it may hold playbooks).

3a. **Scaffold memory - guard against an existing store.** An empty index that contradicts a store
    already in use is an active hazard: it invites a future session to start a second store. Before
    creating `<data_root>/memory/`:
    - If `<data_root>/memory/` already exists, do **not** overwrite it (it may hold facts). Report
      that it exists and move on.
    - *(sidecar)* Check for an existing **workspace-tier** store at `<workspace_root>/memory/MEMORY.md`.
      If present, this repo's shared facts likely already live there. Do **not** stamp a bare empty
      repo-tier index that competes with it. Instead write `<data_root>/memory/MEMORY.md` with a short
      **pointer** header - one line stating that shared facts live in the workspace tier
      (`_meta/memory/`) and this repo-tier index holds only repo-specific facts - then the type
      sections below it. Prefer the pointer over an empty stub.
    - Otherwise (no existing store), copy `templates/memory/MEMORY.md` →
      `<data_root>/memory/MEMORY.md`.

3b. **Stamp the portable layer.** Run the shared stamper so the base is self-describing and
    vendor-neutral. `${CLAUDE_PLUGIN_ROOT}` is this plugin's root.
    - *(in-repo)*:
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest docs/memory/README.md --graph-dest docs/tools/memory_graph.py --agents AGENTS.md --claude-bridge CLAUDE.md`
      This copies the operator's manual (into the base folder) and vendors `memory_graph.py` (into
      `docs/tools/`, separate from the facts), creates `AGENTS.md` (the vendor-neutral entry point,
      canonical home for costly-first facts), and ensures `CLAUDE.md` imports `@AGENTS.md` and
      `@docs/memory/MEMORY.md` (the bridge). Add-only and idempotent.
    - *(sidecar)*: run with only the copy dests under `_meta/` (never the repo tree):
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest <workspace_root>/conventions/memory-base-guide.md --graph-dest <workspace_root>/tools/memory_graph.py`
      (the guide with the other playbooks in `conventions/`; the validator in `tools/` next to any
      existing tools). Then enrich `<workspace_root>/INDEX.md`: add a pointer to
      `conventions/memory-base-guide.md` as the schema/how-to source and a one-line "Link grammar"
      note. Do not create a repo `AGENTS.md`/`CLAUDE.md` in sidecar mode.

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
   use `/project-log`, `/project-plan`, `/ingest`, `/playbook`, and `/memory-lint`.

## Notes

- All record/schema rules live in this plugin's `conventions/project-tracking.md`; the stamped
  files reference it. Do not restate them here.
- Memory schema/rules live in `conventions/memory.md`; each base also stamps a self-contained operator's manual (`docs/memory/README.md` in-repo, `_meta/conventions/memory-base-guide.md` sidecar) via the portable-layer step. `AGENTS.md` is canonical; `CLAUDE.md` bridges to it. Mode rules in `conventions/data-root.md`; do not restate them.
