# Policy packs - versioned importable guardrail/lint policy - design

- Date: 2026-08-28
- Status: accepted (design approved; implementation pending)
- Workstream: packaging

## Problem

The guardrail/lint engine is declarative but every repo starts from an empty template: the
same hazards get re-authored rule by rule (or not at all - the EC2 audit measured the real
UDX hazards living in three hookify rules because authoring per-repo config never happened).
The 2026-08-28 keystone v0.2.0 re-read showed the transferable idea - a versioned shareable
unit riding on an engine - and its defects to avoid: manifests as prose, destructive
re-vendor updates, installation separate from activation. workspace-os has the better
substrate because activation is automatic (the hooks read the config; file-present = active).
This slice ships the pack format, the import machinery, and two starter packs.

## Goals

- A machine-read pack format bundling guardrail rules + lint linters, with optional
  org-specific parameters filled conversationally at import.
- Idempotent, provenance-stamped import into a repo's `.claude/guardrails.json` +
  `.claude/lint.json` that never touches hand-authored rules; clean removal.
- A `/guardrails pack` subcommand (list / add / remove) carrying the existing
  propose-confirm contract.
- Two starter packs with real content: `public-repo` (parameter-free escalations) and
  `enterprise-clean-room` (the UDX-audit hazards, parameterized).

## Non-goals

- No remote/third-party pack fetch - packs ship in the plugin's `packs/` dir; the format is
  designed so a remote source can be added later without changing pack contents. (Decided
  in brainstorming 2026-08-28: the third-party author is a hypothetical customer today.)
- No playbook distribution - playbooks are markdown artifacts with their own `/playbook
  adopt` flow; the pack format can grow to a directory later without breaking pack names.
- No per-pack version field - in-plugin distribution means the plugin version IS the pack
  version.
- No template logic in bash - `{{placeholder}}` substitution happens in the skill; the
  deterministic script only ever sees final JSON.
- No `keystone-module-guardrails` packaging - still gated on the Zach conversation; packs
  make that contribution stronger later ("engine + starter pack").

## Decisions

- **Anti-borrow rules from the keystone defects, enforced by construction:** one
  distribution channel (the plugin); manifests machine-read end to end (a pack that fails
  validation fails CI); imports idempotent and scoped - re-import replaces only the pack's
  own stamped rules, never a delete-and-recopy of the config.
- **Per-rule `"pack": "<name>"` stamp + a `_packs` ledger.** The stamp makes removal and
  re-import exact (delete where pack == name); the ledger
  (`_packs: {<name>: {version, imported}}` in `guardrails.json`, the canonical policy
  file) answers "what is imported here, from which plugin version, since when". The
  engines read named fields only, so the extra key is inert (proven by a test).
- **`remove` never downgrades `ip_class`.** A pack may set `ip_class` on add (announced in
  the proposal); removing the pack reports that `ip_class` was left as-is - silently
  dropping a provenance boundary is worse than a stale one.
- **Params are skill-side.** A pack declares `params: [{name, prompt}]`; `/guardrails pack
  add` asks for each value, substitutes `{{name}}` occurrences, and hands the script a
  final JSON. Deterministic bash stays template-free.

## Design

### 1. Pack format (`packs/<name>.json` + `conventions/packs.md`)

`conventions/packs.md` is the format SoT (the `conventions/playbooks.md` precedent). Shape:

```json
{
  "name": "enterprise-clean-room",
  "description": "IP boundary + never-push wall for an employer workspace",
  "params": [
    { "name": "tripwire_regex", "prompt": "Employer-identifying strings (regex alternation, e.g. AcmeCorp|acme\\.internal)" },
    { "name": "forbidden_remote_regex", "prompt": "Enterprise remote host pattern (e.g. github\\.enterprise\\.example)" }
  ],
  "ip_class": "enterprise",
  "guardrails": { "bash": [ ... ], "write": [ ... ] },
  "lint": { "linters": [ ... ] }
}
```

- `name` (matches the filename), `description`, and `guardrails` are required; `params`,
  `ip_class`, and `lint` optional. Rule objects are exactly the engine's rule shape
  (`name`, `match`, `action`, `reason`, plus `field` on write rules); linter objects are
  exactly the lint engine's (`name`, `match`, `command`).
- `{{param}}` placeholders may appear in any rule/linter string field. Every declared param
  must be used and every placeholder declared (validated, §5).

### 2. `scripts/pack-import.sh` - the deterministic import (fail-loud, bash + jq)

    pack-import.sh list
    pack-import.sh add <pack-json-path>
    pack-import.sh remove <pack-name>

- **Config resolution** mirrors `guardrails-upsert.sh`: `GUARDRAIL_CONFIG` /
  `LINT_CONFIG` env seams (tests) -> sidecar data root -> `<git root>/.claude/`. On `add`
  only, missing config files are created from `templates/guardrails.json` /
  `templates/lint.json` first (the same bootstrap `/guardrails` already documents);
  `remove` and `list` never create files.
- **`add`**: parse the pack (any `{{` remaining in the JSON -> die "unsubstituted
  placeholder"); validate every `match` regex in the engine's jq dialect (the upsert
  script's check); then, per target file, one atomic jq edit: delete rules/linters where
  `.pack == <name>`, insert the pack's entries each stamped `"pack": "<name>"`, and in
  `guardrails.json` upsert the ledger `_packs[<name>] = {version: <plugin.json version>,
  imported: <today>}`. If the pack declares `ip_class`, set it (the skill has already
  announced the change). Atomic per file: temp file, parse-check, move - the
  `guardrails-upsert.sh` pattern.
- **`remove <name>`**: delete `.pack == <name>` rules/linters from both files and the
  ledger entry; print a note when the config's `ip_class` matches a class this pack set
  ("ip_class left as '<v>' - review manually"). Unknown pack name in the ledger -> die.
- **`list`**: available packs (`$CLAUDE_PLUGIN_ROOT/packs/*.json` - script arg
  `--packs-dir` as the test seam, defaulting relative to the script) with name +
  description + param count, then imported packs from the ledger with version + date.
- Empty `lint` section -> `lint.json` untouched (no needless file creation).

### 3. `/guardrails pack` - the conversational surface (skill extension)

`skills/guardrails/SKILL.md` gains a `pack` mode (`argument-hint` grows to
`"[hazard description | list | remove NAME | pack list|add NAME|remove NAME]"`):

- `pack list` -> render the script's list.
- `pack add <name>`: read `packs/<name>.json`. For each declared param, ask the user for a
  value (plain conversation; show the prompt text). Substitute every `{{name}}` occurrence.
  Show the FULL resulting rule set, the linters, and - when the pack sets it - the
  `ip_class` change ("this marks the repo's policy class 'enterprise'"). On confirmation:
  write the substituted JSON to a temp file, run `pack-import.sh add <temp>`, report, and
  in sidecar mode commit the sidecar repo. Parameter-free packs skip straight to the
  proposal.
- `pack remove <name>`: show what the ledger says will be removed, confirm, run the
  script, relay its `ip_class` note verbatim.

### 4. Starter packs

**`packs/public-repo.json`** (no params, no ip_class): write rules - deny path-match
`(^|/)\.env(\..+)?$` ("secrets files never enter a public repo"), deny content-match
`-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----`; bash rule - deny
`git push[^|;&]*--force[^|;&]*(origin[[:space:]]+)?(main|master)\b` ("force-push to the
default branch"). Escalations of the engine's warn-only built-ins for repos where warn is
not enough.

**`packs/enterprise-clean-room.json`** (flagship; params + `ip_class: enterprise`): write
rule - deny content-match `{{tripwire_regex}}` ("employer tripwire string crossing into
this repo"); bash rules - deny `git (push|pull|fetch|remote add)[^|;&]*{{forbidden_remote_regex}}`
("enterprise remote from a personal workspace"), deny `{{tripwire_regex}}` in commands
("employer tripwire string in a command"). Productizes the two measured UDX hazards
(employer IP boundary, never-push enterprise remote).

Exact regexes land in the plan; packs are data, so tightening them later is a data change.

### 5. Validation & tests

- `scripts/validate-plugin.py` gains a packs pass: every `packs/*.json` parses; `name`
  matches the filename; `description` + `guardrails` present; rule/linter objects carry
  their required fields; params declared <-> placeholders used (both directions fail).
- `tests/test-pack-import.sh` (env seams `GUARDRAIL_CONFIG`, `LINT_CONFIG`, `--packs-dir`):
  - `add` lands stamped rules in both files + the `_packs` ledger (version + date).
  - re-`add` does not duplicate (rule count stable).
  - a hand-authored rule (no `pack` field) survives `add` and `remove` untouched.
  - `remove` deletes only the pack's rules + ledger entry; the ip_class note prints.
  - unsubstituted `{{placeholder}}` -> nonzero exit, config untouched.
  - invalid regex in a pack -> nonzero exit, config untouched.
  - engine tolerance: `hooks/guardrail.sh` denies on a pack-stamped rule (extra key inert).
- `hooks/lint.sh` tolerance is implied by the same named-field reads; the guardrail case
  is the one asserted.

### 6. Packaging & close-out

- `plugin.json` -> 0.27.0.
- `conventions/packs.md` (format SoT), README feature-map row + GUIDE paragraph for
  `/guardrails pack` (doc-freshness gate).
- Tracking (dogfood, at each step): idea `policy-packs` graduates to
  `A-20260828-policy-packs`; decision `D-20260828-pack-stamp-ledger` records the per-rule
  stamp + ledger + no-ip_class-downgrade semantics; full close-out on ship, with a note on
  `keystone-module-guardrails` that the starter-pack half of its "engine + pack"
  contribution now exists.

## Error handling

`pack-import.sh` is fail-loud everywhere (bad JSON, unknown pack, unsubstituted
placeholder, invalid regex, unwritable config): message on stderr, nonzero exit, configs
untouched (atomic per-file edits). The skill relays script errors verbatim and never
retries destructively. The engines themselves are unchanged - a repo with imported packs
runs exactly the fail-open hook paths that already exist.

## Open questions

None - distribution (in-plugin), content scope (guardrails + lint, no playbooks), import
home (`/guardrails pack`), and starter set (two packs, skill-side params) decided in
brainstorming, 2026-08-28.
