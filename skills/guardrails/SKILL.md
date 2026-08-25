---
name: guardrails
description: Author a guardrail rule by describing the hazard - propose, dry-run through the real engine, confirm, apply; also list or remove rules. Use when the user describes something that must never happen in this repo (a never-push remote, an IP boundary, a dangerous command), asks to add/list/remove a guardrail, or when a hazard or near-miss worth a permanent rule surfaces mid-task - propose it at a natural boundary, never write without confirmation.
user-invocable: true
allowed-tools: Bash, Read
---

# Guardrails

Conversational authoring over the guardrail engine (`hooks/guardrail.sh` +
`guardrails.json`). Rules are version-controlled with the repo - they protect every
collaborator and machine, unlike personal hookify rules. Every write goes through
`scripts/guardrails-upsert.sh` (fail-loud, atomic, regex validated in the engine's
jq `test()` dialect); this skill NEVER edits the config by hand. Propose -> dry-run ->
confirm -> apply; nothing lands without a yes.

**Prerequisite - resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` (see `conventions/data-root.md`)
and announce the mode and where a rule would land (in-repo: `.claude/guardrails.json`;
sidecar: `<data_root>/guardrails.json` - the repo tree is never touched).

## Dispatch

- `list` -> run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/guardrails-upsert.sh" list`, show the
  output verbatim.
- `remove <name>` -> run `list`, find the rule (search both types; if the name is ambiguous
  or missing, say so and stop). Show the matching rule, confirm, then
  `... guardrails-upsert.sh remove --type <t> --name <name>`.
- Anything else (including no args) -> author mode below. The argument text, if any, is the
  hazard description; otherwise ask for it. Multiple hazards accumulate into ONE batch -
  propose together at a natural boundary, like /ingest.

## Author mode

**1. Route each hazard** before drafting:

- **Engine-fit** (proceed): a text match over a Bash command, or over a write's content or
  path, worth sharing with the repo. `deny` for hard boundaries (IP leakage, never-push
  remotes, secrets); `warn` for advisories.
- **Hookify-fit** (hand off): needs `stop`/`prompt` events, or the user says it is personal /
  this-machine-only. Say why in one line and suggest `/hookify` (if hookify is not installed,
  print the rule you would have written as a hookify `.local.md` body instead). Do not
  reimplement hookify.
- **State-dependent** ("wrong branch", "disk nearly full"): the engine cannot express it -
  say so and point at the `stateful-guardrail-predicates` idea. Never silently drop it.

**2. Draft the rule:** kebab-case `name`; the narrowest regex that still catches the hazard
(jq `test()` dialect - Oniguruma, not grep -E); a `reason` that tells a blocked session what
to do instead. For write rules pick `--field content` (default) or `--field path`.

**3. Dry-run through the real engine** - both directions, before proposing:

    cfg="$(mktemp)"
    printf '{"bash":[],"write":[]}' > "$cfg"
    GUARDRAIL_CONFIG="$cfg" bash "${CLAUDE_PLUGIN_ROOT}/scripts/guardrails-upsert.sh" add \
      --type <t> --name <name> --match <regex> --action <a> --reason <r>
    # must fire (deny -> exit 2; warn -> systemMessage on stdout):
    printf '{"tool_name":"Bash","tool_input":{"command":"<hazard example>"}}' \
      | GUARDRAIL_CONFIG="$cfg" bash "${CLAUDE_PLUGIN_ROOT}/hooks/guardrail.sh"
    # must NOT fire (a nearby legitimate call -> exit 0, no output):
    printf '{"tool_name":"Bash","tool_input":{"command":"<legit example>"}}' \
      | GUARDRAIL_CONFIG="$cfg" bash "${CLAUDE_PLUGIN_ROOT}/hooks/guardrail.sh"
    rm -f "$cfg"

For write rules the synthetic call is
`{"tool_name":"Write","tool_input":{"file_path":"<p>","content":"<c>"}}`. A rule that fails
either direction is revised, not proposed - the dry-run gate is what makes a confirmed rule
trustworthy.

**4. Propose the batch:** per rule - the drafted JSON, both dry-run results as evidence, and
where it will land. Wait for confirmation; the user may accept a subset.

**5. Apply** each confirmed rule with `guardrails-upsert.sh add` (real config - no
`GUARDRAIL_CONFIG`), and surface any script error verbatim (it fails loud; never retry by
editing JSON directly).

**6. Report:** resolved path and mode, the landed rules, a reminder that the config is
version-controlled (commit it with the repo; in sidecar mode the sidecar repo holds it), and
the removal one-liner: `/guardrails remove <name>`.
