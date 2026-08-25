# Playbook Conventions

Single source of truth for the playbook artifact class: `/playbook` and
`hooks/playbook-surface.sh` follow these rules and do not restate them.

## What a playbook is

A **procedure** — multi-step how-to knowledge too big for a memory fact (one fact per file,
see `conventions/memory.md`) and not work-state (see `conventions/project-tracking.md`).
Examples: how to query a warehouse tool safely, how to edit notebooks, how to triage a failed
run. A playbook guides; a guardrail rule blocks — a hazard that must be PREVENTED belongs in
`.claude/guardrails.json` (`/guardrails`), not here.

## Where playbooks live

- Repo tier: `<data_root>/playbooks/<slug>.md` (in-repo: `docs/playbooks/`; sidecar:
  `_meta/<repo>/playbooks/` — resolved via `scripts/resolve-data-root.sh`, never assumed).
- Workspace tier: `<workspace_root>/playbooks/<slug>.md` — procedures shared by every repo in
  a marked workspace.

## File shape

Flat frontmatter (plain `key: value` lines between the first two `---` lines — bash hooks
parse it with sed/grep, so no nesting), then a body in the recommended section shape:

    ---
    name: snowflake-querying
    description: how to query Snowflake with sfq.py without burning retries
    trigger-bash: sfq\.py
    trigger-path:
    surface: before
    ---
    # Snowflake querying
    ## Preconditions
    ## Steps
    ## Verify
    ## Known traps

- `trigger-bash`: ERE (`grep -E`) matched against Bash commands.
- `trigger-path`: ERE matched against Edit/Write file paths. Either or both; with neither the
  playbook is docs-only (listable, never auto-surfaced).
- `surface`: `before` (default) or `after` — see below.
- Body sections are recommended, not enforced. Keep bodies <= 300 lines: larger bodies are
  surfaced as a read-this-path instruction instead of inline content.

## Surfacing (once per session per playbook)

Claude Code's PreToolUse hooks cannot inject model context non-blockingly
(`additionalContext` is honored there only on "ask" escalations — verified against the hooks
docs 2026-08-24). Hence two modes:

- `surface: before` — the FIRST matching tool call in a session is denied once with
  "read <path> first, then retry"; the session marker is written before the deny, so the
  retry passes. Guarantees the procedure is read before the call runs. Use for procedures
  where the first call unguided is the expensive one.
- `surface: after` — the first matching call runs, then the playbook body is injected via
  PostToolUse `additionalContext`. Frictionless; the first call is unguided. Use for
  advisory-grade procedures.

One playbook surfaces per call (first unmarked match, repo tier before workspace tier, glob
order within a tier); others fire on subsequent matching calls. Markers live under
`${TMPDIR:-/tmp}/workspace-os-surfaced-<session_id>/` and reset per session.
