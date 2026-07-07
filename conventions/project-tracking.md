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
- Status: accepted
- Rationale: <why this choice>
- Supersedes: [[supersedes::D-old-id]]     ← only when replacing/reversing a prior decision
- Consequences: <follow-on effects worth recording — optional line>
- Spawns: <linked A-IDs, or "none">

<body: optional detail>
```

### Decision status & supersession (append-only)

- `Status:` is written **once, at creation**, always `accepted`. It is never edited afterwards.
- To reverse or replace a decision, log a **new** decision whose `Supersedes:` line carries a
  typed wikilink — `[[supersedes::D-old-id]]` — then append exactly **one** line to the old
  record's list:
  ```
  - Superseded-by: [[superseded_by::D-new-id]]
  ```
  That appended line IS the superseded marker. **Read rule: a `Superseded-by:` line wins over
  the `Status:` line**; a record with neither (pre-schema records are grandfathered) reads as
  accepted. This keeps the log append-only — no line is ever rewritten.
- The typed-link predicates are the **same vocabulary** as memory's typed wikilinks
  (`conventions/memory.md`): `supersedes`/`superseded_by` here; don't invent tracking-only
  predicates. `[[wikilink]]` targets may be `D-`/`A-` IDs or memory fact slugs;
  `scripts/memory_graph.py` resolves `D-`/`A-` targets when linting `docs/memory/` (links
  *inside* tracking files are not machine-linted — the read rule above is the human contract).

**Model decision** — a decision-template *variant* for DS/ML choices (architecture, features,
validation protocol, champion/challenger). Same `D-` ID, same `decisions-log.md` home, same
status/supersession rules — plus typed fields. Written by `/project-log model-decision`:
```
### D-YYYYMMDD-slug — <title>
- Workstream: <tag>
- Created: YYYY-MM-DD
- Status: accepted
- Model: <model/experiment name>
- Dataset: <data + vintage/cutoff — the version trained against, not a path to secrets>
- Architecture: <choice, vs <alternatives considered>>
- Validation: <protocol — split/CV/walk-forward + the leakage guards applied>
- Headline metric: <ONE number with its metric name — the full table lives at the run pointer>
- Run: <MLflow/W&B run ID or URL; or, with no tracker, a MODEL_LOG.md row ref — the run layer owns the metrics; never re-log them here>
- Outcome: champion | challenger-rejected | challenger-promoted
- Rationale: <why this choice — the reasoning the run platform cannot hold>
- Supersedes: [[supersedes::D-old-champion]]     ← on promotion: the new champion supersedes the old
- Spawns: <linked A-IDs, or "none">

<body: optional detail — a pointer plus the one headline number, never a metrics dump.>
```
**Champion/challenger lifecycle = the supersession protocol:** promoting a challenger mints a
new model-decision record with `Outcome: challenger-promoted` and
`Supersedes: [[supersedes::D-old]]`, and the old champion's record gets its one appended
`- Superseded-by:` line. The decisions log thereby holds the model lineage for free.

**The run layer (tracker-first, ledger fallback):** per-build hyperparameters and metrics are
*run-level* data — an experiment tracker's job (MLflow/W&B/SageMaker), not this log's. When no
tracker is available, the fallback is an in-repo build ledger: copy `templates/MODEL_LOG.md` to
`docs/models/<model-name>.md` (one file per model, append-only, `merge=union`). Git already
records what changed — configs/hyperparameters live in the diff between build shas — so a ledger
row records only the association: *sha → headline metrics → verdict*, one row per **evaluated
candidate** (a build you'd want to find again), never per debug run. Either way the decision
record's `Run:` field points at the run layer (tracker run ID/URL, or a `MODEL_LOG.md` row);
decisions-log.md stays the reasoning layer on top and never duplicates run data.

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
- `/project-log decision` → record appended to `decisions-log.md`. Append-only. When it
  supersedes a prior decision, the old record also gets its one `Superseded-by:` line appended
  (see "Decision status & supersession").
- `/project-plan` → idea appended to `ideas.md`. When an idea goes active, it graduates to an
  action in `action-items.md` (and can be removed from `ideas.md`).

## Adopting existing docs (`/tracking-adopt`)

`/tracking-adopt` bulk-applies these record rules to a repo's pre-existing **work-state** docs
(opt-in; the passive default never auto-touches them). It is the tracking-side sibling of
`/memory-adopt`: where `/memory-adopt` extracts durable knowledge and skips work-state,
`/tracking-adopt` claims that work-state. Candidate sources: `README*`, `docs/**/*.md`, `NOTES*`,
`CLAUDE.md`, `TODO*`/`TODOS*`, `CHANGELOG*`/`RELEASES*` — excluding `docs/project-tracking/` (never
re-adopt itself) and `docs/memory/`. Detect tracking-content by section headers (Roadmap, Future,
Post-MVP, Out-of-scope, Backlog, TODO, Key decisions) and checkbox lists (`- [ ]`/`- [x]`). Route
each chunk:

- roadmap / future / post-MVP / someday / out-of-scope → an **idea** in `ideas.md` (Intended-start
  copied verbatim; map obvious priority language, else `mid`);
- explicit decision (a "Key decisions" item, "Supersedes…", "chose X because Y") → a **`D-` record**
  in `decisions-log.md` (the body `[[wikilink]]`s the source doc);
- open TODO / unchecked `- [ ]` / "next up" → an **`A-` record** in `action-items.md`, status `open`;
- completed / checked `- [x]` / changelog "done" → **skip for now** (belongs in `resolved.md`, which
  needs a real commit ref — adopted via git history in a later slice, not from prose);
- durable knowledge / imperative / about-the-person → **out of lane, skip** (knowledge is
  `/memory-adopt`'s job).

**IDs:** new records use date-slug IDs; pre-existing `#`/letter IDs in source docs are legacy —
grandfathered, never rewritten (see IDs above). **Workstreams:** tag against the repo's
`## Workstreams` list; when bootstrapping a repo that has none, propose an inferred set from the
scanned docs for confirmation. **Source docs are read-only** — never modified (not even `CLAUDE.md`).
**Idempotent:** before proposing, skip any record whose slug or content is already in tracking.
**Never write secrets.** Apply only on explicit confirmation.

## Concurrency

`action-items.md`, `decisions-log.md`, `resolved.md`, and `ideas.md` are append-heavy and
declared `merge=union` in the target repo's `.gitattributes`, so concurrent appends from
different branches/PRs auto-merge instead of conflicting. (Periodically scan for duplicate
lines from a bad union resolution.)
