---
name: project-status
description: Read-only status view over the current repo's project tracking — open actions by workstream, ideas by priority, recent decisions and resolved items, plus a brief mode for "what should I work on next". Use on /project-status, or when the user asks "what's next", "where are we", "what's the status", or "what should I work on". Writes nothing.
user-invocable: true
disable-model-invocation: false
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "[workstream | high|mid|low] | brief [workstream | high|mid|low]"
---

# Project Status

A **read-only** view over `<data_root>/project-tracking/` — the only skill in this plugin that
writes nothing, anywhere, in any mode. No propose/confirm gate: there is nothing to confirm.
The record schema and lifecycle live in `conventions/project-tracking.md`; this skill only
renders what the tracking files already say. (Report/brief output shapes adapted from
zachburke9/keystone-engine's project-status skill, MIT — re-founded on per-repo tracking files
instead of its single-workspace project registry.)

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/` in BOTH modes; never hardcode `docs/…`. Announce the
   resolved mode. Reads only — no sidecar commit step applies.
   If `<data_root>/project-tracking/` does not exist: say so, point at `/project-init`
   (greenfield repo) or `/tracking-adopt` (repo with existing work-state docs), and stop.
   Never create anything.

1. **Parse `$ARGUMENTS`.** A leading `brief` selects brief mode. The remaining token (if any)
   is the filter, matched case-insensitively — first against the repo's workstream list (the
   tracking README's `## Workstreams` section, else the tags actually present in records),
   then against the priority enum `high` / `mid` / `low`. Unknown token → say so, list the
   valid workstreams, and stop. No filter → whole-repo view.

2. **Read fresh.** Read all four files — `action-items.md`, `ideas.md`, `decisions-log.md`,
   `resolved.md` — every run; never trust a remembered copy. Parse **leniently**: adopted
   repos carry legacy IDs (`#21`, item `K`) and non-record prose (e.g. a pre-existing resolved
   table). Render what is there as found — never rewrite it, never warn about its format.
   Count only what parses as a record; mention unparsed content in one line (e.g. "plus a
   pre-existing resolved table").

3. **Render** the selected mode (below). Recent-window only — never dump full history. A file
   still showing its italic placeholder line (`_No open items yet._`, `_No ideas captured
   yet._`, …) renders as a one-line empty state; continue with the remaining sections. With a
   filter, scope every section to it and name the filter in the header.

## Report mode (default)

Sections, in order:

1. **Header** — repo name, today's date (`date +%F`), resolved mode, active filter if any.
2. **Open actions** grouped by workstream: `ID — title — age` (age in days from `Created:`),
   oldest first within each workstream. Untagged records group under `(untagged)`; if the repo
   has no workstream enum and no tagged records, use a single untagged group — never invent
   workstreams.
3. **Ideas** by priority, high → mid → low: one title line each (name + a one-phrase hook);
   `someday`-priority ideas collapse to a single count line.
4. **Recent decisions** — last ~5, newest first: `ID — title`. Mark superseded decisions
   (read rule: an appended `Superseded-by:` line wins over `Status:`).
5. **Recent resolved** — last ~5, newest first: `ID — title — completed date`.
6. **Summary** — one line of counts (open actions, ideas by priority tier, decisions,
   resolved).

## Brief mode (`/project-status brief`)

The "what should I work on" view — one sentence per item:

```
PROJECT BRIEF: <date>

IMMEDIATE (high)
- <ID>: one line on state + next action
NEXT (mid)
- ...
LONG-TERM (low)
- ...

Suggested order: <IDs> — priority first, then staleness (oldest Created first).
```

Inputs: open action items plus ideas whose `Priority:` is `high` / `mid` / `low` (skip
`someday`). Action records carry no priority field — place each in a tier by judgment from
its content and age. Within a tier, oldest `Created:` first. Always end with the suggested
order line.
