# workspace-os Guide

The runbook. [README.md](README.md) is the front door (what it is, install, quickstart,
feature map); this file is the task-oriented walkthrough — setup, daily use, what the
automatic hooks will do mid-session, occasional operations, maintenance, troubleshooting.
The `conventions/` docs stay the single sources of truth for schemas and rules; this guide
links to them rather than restating them.

## Contents

- [Setting up a personal repo](#setting-up-a-personal-repo)
- [Setting up an enterprise workspace (sidecar mode)](#setting-up-an-enterprise-workspace-sidecar-mode)
- [Daily workflow](#daily-workflow)
- [The capture cadence](#the-capture-cadence)
- [The automatic hooks](#the-automatic-hooks)
- [Adopting an existing repo](#adopting-an-existing-repo)
- [Occasional operations](#occasional-operations)
- [Maintenance, linting, and updating](#maintenance-linting-and-updating)
- [Troubleshooting](#troubleshooting)

## Setting up a personal repo

A "personal repo" is any repo where committing docs in-tree is fine (your own projects).

1. Open a Claude Code session at the repo root and run **`/project-init`**. It stamps:
   - `docs/project-tracking/` — action-items, ideas, decisions-log, resolved, and a README
     seeded with the repo's **workstream tags** (you'll be asked for 3–7 of them: the
     cross-cutting axes of the project, e.g. `pipeline · strategy · ops`).
   - `docs/memory/` — the shared knowledge base plus its `MEMORY.md` index, an
     `@docs/memory/MEMORY.md` import in the repo's `CLAUDE.md` (so every session loads the
     index), and the portable layer: an operator's manual, a vendored `memory_graph.py`
     validator, and an `AGENTS.md` entry point usable by non-Claude tools.
   - `.gitattributes` merge rules (`merge=union`) so append-heavy tracking files don't
     conflict across branches.
2. **Commit everything it created.** The data layer is meant to be versioned with the code —
   that's the point.
3. Optional, per repo:
   - Guardrail rules: run `/guardrails` and describe a hazard (see
     [Guardrails](#guardrails)).
   - Advisory linters: copy `templates/lint.json` to `.claude/lint.json` (see
     [Advisory lint](#advisory-lint)).

## Setting up an enterprise workspace (sidecar mode)

For repos where **nothing may be committed or left untracked in-tree** (employer code).
Sidecar mode keeps the identical data layer *outside* the repo:

1. Arrange the repos under one workspace folder, e.g. `~/work/acme/repo-a`, `~/work/acme/repo-b`.
2. In a session at the workspace root, run **`/workspace-init`**. It creates
   `~/work/acme/_meta/` — a **local-only git repo with no remote** (history without push) —
   and a `workspace.json` marker.
3. That's it. Every repo under the marked workspace is now in sidecar mode automatically:
   tracking and memory for `repo-a` live at `_meta/repo-a/`, and a workspace-wide memory tier
   lives at `_meta/memory/` (shared by all the workspace's repos). A SessionStart hook
   surfaces the memory index (there is no CLAUDE.md import to add — the repo tree is never
   touched, and the guardrail engine warns if anything tries).

Where data lives is always **resolved, never assumed** — every skill and hook asks
`scripts/resolve-data-root.sh` and announces the mode it found. Rules in
[`conventions/data-root.md`](conventions/data-root.md).

## Daily workflow

You rarely invoke skills by hand — see [the capture cadence](#the-capture-cadence). When you
do, the daily set is:

- **`/project-log action`** — an open work item (`A-YYYYMMDD-slug`). **`/project-log done`**
  moves it to the resolved record with the completion date and commit ref.
- **`/project-log decision`** — a choice plus the why (`D-YYYYMMDD-slug`, append-only;
  reversals happen by supersession, never edits). **`model-decision`** is the DS/ML variant
  (dataset vintage, validation protocol, one headline metric, a run pointer).
- **`/project-plan`** — a future intent: the why and rough timing, parked, not started.
- **`/ingest`** — a durable fact about the codebase into `docs/memory/`;
  `gotcha:`/`stale-prior:` routes a corrected assumption to the right home (a CLAUDE.md
  bullet or a memory fact).
- **`/project-status`** — the read-only view: open actions by workstream, ideas by priority,
  recent decisions/resolved. **`/project-status brief`** answers "what should I work on
  next" (filter by workstream or `high`/`mid`/`low`).
- **`/memory-search <query>`** — find a fact; `links <fact>` shows what links to/from it.

In a marked workspace with several checkouts of one repo, log where a fix has landed with
`/project-log propagated` and see what each checkout still needs with `/project-status matrix`.

Stopping with work unfinished? **`/handoff`** writes a live record of what's mid-flight
(mission, traps, next steps) into `project-tracking/handoffs/`; your next session in the
repo sees it automatically at start — resume by asking to pick it up, and it's deleted when
the work completes via `/project-log done`. **`/work-journal`** answers "what did I do this
week" from git history cross-referenced with tracking; **`/work-journal log`** records the
session in `work-log.md`.

Schemas and lifecycle: [`conventions/project-tracking.md`](conventions/project-tracking.md)
and [`conventions/memory.md`](conventions/memory.md).

## The capture cadence

In any repo with workspace-os data, a SessionStart hook (`hooks/capture-cadence.sh`) injects
a short standing instruction: as work happens, Claude watches for durable items — a decision,
a finished action, a fact, a future intent, a hazard worth a guardrail rule, a repeated
procedure worth a playbook — and **proposes them as a batch at natural stopping points**
(task done, before a commit). Nothing is written without your confirmation, and every capture
goes through the relevant skill's full ritual (format, secret-scan, idempotency). In repos
without workspace-os data the hook stays silent.

## The automatic hooks

Five hooks ship with the plugin. All of them **fail open**: any error, missing dependency, or
absent config means silence, never a broken session. Hooks load at session start — after
installing or updating, restart Claude Code before expecting them.

### Guardrails

`hooks/guardrail.sh` (PreToolUse on Bash/Edit/Write) guards every command and file write:

- **Built-in, always on:** warn-only advisories for possible secrets in writes, force-push to
  `main`/`master`, and root-like `rm -rf`; hard **denies** for high-confidence secrets
  (private-key blocks, `AKIA…`, `sk-…`).
- **Per-repo rules** live in `.claude/guardrails.json` (in-repo mode) or
  `<data_root>/guardrails.json` (sidecar). `deny` blocks the call with your reason shown to
  Claude; `warn` prints an advisory. Tag the repo `ip_class`
  (`personal`/`employer`/`clean-room`) and add tripwire `write` rules for cross-boundary IP
  leakage.
- **Author rules by conversation** — run `/guardrails` and describe the hazard ("we never
  push to the enterprise remote"). It drafts the rule, **dry-runs it through the real engine**
  (one call that must fire, one that must not — you see both results), and applies it only on
  confirm. `/guardrails list` and `/guardrails remove <name>` complete the loop. What you'll
  see when a deny fires: the tool call fails with the rule's reason — that's the rule working.

**Policy packs** bundle ready-made rules: `/guardrails pack list` shows what ships with the
plugin, `/guardrails pack add public-repo` imports deny-tier protections for a public repo,
and `/guardrails pack add enterprise-clean-room` sets up an employer IP boundary (it asks
for your tripwire strings and enterprise remote pattern, then denies both everywhere in the
repo). Re-importing after a plugin update refreshes a pack's rules without touching rules
you wrote yourself; `/guardrails pack remove <name>` takes one out again. Format:
`conventions/packs.md`.

### Playbook surfacing

`hooks/playbook-surface.sh` (PreToolUse + PostToolUse on Bash/Edit/Write) surfaces a matching
[playbook](conventions/playbooks.md) — a stored procedure with trigger, steps, verify, known
traps — at most **once per session per playbook**:

- `surface: before` (default): the *first* matching call in a session is **denied once** with
  "read `<path>` first, then retry." **This is expected behavior, not an error** — Claude
  reads the playbook and the retry goes through. Use for procedures where an unguided first
  call is the expensive one.
- `surface: after`: the first matching call runs, then the playbook body is injected as
  context. Frictionless, for advisory-grade procedures.

Author with `/playbook`, adopt existing how-to docs with `/playbook adopt <path>`, inspect
with `/playbook list`.

### Advisory lint

`hooks/lint.sh` (PostToolUse on edits) runs *your* linters on each edited file and feeds any
diagnostics back to Claude to fix. No built-ins: copy `templates/lint.json` to
`.claude/lint.json` and declare `{name, match, command}` entries (`match` is a path regex;
the engine runs `<command> <file_path>`). A clean file is silent.

### Dispatch ledger

`hooks/dispatch-ledger.sh` (PostToolUse on subagent dispatches) appends one JSONL line per
dispatch — agent type, a short description, prompt/response **sizes** (never the text),
estimated tokens — to `~/.claude/workspace-os/dispatch-ledger.jsonl`. The ledger is
**local-only by construction** (it lives outside every repo) so it can never be committed
anywhere. Read it back:

```
bash scripts/dispatch-ledger-summary.sh [--repo NAME] [--top N]
```

### Session-start context

`hooks/capture-cadence.sh` (the [capture cadence](#the-capture-cadence)) and
`hooks/sidecar-memory-context.sh` (in sidecar mode, injects the memory index that in-repo
mode gets via the CLAUDE.md import).

## Adopting an existing repo

For a repo with pre-existing docs and work-state, after `/project-init`:

- **`/memory-adopt`** — scans free-form docs (README, design notes, CLAUDE.md reference
  content, resolved `@import`s), proposes facts for `docs/memory/`, applies only what you
  confirm. Idempotent; secret-scanned.
- **`/tracking-adopt`** — routes roadmap entries → ideas, recorded decisions → the decisions
  log, open TODOs → action items. **`/tracking-adopt git`** mines merged git history into
  `resolved.md` (one record per merged unit, real SHAs, deduplicated).
- **`/playbook adopt <path>`** — reshapes an existing how-to doc into trigger-surfaced
  playbooks. The source doc is never modified without a separate confirmation.

All adoption is opt-in and propose→confirm→apply; nothing is reshaped silently.

## Occasional operations

- **`/memory-sync`** — migrate a fact from your machine-local `~/.claude` auto-memory into a
  repo's shared `docs/memory/` (one-way, content-gated).
- **`/make-portable`** — retrofit the vendor-neutral layer (operator's manual, vendored
  validator, `AGENTS.md`, `CLAUDE.md` bridge) onto a memory base created before it existed;
  add-only and idempotent. `refresh` re-copies the plugin-owned files (confirm-gated), never
  your facts. Background: [PORTABILITY_NOTES.md](PORTABILITY_NOTES.md).
- **`/continuity`** — scaffold/review a repo-root `CONTINUITY.md` bus-factor runbook:
  auto-inventories scheduled jobs (systemd/cron/CI), one obligations row per dependency with
  detection, access *pointers* (never secrets), re-verify budgets.

## Maintenance, linting, and updating

- **Memory integrity:** `/memory-lint` runs the deterministic graph pass (broken wikilinks,
  index parity, orphans, citation freshness against the code, tracking-boundary checks) plus
  model-judgment checks. For CI or pre-commit in a data repo:
  `python3 scripts/memory_graph.py --check`.
- **Updating the plugin:** merge to `main`, then on each machine
  `claude plugin update workspace-os@workspace-os` (the full `name@marketplace` form), then
  restart Claude Code. If your marketplace source is a **local directory checkout** (the
  development setup), `git pull` that checkout *first* — the update snapshots the local
  directory, not GitHub.
- **House rules for changes to this repo:** every test script listed in
  `.github/workflows/ci.yml`, green CI before merge, version bump in
  `.claude-plugin/plugin.json` on user-visible changes. See `CLAUDE.md`.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Skills exist but no hook ever fires | Hooks load at session start — restart Claude Code after install/update. Also check `jq` is installed: the hooks fail **open**, so a missing `jq` means silence, not errors. |
| A Bash call was suddenly denied with "playbook … read … first, then retry" | Expected: a `surface: before` playbook fired its once-per-session read gate. Read the file, retry, continue. |
| A write was blocked mentioning secrets or a guardrail rule | The guardrail engine working as configured. `/guardrails list` shows the active rules; the built-in secret denies have no config. |
| "Where is my tracking/memory data?" in an enterprise repo | You're in sidecar mode: data is at `<workspace>/_meta/<repo-folder>/`, not in the repo. `bash scripts/resolve-data-root.sh` prints the resolved mode and path. |
| `/project-init` refuses to run | The scaffold already exists — it never overwrites. Use the adoption skills to fold in existing content. |
| Plugin update says updated but behavior is old | Restart Claude Code (hooks and skills load at session start). On a dev machine with a directory marketplace, also confirm the local checkout was pulled first. |
| Memory lint reports broken `A-`/`D-` links from workspace-tier facts | Pass one `--tracking-root` per repo tier (the flag repeats) — see the workspace-tier invocation in `skills/memory-lint/SKILL.md`. |
| Dispatch ledger is empty | Capture starts on the first session *after* install; check `~/.claude/workspace-os/dispatch-ledger.jsonl` exists and that dispatches actually happened. |
