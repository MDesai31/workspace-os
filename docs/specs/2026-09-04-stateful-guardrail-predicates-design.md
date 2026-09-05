# Stateful guardrail predicates — design

Date: 2026-09-04. Status: approved (user picked it off the brief 2026-09-04). Closes the
stateful-guardrail-predicates idea (EC2 audit 2026-08-24). Its gate — guardrail-conversational-
authoring shipped first, so a richer rule language has an authoring path — is cleared.

## Problem

`hooks/guardrail.sh` matches regex over text only: a Bash command, or a write's content or
path. A rule therefore cannot depend on machine or repo state. Three hazards this work has hit
have no rule today and are handled by prose or one-off checks: running a generating script
while `/home` sits at 95%+, writing while the checkout is on the wrong branch (folder names
deliberately do not match branch names), and dispatching an expensive agent before its cheap
probe has run. `/guardrails` author mode currently routes these as "state-dependent: the engine
cannot express it" and points at this idea.

## Design

### Schema: an optional `predicate` on any rule

```json
{ "name": "no-gen-on-full-disk",
  "match": "python gen\\.py",
  "predicate": "[ $(df --output=pcent /home | tail -1 | tr -dc 0-9) -ge 95 ]",
  "action": "deny",
  "reason": "/home is at 95%+; free space before generating." }
```

- `predicate` is a shell command string, valid on `bash` and `write` rules alike.
- **AND with `match`, exit 0 = fire.** The rule fires only when the regex matches AND the
  predicate exits 0. The predicate is phrased as the *hazard condition*, the same way `match`
  is — "on main" fires a wrong-branch rule; "disk at 95%+" fires a disk rule.
- No predicate-only rules and no new rule type. A state check that should apply to every call
  of a tool uses `"match": ".*"`.
- Rules without a predicate are unchanged.

Rejected: "non-zero = fire" (the predicate as a precondition that must hold). It reads
naturally for the branch case but inverts the engine's fail-open contract — an erroring or
timing-out predicate exits non-zero and would *fire*, so errors would need a second signal.
Rejected: predicate replaces match (predicate-only rules). Simplest schema, but every such rule
pays a subprocess on every Bash/Edit/Write call with no regex gate to cheapen it.

### Engine (`hooks/guardrail.sh`)

The jq pass that selects matching config rules emits a third column, the predicate (empty when
absent). For each candidate row with a non-empty predicate the bash loop:

1. runs it as `bash -c "$predicate"` under a hard **5-second** timeout (`timeout 5` where the
   coreutils binary exists; bare `bash -c` otherwise — fail open, never fail closed);
2. in the directory the tool call came from — the `cwd` field of the hook's stdin JSON,
   falling back to the hook's own working directory — so `git branch --show-current` and
   relative paths mean what the author expects;
3. with stdout and stderr discarded (the predicate's only channel is its exit status);
4. exit 0 → the rule fires (deny/warn as configured); **anything else** — non-zero, timeout
   (124), command not found, syntax error — the rule is skipped.

**No caching.** A predicate runs on every call its regex matches. Branch and disk state change
mid-session; a per-session cache would answer a question nobody asked. Cost is bounded by
`match`: a narrow regex pays only when it hits.

### Trust model

A predicate is arbitrary shell stored in a version-controlled file and executed by a hook. That
is the same standing as repo-level Claude Code hooks (`.claude/settings.json`) and the existing
lint linters (`.claude/lint.json` commands), both of which already run repo-configured
commands. Decision: **run as-is; document the risk** — `guardrails.json` is part of the repo's
trusted configuration. The template comment and GUIDE say so plainly. Rejected: an allowlisted
predicate library (every new hazard class needs an engine change — the disease this slice
cures) and pack-forbidden predicates (packs are the plugin's own shipped rules; forbidding them
there while allowing them in hand-authored rules protects nothing).

### Authoring CLI (`scripts/guardrails-upsert.sh`)

`add` gains an optional `--predicate CMD` (either rule type). Stored verbatim; the only static
check is non-empty — a predicate's correctness is proven by the skill's dry-run, not by
inspection. Re-adding a rule by name without `--predicate` drops any prior predicate (the
existing replace-by-name semantics: the new rule is the whole rule). `list` gains a predicate
column (`-` when absent).

### Skill (`skills/guardrails/SKILL.md`)

Author-mode step 1: the "State-dependent" route becomes **engine-fit with a predicate**. Step 2
drafting guidance: phrase the predicate as the hazard condition (exit 0 = the hazard is
present), it runs in the call's cwd with a 5-second budget and its output discarded, prefer a
test that is cheap and side-effect free. Step 3, the dry-run gate, gains a third required case
for predicate rules: must fire (regex hits, state hazardous), must not fire on a nearby
legitimate command, and **must not fire when the state is healthy** (regex hits, predicate
false). The authoring session proves the healthy case by running the predicate by hand or by
substituting a known-false predicate for the dry-run. The pointer to the idea is removed.

### Packs, template, validator, docs

- `conventions/packs.md`: `predicate` is an optional string on pack rules, same semantics.
- `scripts/validate-plugin.py`: no change required — it checks required fields only and
  treats extra keys as data. A test-free assertion of this fact is fine: the validator run in
  CI covers it.
- `templates/guardrails.json`: `_comment` states the trust model and the predicate contract;
  `_examples.bash` gains a predicate example.
- `GUIDE.md` § Guardrails: one bullet on predicates and the trust statement.

### Tests

`tests/test-guardrail.sh` (engine):

- predicate true (`true`) + regex hit → fires;
- predicate false (`false`) + regex hit → passes, no output;
- predicate `sleep 10` → passes within the budget (fail open on timeout);
- predicate `[ "$(git branch --show-current)" = main ]` against a temp repo on `main` with the
  hook's stdin `cwd` pointing at it → fires; same rule with the repo on a feature branch →
  passes (proves both cwd handling and the branch hazard end to end);
- an existing no-predicate rule in the same config still fires (regression).

`tests/test-guardrails-upsert.sh` (CLI): `add --predicate` persists the field; `list` shows
it; re-add without `--predicate` drops it; `--predicate ""` dies.

### Out of scope (deliberate)

Passing the matched command/path/content to the predicate via environment, a per-rule timeout
override, a `Task` PreToolUse surface, and a session-scoped "which probes have run" record.
Those are probe-first-dispatch-gate's to design; this slice only gives it the predicate
mechanism it was gated on.

## Verification

Suite green locally and in CI before merge; validator clean; `memory_graph: clean` on the
close-out commit. Version 0.34.0.
