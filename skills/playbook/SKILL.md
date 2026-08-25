---
name: playbook
description: Author a procedure playbook (trigger, preconditions, steps, verify, known traps) that auto-surfaces at trigger time; adopt an existing how-to doc into one; or list playbooks. Use when the user describes a repeatable multi-step procedure worth codifying, asks to create/adopt/list playbooks, or when a procedure gets re-explained mid-task - propose capturing it at a natural boundary, never write without confirmation.
user-invocable: true
allowed-tools: Bash, Read, Write
---

# Playbook

Procedure capture over the playbook artifact class (`conventions/playbooks.md` is the SoT -
shape, triggers, surface modes; do not restate it, follow it). Playbooks live at
`<data_root>/playbooks/` (repo tier) or `<workspace_root>/playbooks/` (workspace tier) and are
auto-surfaced by `hooks/playbook-surface.sh` when a matching tool call happens.

**Prerequisite - resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and announce the mode and where a
playbook would land. Create the `playbooks/` dir on first write.

## Dispatch

- `list` -> for each tier dir that exists, print each playbook's slug, `name`, `description`,
  triggers, and `surface` mode (read the frontmatter; both tiers, repo tier first).
- `adopt <path>` -> adopt mode below.
- Anything else (including no args) -> author mode; the argument text, if any, seeds the
  procedure description.

## Author mode

1. **Elicit the procedure** - from the conversation or by asking: what triggers it, the steps
   in copy-paste form, how to verify, the traps it prevents.
2. **Draft** into the template shape (`templates/playbook.md`): kebab-case slug/name; the
   narrowest `trigger-bash`/`trigger-path` ERE that still catches the moment of need;
   `surface: before` for procedures where an unguided first call is expensive, `after` for
   advisory ones (default before). Validate each trigger compiles:
   `printf '' | grep -qE -- '<regex>'; [ $? -le 1 ]` (exit 2 = bad regex - revise).
3. **Choose the tier** - repo tier by default; workspace tier when the user says it applies
   across the workspace's repos.
4. **Propose** the full file content + where it lands + which calls will trigger it. Nothing
   is written without confirmation.
5. **Write** on confirm (create the dir if needed), then **report**: path, trigger, mode, and
   that surfacing gates per session (a playbook surfaces at most once per session; markers
   reset next session).

## Adopt mode

Read the source doc fully, then propose a reshaping into one or more playbooks (a 300-line
how-to often splits by trigger). Per proposed playbook: content in the shape, trigger,
surface mode, tier. **The source doc is never modified or deleted** - suggest leaving it with
a one-line pointer note, but that edit too is propose-confirm. Apply only what the user
confirms; report as in author mode.

## Batching

Accumulate multiple procedures into ONE propose-confirm batch at a natural boundary, like
/ingest. Skip trivia: a procedure earns a playbook when getting it wrong costs real time or
tokens, not when it is two obvious steps.
