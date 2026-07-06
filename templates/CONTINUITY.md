# Continuity Runbook: keeping <REPO> running when the maintainer is out

The bus-factor doc. If the maintainer disappears for a month, this file is what a stranger
reads to know **what silently stops, how to notice, and how to restart it**. It is a
*pointer-map*: it names where things live and who holds them — it **never contains a secret**
(no keys, tokens, passwords, connection strings; pointers to their storage only).

Conventions: `TODO(<owner>): …` marks a fact only that person can fill — leaving one is
correct (a named gap beats a silent one). Scaffolded/updated by `/continuity`; keep rows
current when jobs are added or retired, and re-run `/continuity review` on a lifecycle change.

## 1. Recurring obligations (the things that rot if nobody runs them)

One row per scheduled/recurring job. Framed deps→outs: what a job **Needs** to run, and what
**Goes stale** when it stops — staleness is usually silent, so **Detection** (how a missed run
is noticed) is the load-bearing column.

| Obligation | Cadence / window | Runs where (host + scheduler) | Needs (deps) | Goes stale if it stops (outs) | Detection | Owner |
|---|---|---|---|---|---|---|
| <job name / unit> | <e.g. daily ~06:00> | <host + systemd timer / cron / CI schedule> | <inputs: creds, upstream data, env> | <the dashboards/tables/artifacts that silently rot> | <sentinel script / alert / TODO(owner): how is a miss noticed?> | <person> |

## 2. Access and secrets (single points of failure) — POINTERS ONLY

Where credentials/tokens live and who can act — never the values themselves.

- **<credential/token>:** lives in `<path/manager/vault — a pointer>`; held by `<person>`.
  Setup/rotation recipe: `<doc pointer>`.
- **<privileged account/role>:** what only it can do; who else can assume it.
- **Escalation:** `TODO(<owner>): who is the backup contact for an incident, and how are they
  reached?`

## 3. The "trusted-for-now" source budget

Inherited sources of truth that are relied on but not continuously verified. Each carries a
re-verify cadence so trust has an expiry date instead of drifting into assumption.

| Inherited source | Re-verify cadence | Last verified | Owner |
|---|---|---|---|
| <upstream table / API / vendor feed / doc> | <quarterly / on error / automated-by-sentinel> | <date or TODO(owner)> | <person> |

## 4. Meta-layer maintenance budget

The workspace's own upkeep obligations (docs, memory, tracking) — small, scheduled, easy to skip:

- **`CLAUDE.md` / instruction files:** soft size cap; when tripped, *move* content out
  (to `docs/memory/` via `/memory-adopt`'s boundary test), never keep appending.
- **`docs/memory/`:** run `/memory-lint` when the index grows or links feel stale (the
  deterministic pass runs in `--check` form; the librarian pass is on demand).
- **Tracking ledgers:** periodically scan the `merge=union` files for duplicate lines from a
  bad union resolution (`conventions/project-tracking.md` § Concurrency).
- **Skills/hooks audit:** `TODO(<owner>): set a cadence to ask "which skill/hook earned its
  keep?" and retire the rest.`

## 5. Proving it doesn't freeze (the bus-factor test)

The runbook is verified, not assumed: pick one obligation, have someone who is **not** the
owner follow this doc alone to (a) confirm the job ran on schedule, (b) simulate a miss and
detect it via the Detection column, (c) restart it. Record the result and what the doc was
missing:

- Last test: `TODO(<owner>): date, who ran it, which obligation, what gaps were found`
