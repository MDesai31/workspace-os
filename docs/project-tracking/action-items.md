# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260626-sp2b-memory-roundout — SP2b: /memory-lint, /memory-sync, secret guard
- Workstream: memory
- Status: open
- Created: 2026-06-26

Round out the memory layer after the SP2a dogfood: `/memory-lint` (index/frontmatter/wikilink
integrity), `/memory-sync` (one-way `~/.claude`→repo bridge), and a warn-only secret-guard hook on
`docs/memory/` writes (confirm the plugin hook-registration schema first). Plan:
`docs/plans/2026-06-26-sp2-memory.md` (Tasks 4–6).

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
