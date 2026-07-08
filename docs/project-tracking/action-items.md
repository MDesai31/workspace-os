# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.


### A-20260707-sidecar-data-layer — build sidecar data-layer mode per spec
- Workstream: meta
- Status: open
- Created: 2026-07-07

Implement docs/specs/2026-07-07-sidecar-data-layer-design.md: `scripts/resolve-data-root.sh`
resolver + `/workspace-init` skill + sidecar branches in `/project-init` and the data-writing
skills + SessionStart memory-surfacing hook + `guardrail.sh` sidecar fallback + conventions
"Data-root resolution" section + resolver/invariant tests. Safety invariant: in sidecar mode no
skill/hook touches the repo working tree. Spawned by D-20260707-sidecar-data-layer.
