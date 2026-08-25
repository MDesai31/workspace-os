# Guardrail conversational authoring - design

- Date: 2026-08-24
- Status: accepted (design approved; implementation pending)
- Workstream: workflow

## Problem

The guardrail engine is tested, fail-open, sidecar-aware, and solves a real hazard class (employer
IP boundaries, never-push remotes) - and has **zero adoption**: the 2026-08 EC2 audit
(`docs/memory/adoption-audit-2026-08.md`) found no `.claude/guardrails.json` in any real workspace.
What actually enforces those hazards is three *hookify* rules, because a hookify rule is authored by
asking for one mid-task while `guardrails.json` must be hand-written against a schema. The audit's
general finding: every workspace-os surface authored by conversation or one command scored 6-9/10 in
real use; every surface requiring hand-authored JSON scored 1-3. The engine lost on authoring
ergonomics, not capability.

## Goals

- Author a guardrail rule by describing the hazard in conversation: propose -> confirm -> apply,
  like every other capture skill.
- Prove the rule before it lands: dry-run the draft through the real engine and show it firing
  (and not over-firing).
- Keep the engine's differentiators: rules version-controlled with the repo (shared across
  collaborators and machines), hard `deny` semantics, `ip_class` tripwires, sidecar awareness.
- Make rule capture proactive: Claude may propose a rule when a hazard surfaces mid-session,
  batched at boundaries per the capture cadence.
- Complete the loop: rules are listable and removable conversationally too.

## Non-goals

- No change to the engine or its rule language. State-dependent rules ("wrong branch", "disk
  full") stay out of scope - that is the `stateful-guardrail-predicates` idea, explicitly gated
  behind this slice.
- No conversational authoring for `.claude/lint.json` (logged as a separate follow-up idea).
- No hookify reimplementation: hazards that fit hookify better are handed off, not absorbed.
- No new hook surfaces (`Task`, `Stop`, `SessionEnd` interception is other ideas' territory).

## Decision: guardrails.json stays canonical; hookify gets the misfits

Considered: (a) author `guardrails.json` and route misfit hazards to hookify - CHOSEN; (b) author
`guardrails.json` only, misfits declared out of scope; (c) concede the format and emit hookify
`.local.md` rules. (c) rejected because hookify rules are gitignored and personal - they protect
one machine, not the repo; the engine's whole differentiator is rules that travel with the repo.
(b) rejected because real hazards genuinely need `stop`/`prompt` events or personal scope, and a
skill that shrugs at them recreates the ergonomics gap. The routing test for (a): a text-match
over a Bash command or a write's content/path, worth sharing with the repo -> `guardrails.json`;
needs `stop`/`prompt` events or is explicitly personal/machine-local -> hookify handoff;
state-dependent -> named out of scope with a pointer to `stateful-guardrail-predicates`.

## Design

### 1. `scripts/guardrails-upsert.sh` - the deterministic write path

Plain bash + jq (the engine's own deps). Unlike the engine it **fails loud**: authoring must
error, never silently no-op. Modes:

- `add --type bash|write --name NAME --match REGEX --action deny|warn --reason TEXT
  [--field content|path]` - creates the config from `templates/guardrails.json` if absent;
  add-or-replace by `name` within the type's array (idempotent); `--field` valid only with
  `--type write`.
- `remove --type bash|write --name NAME` - deletes the rule; error if not found.
- `list` - prints both arrays (type, name, action, match, reason) plus the resolved config path
  and mode; exit 0 with a note when no config exists.

Safety contract:

- **Regex validated in the evaluation dialect.** Config rules are evaluated by jq `test()`
  (Oniguruma), not `grep -E`; the script rejects a `--match` that jq cannot compile.
- **Atomic writes.** Build to a temp file, `jq -e .` parse-check, then move into place. A
  malformed config can never be left behind.
- **Never clobber.** A pre-existing config that does not parse is an error to report, not a file
  to overwrite.
- **Path resolution mirrors the engine** (`hooks/guardrail.sh`): `GUARDRAIL_CONFIG` env override
  (test seam) -> in-repo `<git root>/.claude/guardrails.json` -> in sidecar mode the write target
  is `<data_root>/guardrails.json`, so an enterprise repo tree is never touched (the engine itself
  warns on in-tree writes of this file in sidecar mode).

### 2. `skills/guardrails/SKILL.md` - the conversation

User-invocable and model-invocable (no `disable-model-invocation`), per the capture-cadence
matrix: it is a propose-confirm capture skill, not a bulk or side-effecting one.

Flow (author mode, the default):

0. **Resolve the data root** (`scripts/resolve-data-root.sh`), announce the mode and where a rule
   would land.
1. **Elicit the hazard** - from the invocation args if present, else ask. Multiple hazards
   accumulate into one batch.
2. **Route** each hazard: engine-fit (text-match over Bash command or write content/path, worth
   sharing) proceeds; hookify-fit (`stop`/`prompt` events, explicitly personal/machine-local)
   gets a one-line explanation and a handoff - suggest `/hookify` when the plugin is present,
   else print the suggested rule body; state-dependent gets named as future work
   (`stateful-guardrail-predicates`) rather than silently dropped.
3. **Draft the rule**: kebab-case `name`; `deny` for hard boundaries (IP leakage, never-push
   remotes, secrets), `warn` for advisories; the narrowest regex that still catches the hazard;
   a `reason` that tells the blocked session what to do instead.
4. **Dry-run through the real engine**: write a temp config holding only the draft rule, run
   `hooks/guardrail.sh` with `GUARDRAIL_CONFIG` pointing at it (the `run_hook` pattern from
   `tests/test-guardrail.sh`), against two synthetic tool calls - one that must fire, one nearby
   legitimate call that must not. Both results are shown as evidence.
5. **Propose** the batch: per rule - the JSON, the dry-run evidence, where it will land. Nothing
   is written without confirmation.
6. **Apply** via `guardrails-upsert.sh add`, once per confirmed rule.
7. **Report**: resolved path and mode, the landed rules, and the removal one-liner
   (`/guardrails remove <name>`).

`list` mode wraps `guardrails-upsert.sh list`. `remove <name>` mode shows the matching rule and
confirms before running `remove` (searching both type arrays for the name; ambiguity -> ask).

### 3. Capture-cadence nudge

One line added to the `hooks/capture-cadence.sh` heredoc, alongside the existing capture lines:

    - a hazard or near-miss worth a permanent rule -> /guardrails

Same batching discipline as the rest of the cadence: accumulate, propose at a boundary.

### 4. Testing

New `tests/test-guardrails-upsert.sh`, same plain-bash harness style as `test-guardrail.sh`,
`GUARDRAIL_CONFIG` as the seam. Cases: create-from-missing (template copied, rule added);
add-to-existing; idempotent replace by name; `--field path` write rule; remove; remove-missing
errors; invalid regex rejected (jq dialect); malformed existing config refused, file untouched;
atomicity (failed add leaves no temp debris, original intact); `list` on empty/populated/missing
config; sidecar routing via the resolve-data-root fixtures; `GUARDRAIL_CONFIG` override wins.
Registered in `.github/workflows/ci.yml` (per the CLAUDE.md rule: CI lists every test script).

The dry-run mechanism itself needs no new tests - it is exercised by `tests/test-guardrail.sh`.

### 5. Packaging and docs

- README: `/guardrails` added to the skills list; the Guardrails section gains one sentence
  pointing at conversational authoring.
- `plugin.json`: description mentions `/guardrails`; version -> 0.22.0.
- `scripts/validate-plugin.py` picks the new skill up automatically (13 -> 14 skills).

### 6. Close-out (tracking)

- Promote the idea: `A-20260824-guardrail-conversational-authoring` (workstream: workflow).
- Decision record: `D-20260824-guardrails-canonical-hookify-misfits` - the §Decision above.
- New idea: `lint-conversational-authoring` (or fold/retire lint - capture the question, not an
  answer), noting lint's 1/10 audit score.
- On ship: `/project-log done`, resolved record with the merge SHA.

## Error handling

The skill inherits the script's fail-loud contract: any script error is reported to the user
verbatim with the config left untouched. The engine's own fail-open behavior is unchanged - a
config this slice writes is always parse-checked before landing, so the engine's silent-skip path
for invalid JSON should never see one of ours. Dry-run failures (rule does not fire on the
must-fire case, or fires on the must-not case) block the propose step: the draft is revised, not
shipped broken.

## Open questions

None - the fork (canonical format), trigger mode (model-invocable + cadence), and scope
(guardrails only) were decided in brainstorming, 2026-08-24.
