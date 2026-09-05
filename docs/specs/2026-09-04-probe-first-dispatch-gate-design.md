# Probe-first dispatch gate — design

Date: 2026-09-04. Status: approved (user picked it off the brief 2026-09-04, directly after
stateful-guardrail-predicates shipped). Closes the probe-first-dispatch-gate idea (EC2 audit
2026-08-24). Prerequisites: dispatch-ledger (v0.23.0) and stateful-guardrail-predicates
(v0.34.0) both shipped.

## Problem

The 2026-08 EC2 audit measured two subagent dispatches burning ~484k tokens re-deriving a CSV
the pipeline had already written; a 0.25-second probe would have surfaced it. The lesson lives
as CLAUDE.md prose, binding only while the model chooses to obey it. Nothing intercepts a
dispatch today: `hooks.json` registers PreToolUse on `Bash|Edit|Write` only.

## Two facts that shape the design

- **PreToolUse cannot inject context non-blockingly** (verified 2026-08-24,
  `conventions/playbooks.md`). `hooks/playbook-surface.sh` already solves this with
  **deny-once**: write a per-session marker, exit 2 with instructions on stderr, and the retry
  passes. The gate reuses that pattern rather than inventing one.
- **A predicate is the wrong tool here.** The idea assumed "has the probe run" would live in
  a predicate, but a probe's value is its *output*, not its exit status. The session marker
  answers "has it run"; the output travels in the deny message.

## Design

### Rule shape: a `dispatch` array in `guardrails.json`

```json
{ "dispatch": [
    { "name": "pipeline-output-exists",
      "match": "(derive|compute|generate|rebuild).*(csv|features)",
      "probe": "ls -la data/out/ && head -3 data/out/features.csv",
      "reason": "the pipeline may already have written this; check before re-deriving." }
] }
```

Fields: `name`, `match`, `probe`, `reason`. No `action` (a dispatch rule is always
deny-once), no `field`, no `predicate`. The regex runs over the dispatch's `description` and
`prompt` joined by a newline, so a rule can key on the label or the question text.

Rejected: a separate `probes.json` + `probe-gate.sh` hook. Cleaner isolation, but it needs its
own authoring path, list/remove, and pack support — all of which `guardrails.json` gives for
free through the upsert CLI, `/guardrails`, and `pack-import.sh`.

### Engine (`hooks/guardrail.sh`)

- `hooks.json` adds a PreToolUse entry with matcher `Task|Agent` pointing at the guardrail
  engine only (playbook-surface's matcher is unchanged).
- New tool case `Task|Agent`: subject = `description + "\n" + prompt`. For every `dispatch`
  rule whose regex matches AND whose per-session marker is absent:
  1. write the marker **first** (so the retry passes even if the probe misbehaves);
  2. run the probe in the call's cwd (`.cwd` from stdin, the v0.34.0 `call_cwd`) under a
     **10-second** timeout, capturing combined stdout+stderr, capped at **4000** characters
     (truncated with a marker line);
  3. collect a block: `probe-first: '<name>' - <reason>`, the output, and — when the probe
     exited non-zero or timed out — `(probe exited <N>)` so Claude learns the probe is broken
     instead of silently paying for the dispatch.
- If any rule fired: print every block to stderr, then one closing line — `Re-dispatch only if
  the output above does not answer the question.` — and exit 2. Otherwise exit 0 silently.
- Markers: `${TMPDIR:-/tmp}/workspace-os-probed-<session_id>/<rule-name>` — the
  playbook-surface convention, a separate directory so slugs cannot collide. Once per session
  per rule; a new session probes again.
- Built-in defaults and `bash`/`write` rules never run for a dispatch; dispatch rules never run
  for Bash/Edit/Write.

Rejected: keying markers on the matched text (a second, different question would re-probe) —
the first deny puts the probe output in context, where the second question can see it. A
`warn`-style non-blocking variant — the platform cannot deliver one from PreToolUse.

### CLI (`scripts/guardrails-upsert.sh`)

`--type dispatch` on `add` requires `--probe CMD` (non-empty) and dies on `--action`, `--field`,
or `--predicate`. `bash|write` die on `--probe`. `list` shows dispatch rows with the probe in the
column `bash`/`write` rows use for the predicate. `remove --type dispatch` works unchanged.

### Skill (`skills/guardrails/SKILL.md`)

Author-mode step 1 gains a fourth route, **dispatch-fit**: "we keep re-deriving X", "check Y
before spending an agent on Z" — a `dispatch` rule whose probe is the cheap check. Step 3's
dry-run for a dispatch rule is three synthetic `Task` calls with a throwaway `session_id`:
a matching dispatch must deny with the probe output visible; the same call again must pass
silently; a non-matching dispatch must pass. Report step names the removal one-liner as before.

### Packs, validator, template, docs

- `conventions/packs.md`: `guardrails.dispatch` optional, rule shape stated.
- `scripts/validate-plugin.py`: dispatch rules in packs require `name`, `match`, `probe`,
  `reason`.
- `scripts/pack-import.sh`: stamps/replaces `dispatch` rules like the other two arrays.
- `templates/guardrails.json`: `dispatch: []`, an `_examples.dispatch` entry, and a comment
  line explaining the once-per-session deny.
- `GUIDE.md` § Guardrails: a "Probe-first dispatch" bullet; README engine row mentions
  dispatches; the dispatch-ledger spec's "no gating" non-goal gets a pointer to this spec.

### Tests

`tests/test-guardrail.sh`: matching dispatch denies with probe output; same session retry
passes silently; new session denies again; non-matching dispatch passes; two matching rules
surface in one deny; a failing probe denies and reports its exit status; a `sleep 30` probe is
cut off inside the budget; output over 4000 chars is truncated; a Bash call ignores dispatch
rules. `TMPDIR` is the marker seam (playbook-surface precedent).

`tests/test-guardrails-upsert.sh`: dispatch add persists `probe`; add without `--probe` dies;
`--action` with dispatch dies; `--probe` with bash dies; list shows it; remove works.

`tests/test-pack-import.sh`: a pack with a dispatch rule imports and re-imports idempotently.

### Out of scope (deliberate)

Marker keyed on matched text; a non-blocking variant; mining sessions for re-derivation
patterns; passing the dispatch text to the probe via environment.

## Verification

Suite green locally and in CI before merge; validator clean; `memory_graph: clean` on the
close-out commit. Version 0.35.0.
