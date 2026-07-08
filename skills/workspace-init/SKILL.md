---
name: workspace-init
description: Mark a workspace directory for sidecar mode. Use when repos live under one folder (e.g. an employer's codebase dir) and workspace-os data must stay OUT of the repos — creates the local-only _meta/ sidecar repo and its workspace.json marker. After this, every repo under the workspace resolves to sidecar mode.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
---

# Workspace Init

Create and mark a sidecar workspace: a `_meta/` git repo (NO remote — local-only by design)
holding the workspace-os data layer for every repo under this directory. Mode semantics,
marker schema, and the safety invariant live in this plugin's `conventions/data-root.md` —
follow it exactly; do not restate the rules here.

## Steps

1. **Confirm the workspace root.** The target is the directory that CONTAINS the repos (not a
   repo itself). Confirm the absolute path with the user. If the target directory is inside a
   git repository (`git -C <target> rev-parse --show-toplevel` succeeds), stop — a workspace
   root must not be inside a repo.

2. **Refuse if already marked.** If `<target>/_meta/workspace.json` exists, report that the
   workspace is already initialized and stop. If a bare `<target>/_meta/` exists without the
   marker, ask before adopting it.

3. **Ask the workspace name** (short kebab-case, e.g. `acme-work`).

4. **Scaffold.** Create `<target>/_meta/`, then:
   - copy this plugin's `templates/workspace.json` to `_meta/workspace.json`, replacing the
     name placeholder with the chosen name;
   - create `_meta/memory/` and copy `templates/memory/MEMORY.md` into it (the workspace
     tier — see `conventions/memory.md` § two-tier memory).

5. **Init the sidecar repo.** `git -C <target>/_meta init`, then commit everything with
   message `workspace-init: mark <name> as a sidecar workspace`. Do NOT add any remote and do
   not suggest one — local-only is the point.

6. **Verify.** From inside one of the workspace's repos run
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and show the user it prints
   `mode=sidecar`. If the workspace has no repos yet, skip and say so.

7. **Report.** Print the `_meta/` tree and remind the user: `/project-init` inside any repo
   here now stamps `_meta/<repo>/` instead of the repo tree; per-record history accrues in
   `_meta/` automatically; there is NO off-machine backup unless the machine itself is backed
   up.
