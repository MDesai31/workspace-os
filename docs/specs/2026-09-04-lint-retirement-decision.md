# Advisory lint: retire — decision

Date: 2026-09-04. Status: decided (user: "retire it", 2026-09-04). Closes the
lint-conversational-authoring idea (EC2 audit 2026-08-24), which captured the QUESTION —
author, fold, or retire `lint.json` — rather than presupposing a build.

## The surface

`hooks/lint.sh` (PostToolUse on Edit/Write/MultiEdit) read a per-repo `.claude/lint.json`
(sidecar: `<data_root>/lint.json`), ran each declared `{name, match, command}` linter whose
path regex matched the edited file, and fed non-empty output back to Claude as
`additionalContext`. It shipped no built-in linters; packs could carry a `lint.linters` array.

## The options

- **Author** — a `/lint` skill mirroring `/guardrails`: propose linters from what the repo
  contains, dry-run, write on confirm. Cures the hand-authored-JSON disease the same way.
- **Fold** — a linter becomes a guardrail `write` rule that runs a command; retire the second
  hook and config.
- **Retire** — delete the hook, template, tests, and pack support.

## Decision: retire

- **Evidence gate, honestly read.** The idea waited for `/guardrails` adoption evidence. As of
  today the guardrail engine has predicates, dispatch rules, packs, session mining — and exactly
  one real rule in one repo, written hours ago. Conversational authoring has not yet produced
  evidence that it lights up a dark surface; copying the pattern to lint would be building on
  an unproven cure.
- **Natives cover it** (D-20260828-build-only-what-native-wont). Editor integrations, CI, and
  Claude Code's own per-repo PostToolUse hooks all run linters; the plugin's version added a
  second config format and a second engine for a capability the host already offers with no
  differentiator (no shared deny semantics, no sidecar-only value, no ip_class tie-in).
- **Fold rejected.** It would keep the capability alive inside the guardrail engine's write
  path with the same zero-adoption problem, plus an engine change nobody asked for.
- **Author rejected.** A skill that proposes `ruff`/`eslint` entries is a build-alike of the
  host's hook config; the idea itself flagged this as the presupposition to avoid.

## Removal scope (v0.37.0)

`hooks/lint.sh`, `templates/lint.json`, `tests/test-lint.sh`, `tests/fixtures/fake-linter.sh`;
the PostToolUse entry in `hooks/hooks.json`; the CI step; `lint` resolution/import/removal in
`scripts/pack-import.sh` and its tests; `lint` in `conventions/packs.md` and both shipped
packs; `scripts/validate-plugin.py` now **rejects** a `lint` key in a pack (retired — fail
loud, not silent drop); the `/guardrails` pack-mode wording; README hook row; GUIDE § Advisory
lint and its onboarding pointer; ARCHITECTURE.md; CLAUDE.md. The 2026-08 adoption-audit memory
fact keeps its historical mention.

Not removed: `/memory-lint` and `playbook-lint.sh` (different tools, same word).

## Migration

Any repo with a `.claude/lint.json` (none known) loses nothing that Claude Code's own
`PostToolUse` hook in `.claude/settings.json` cannot express in five lines; the GUIDE
retirement note says so.
