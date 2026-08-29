# Guardrails session mining (/guardrails mine) — design

Date: 2026-08-29. Status: approved (user picked it off the brief 2026-08-29). Closes the
guardrails-session-mining idea (spun off 2026-08-29 from the shipped
guardrail-conversational-authoring idea). Borrow source: hookify's bare `/hookify`
conversation mining — its one feature over `/guardrails`; per
D-20260828-build-only-what-native-wont this is a borrow bolted onto our engine, not a
build-alike of hookify.

## Problem

`/guardrails` authors a rule only when someone describes the hazard. The hazards that most
deserve rules surface *as events*: a near-miss mid-session, a correction the user had to
type, a command that failed in a way that could have been destructive. Today those convert
to rules only if someone notices and re-describes them. hookify's discovery half (mine the
conversation, propose rules) is the missing intake; our authoring half (dry-run through the
real engine, tracked shared config, deny semantics) is strictly better than theirs — so the
mine feeds the existing pipeline unchanged.

## Design

### New dispatch entry: `mine`

`/guardrails mine` scans **the current session's conversation** for near-misses and hands
each candidate to author mode. What counts as a near-miss:

- a **user correction or prohibition** ("don't X", "never push to Y", "stop doing Z") —
  the strongest signal; the user already paid for this rule once;
- a **hazardous call that happened or almost happened**: a destructive command that errored
  or was caught late, a write that nearly landed a secret or a tripwire string, a push
  aimed at the wrong remote;
- a **repeated manual guard** — the same check performed by hand more than once this
  session (the rule writes itself);
- an **existing-rule near-fire**: something a current rule *almost* matched but its regex
  missed (propose the tightened rule as a revision).

Explicitly NOT candidates: one-off typos, failures with no hazard (a red test), anything
already covered by a landed rule, and style preferences with no blast radius.

### Everything downstream is the existing pipeline, unchanged

Each candidate goes through author-mode **step 1 routing** (engine-fit → proceed;
hookify-fit → hand off with the one-line why; state-dependent → name
stateful-guardrail-predicates) and then the normal draft → **dry-run both directions
through the real engine** → batch proposal → confirm → apply. Nothing is written without
confirmation; the user may accept a subset; an empty mine says "no near-misses found" and
stops. Evidence discipline: every proposed rule cites the moment in the session it came
from (what happened, in one line) — a mined rule with no citable moment is not proposed.

### Scope: current session only

Mining reads the conversation in context — no transcript files, no history. The
batch/historical case (reading `~/.claude/projects/` transcripts) is deliberately left to
the transcript-mining-ingest idea: different cost profile, different dedupe problem, and it
targets facts/records, not rules. One decision record carries this
(D-20260829-mine-current-session-only).

## Non-goals

- No automatic mining (no Stop-hook trigger; explicit `/guardrails mine` only — the
  capture-cadence nudge already tells the model to propose rules for hazards it *notices*).
- No transcript-file reading (above).
- No lint-rule mining (lint.json's future is still the open lint-conversational-authoring
  question).

## Verification

Skill-prose slice: validator + full suite green; doc-freshness gate covers README/GUIDE.
