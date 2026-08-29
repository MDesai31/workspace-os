# Playbooks

Procedures — multi-step how-to knowledge too big for a memory fact and not work-state.
Each `<slug>.md` here carries a trigger (`trigger-bash` / `trigger-path`) and is surfaced
automatically the first time a matching tool call happens in a session. Format and surfacing
rules: the workspace-os plugin's `conventions/playbooks.md` (the single source of truth).

Author one with `/playbook` (describe the procedure), adopt an existing how-to doc with
`/playbook adopt <path>`, list them with `/playbook list`. `/memory-lint` checks these files
for the mistakes the surfacing hook would swallow silently.
