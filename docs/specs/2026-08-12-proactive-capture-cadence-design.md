# Proactive capture cadence - design

- Date: 2026-08-12
- Status: accepted (design approved; implementation pending)
- Workstream: meta

## Problem

Eleven of the twelve workspace-os skills carry `disable-model-invocation: true`; only `project-plan`
does not. In practice the user rarely invokes the capture skills by hand (especially the
project-tracking ones). Instead Claude does the work "on their behalf" - but, because the flag blocks
the clean invocation path, it does so by improvising the record inline (from the visible skill
descriptions and general knowledge, or by reading files ad hoc) rather than by running the skill. The
skills' safeguards - the exact record template, the CLAUDE.md/AGENTS.md boundary test, the
secret-scan, idempotency, confirm-before-write - are therefore bypassed precisely when capture
happens. The SessionStart hook injects only the `MEMORY.md` index, not the conventions or the skills,
so the "roundabout" path is not even convention-informed.

The `project-plan` asymmetry (model-invocable while `project-log`/`ingest` are not) is an accident:
Claude can auto-capture a future intent but not a decision, an action, or a durable fact.

## Goals

- Let Claude run the capture and read-only skills through their real ritual, proactively.
- Capture happens without interrupting mid-task: candidates accrue and are proposed as a batch at a
  natural stopping point; nothing lands unseen.
- Keep heavy, one-time, side-effecting skills strictly manual.

## Non-goals

- No change to what the records/facts themselves look like (schema is unchanged).
- No new capture skill; this is an invocation-and-cadence change over the existing skills.
- Not a hard, enforced gate: the cadence is an always-loaded instruction the model follows, not a
  blocking hook.

## Design

### 1. Skill invocation matrix

Remove `disable-model-invocation` (make model-invocable) from:

- `project-log` - decisions, actions, done, model-decision.
- `ingest` - durable facts (and the costly-first AGENTS.md gotcha write).
- `memory-lint` - read-only integrity + citation/boundary gates.
- `memory-search` - read-only recall.

(`project-plan` is already model-invocable; the four above bring the capture + read-only surface in
line with it.)

Keep `disable-model-invocation` (manual only) on the heavy / one-time / bulk skills:
`project-init`, `workspace-init`, `make-portable`, `memory-adopt`, `tracking-adopt`, `memory-sync`,
`continuity`. Claude must never auto-fire a repo bootstrap or a bulk adoption.

All skills stay `user-invocable`.

### 2. The capture cadence (SessionStart injection)

A new SessionStart hook, `hooks/capture-cadence.sh`, registered in `hooks.json`, emits a short
always-loaded instruction on stdout (SessionStart stdout is added to session context).

**Scoping (bounds the global bias).** The hook runs `scripts/resolve-data-root.sh` and emits the
cadence only when the repo actually has workspace-os data - a `project-tracking/` or `memory/`
directory under the resolved `data_root` (and, in sidecar mode, the workspace tier). If neither
exists, or the repo is not a workspace-os repo, it prints nothing and exits 0. Fail open always. It
fires in BOTH data-root modes (unlike `sidecar-memory-context.sh`, which is sidecar-only).

**Injected text (final wording tuned in implementation), roughly:**

> ## workspace-os capture cadence
> As you work in this repo, watch for durable items worth recording and capture them proactively:
> - a decision (a choice + why) -> `/project-log decision` (or `model-decision`)
> - a started or finished action -> `/project-log action` | `done`
> - a durable fact about this codebase -> `/ingest`
> - a future intent -> `/project-plan`
>
> Do not interrupt mid-task. Accumulate candidates and PROPOSE them as a batch at a natural stopping
> point (task done, before a commit). On the user's confirmation, invoke the relevant skill so the
> record follows its full ritual (format, the AGENTS.md/CLAUDE.md boundary test, secret-scan,
> idempotency). Skip trivia; capture only what future-you could not re-derive.

### 3. Description nudges

Update the `project-log` and `ingest` descriptions so the model's own invocation trigger aligns with
the cadence (proactive, batched at a stopping point). The read-only skills need no description change
- `memory-lint` and `memory-search` already say "use after editing memory / when recall seems stale,"
which the model can now act on directly.

### 4. Integration notes

- **Confirmation is not doubled.** The batch proposal at the stopping point IS the user-facing
  confirmation. When Claude then invokes `ingest` for a costly-first AGENTS.md bullet, that skill's
  confirm-before-write becomes a final exact-bullet check (showing the precise text and path), not a
  fresh gate. Acceptable and useful; not redundant.
- **Both modes.** The cadence hook fires in in-repo and sidecar modes; only its data-existence probe
  differs by mode (via `resolve-data-root.sh`).

## Testing

- `tests/test-capture-cadence.sh` (bash + the resolver): the hook emits the cadence in a scratch repo
  that has workspace-os data (in-repo and sidecar fixtures), prints nothing in a repo without it, and
  never errors (fail open) when not in a git repo.
- `scripts/validate-plugin.py` passes with the new hook registered in `hooks.json`.

## Records and version

- Decision record `D-20260812-proactive-capture-cadence`: capture + read-only skills become
  model-invocable and a SessionStart cadence hook drives proactive, batched capture; supersedes the
  blanket `disable-model-invocation` default for those skills. Heavy/one-time skills stay manual.
- Minor version bump.

## Global constraints

- No em dashes (U+2014) on added lines; plain ASCII.
- The hook fails open (exit 0, no output) whenever anything is missing or the repo is not a
  workspace-os repo; it never blocks a session.
- Reuse `scripts/resolve-data-root.sh` as the single source of mode/data-root truth; do not
  re-derive paths.
