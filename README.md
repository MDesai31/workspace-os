# workspace-os

A portable personal **project operating system** — a Claude Code plugin you install once per
machine and carry job-to-job.

The mental model is one split: the **engine** (this plugin — skills, hooks, conventions,
templates) is installed once per machine and updated centrally; the **data** it manages lives in
each project's own repo (`<repo>/docs/project-tracking/`, `<repo>/docs/memory/`,
`<repo>/docs/playbooks/`), version-controlled with that project's code so it travels with the
repo, not the machine. For enterprise repos where nothing may be committed in-tree, a **sidecar
mode** keeps the same data layer in a local-only `_meta/` folder instead — see
[GUIDE.md](GUIDE.md#setting-up-an-enterprise-workspace-sidecar-mode).

**New here? Read [GUIDE.md](GUIDE.md)** — the runbook: setup walkthroughs, the daily workflow,
what each automatic hook does, and troubleshooting.

## Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code) (the skills and hooks run inside it)
- `git`, `jq`, and `python3` on PATH (the hooks are bash+jq; the memory validator is python3)

## Install

In any Claude Code session:

```
/plugin marketplace add MDesai31/workspace-os
/plugin install workspace-os
```

Then restart Claude Code once (hooks load at session start).

## Five-minute quickstart

In a Claude Code session inside any git repo you own:

1. `/project-init` — stamps the tracking + memory scaffold into `docs/` and seeds the repo's
   workstream tags. Commit what it creates.
2. `/project-log action` — record the first thing you're working on.
3. `/ingest` — capture one durable fact about the codebase into `docs/memory/`.
4. `/project-status brief` — see the whole picture: open actions, ideas, what to do next.

From then on you mostly don't invoke anything: a session-start nudge has Claude propose
captures (decisions, facts, hazards, procedures) as you work, batched at natural stopping
points, and nothing is ever written without your confirmation.

## Feature map

| | Surface | One line | More |
|---|---|---|---|
| **Set up once (per repo)** | `/project-init` | stamp the tracking + memory scaffold into a repo | [GUIDE](GUIDE.md#setting-up-a-personal-repo) |
| | `/workspace-init` | mark an enterprise workspace for local-only sidecar data | [GUIDE](GUIDE.md#setting-up-an-enterprise-workspace-sidecar-mode) |
| **Daily** | `/project-log` | log an action / decision / model-decision / discovery / finding / meeting; `done` archives; `verdict` closes a finding on evidence; `propagated` records a landing in another checkout; `release-notes` cuts a changelog | [conventions](conventions/project-tracking.md) |
| | `/project-plan` | park a future intent without starting it | [conventions](conventions/project-tracking.md) |
| | `/project-status` | read-only status + `brief` "what should I work on next"; `matrix` shows per-checkout propagation in a marked workspace | [GUIDE](GUIDE.md#daily-workflow) |
| | `/ingest` | capture a durable fact (or `gotcha:` a stale prior) into memory | [conventions](conventions/memory.md) |
| | `/memory-search` | find a fact by keyword, or its backlinks | [GUIDE](GUIDE.md#daily-workflow) |
| | `/handoff` | pause an effort into a live handoff record; auto-surfaced at session start | [conventions](conventions/project-tracking.md) |
| | `/work-journal` | summarize recent work from git + tracking; `log` records the session; `prep` briefs a meeting | [GUIDE](GUIDE.md#daily-workflow) |
| **Occasionally** | `/guardrails` | author a deny/warn rule from a described hazard (dry-run proven); `mine` scans the session for near-misses; `pack` imports versioned policy packs ([format](conventions/packs.md)) | [GUIDE](GUIDE.md#guardrails) |
| | `/playbook` | author/adopt a procedure that auto-surfaces at trigger time | [conventions](conventions/playbooks.md) |
| | `/memory-lint` | memory integrity (link graph, index parity, citation freshness) + playbook lint | [GUIDE](GUIDE.md#maintenance-linting-and-updating) |
| | `/memory-adopt` `/tracking-adopt` | adopt a repo's existing docs / roadmaps / git history; `foreign` converts an existing notes/wiki store | [GUIDE](GUIDE.md#adopting-an-existing-repo) |
| | `/memory-sync` | migrate a fact from `~/.claude` auto-memory into a repo | [GUIDE](GUIDE.md#occasional-operations) |
| | `/make-portable` | retrofit the vendor-neutral layer onto an existing memory base | [PORTABILITY_NOTES](PORTABILITY_NOTES.md) |
| | `/continuity` | scaffold a repo-root bus-factor runbook (CONTINUITY.md) | [GUIDE](GUIDE.md#occasional-operations) |
| **Automatic (hooks)** | `guardrail.sh` | blocks/warns on hazardous Bash + writes (secrets, force-push, your rules) | [GUIDE](GUIDE.md#guardrails) |
| | `playbook-surface.sh` | surfaces a matching playbook once per session (before or after the call) | [GUIDE](GUIDE.md#playbook-surfacing) |
| | `lint.sh` | runs your declared linters on edited files, feeds diagnostics back | [GUIDE](GUIDE.md#advisory-lint) |
| | `dispatch-ledger.sh` | logs every subagent dispatch (sizes only) to a local-only ledger | [GUIDE](GUIDE.md#dispatch-ledger) |
| | `capture-cadence.sh` `sidecar-memory-context.sh` | session-start context: capture nudge + sidecar memory index | [GUIDE](GUIDE.md#the-capture-cadence) |

## Updating

Improve the engine → merge to `main` → on each machine: pull this repo, then
`claude plugin update workspace-os@workspace-os`, then restart Claude Code. Details and
troubleshooting in [GUIDE.md](GUIDE.md#maintenance-linting-and-updating).

## Going deeper

- [GUIDE.md](GUIDE.md) — the runbook (setup, daily use, hooks, troubleshooting)
- [ARCHITECTURE.md](ARCHITECTURE.md) — the engine/data split and how the pieces relate
- [PORTABILITY_NOTES.md](PORTABILITY_NOTES.md) — the vendor-neutral layer
- `conventions/` — the single sources of truth the skills follow:
  [project-tracking](conventions/project-tracking.md) · [memory](conventions/memory.md) ·
  [playbooks](conventions/playbooks.md) · [packs](conventions/packs.md) ·
  [data-root](conventions/data-root.md)
