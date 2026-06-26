# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260625-install-and-dogfood — install workspace-os and use it natively
- Workstream: skills
- Status: open
- Created: 2026-06-25

`/plugin marketplace add MDesai31/workspace-os` + `/plugin install workspace-os`, reload, then
confirm `/project-init`, `/project-log`, `/project-plan` work as native skills (these tracking
records were stamped by hand pre-install). First live use: `/project-init` on klapp.

### A-20260625-default-branch-main — rename default branch master→main
- Workstream: packaging
- Status: open
- Created: 2026-06-25

`git init` created `master`; other repos use `main`. `git branch -m master main` + update the
remote default for consistency.

### A-20260625-visibility-decision — decide + set repo visibility
- Workstream: packaging
- Status: open
- Created: 2026-06-25

Currently private. Decide private (auth required on each machine) vs public (frictionless
install, shareable; no secrets in the repo). Set with `gh repo edit --visibility`.

### A-20260625-meta-ci — add CI to workspace-os itself
- Workstream: packaging
- Status: open
- Created: 2026-06-25

A small GitHub Actions workflow validating `plugin.json`/`marketplace.json` parse and that each
`skills/*/SKILL.md` has valid frontmatter (name/description). Mirrors the diff-scoped, SHA-pinned,
least-privilege pattern used in the Options Analyzer CI.
