# Project-Tracking Conventions

The single source of truth for the `workspace-os` tracking skills. `/project-log`,
`/project-plan`, and `/project-init` all follow these rules — they do not restate them.

## Data files (per target repo)

Created by `/project-init` under `<repo>/docs/project-tracking/`:

| File | Holds | Written by |
|---|---|---|
| `action-items.md` | open action records | `/project-log action` |
| `resolved.md` | completed records (archived on done) | `/project-log done` |
| `decisions-log.md` | decision records (append-only) | `/project-log decision` |
| `ideas.md` | future intents | `/project-plan` |
| `README.md` | index + the repo's workstream list | manual / `/project-init` |

## IDs

- Actions: `A-YYYYMMDD-slug`. Decisions: `D-YYYYMMDD-slug`.
- `YYYYMMDD` is the creation date; `slug` is a short kebab-case descriptor.
- **Assigned once at creation, never renumbered.** Collision-proof across parallel branches
  with no coordination.
- Pre-existing `#`/letter IDs in a repo (e.g. `#21`, item `K`) are **legacy** — grandfathered,
  referenced as-is, never rewritten. Only new entries use date-slug IDs.

## Workstreams

A small per-repo enum (the cross-cutting axis). The allowed tags live in the repo's
`docs/project-tracking/README.md` under `## Workstreams`, seeded by `/project-init`. Every
record is tagged with exactly one. (Example for a data project: `data/pipeline · strategy · ML · risk · ops`.)

## Record templates

**Action** — appended to `action-items.md`, status `open`:
```
### A-YYYYMMDD-slug — <title>
- Workstream: <tag>
- Status: open
- Created: YYYY-MM-DD

<body: the detail>
```

**Decision** — appended to `decisions-log.md` (append-only, never edited after the fact):
```
### D-YYYYMMDD-slug — <title>
- Workstream: <tag>
- Created: YYYY-MM-DD
- Rationale: <why this choice>
- Spawns: <linked A-IDs, or "none">

<body: optional detail>
```

**Idea** — appended to `ideas.md`:
```
### <name> — <one-line>
- Workstream: <tag>
- Priority: high | mid | low | someday
- Intended start: <verbatim; fuzzy is fine — "Q3", "after X", "someday">
- Why/context: <the reasoning to preserve>
- To start, future-us needs: <key files / the open question / the dependency to clear>
```

## Lifecycle

- `/project-log action` → record lands `open` in `action-items.md`.
- `/project-log done A-…` → append these two lines to the record's body, then **move the whole
  record out of `action-items.md` and append it to `resolved.md`** (keeps the open list lean):
  ```
  - Completed: YYYY-MM-DD
  - Commit: <sha or PR#>
  ```
- `/project-log decision` → record appended to `decisions-log.md`. Append-only.
- `/project-plan` → idea appended to `ideas.md`. When an idea goes active, it graduates to an
  action in `action-items.md` (and can be removed from `ideas.md`).

## Concurrency

`action-items.md`, `decisions-log.md`, `resolved.md`, and `ideas.md` are append-heavy and
declared `merge=union` in the target repo's `.gitattributes`, so concurrent appends from
different branches/PRs auto-merge instead of conflicting. (Periodically scan for duplicate
lines from a bad union resolution.)
