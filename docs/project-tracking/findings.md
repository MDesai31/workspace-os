# Findings (open questions)

Questions and investigation findings that close on evidence, not on work. Added by
`/project-log finding`; closed by `/project-log verdict` (which moves the record to
`resolved.md`). Records use the finding template from the conventions doc.

### F-20260905-function-hooks-ship — will Claude Code function hooks ship, and what does the shipped surface cover?
- Workstream: workflow
- Status: open
- Created: 2026-09-05
- Awaiting: Anthropic — GitHub issue #91870 outcome / a changelog or docs entry
- Closes-on: function hooks reach GA (docs + changelog) with the event list and repo-config story known, OR the proposal is closed without shipping

Observed 2026-09-05: a TypeScript-middleware hook type wrapping ~20 engine events, able to deny,
modify, and inject context non-blockingly, in build 2.1.260 behind a flag; the proposal is two
days old and explicitly community-gated. It decides whether guardrails-renderers needs a
function-hook host at all, and whether the deny-once pattern (playbook-surface, dispatch gate)
can be retired. See D-20260905-engine-is-a-host.
