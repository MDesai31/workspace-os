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

## The memory/tracking boundary

A tracking record says **what to do** (or what was decided); memory (`docs/memory/`) says **what is
true**. A record body should stay lean - the goal, the status, the decision, and a `[[wikilink]]` to
the durable facts - not a growing dump of measured evidence.

- **Measured evidence belongs in a memory fact, not a record body.** A block of pinned numbers
  (benchmark results, row counts, profiling output) is durable knowledge: put it in `docs/memory/`
  and `[[wikilink]]` it from the record. Do not embed a `**MEASURED**` evidence block in an `A-`/`D-`
  body.
- **Keep bodies short.** As a guideline a record body stays under ~40 lines; past that, the detail
  has usually become knowledge that wants a memory fact.

`memory_graph.py --check-tracking` (the `/memory-lint` boundary gate) flags records that exceed the
line ceiling (`--max-record-lines`, default 40) or carry a `**MEASURED**` block.

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
- `/project-plan` → idea appended to `ideas.md`. `ideas.md` is a **queue, not an archive**: an idea
  leaves it as soon as it stops being pending work, by one of two exits.
  - **Goes active** → graduates to an action in `action-items.md`, and is removed from `ideas.md`.
  - **Ships completely** → closed out in this order: (1) append a `Closes <idea>` line to the
    decision record that carries its reasoning, (2) ensure the `A-` record in `resolved.md` names
    the idea it closed, (3) remove the record from `ideas.md`, (4) repoint any `[[wikilinks]]` to
    it from surviving ideas into `<name> (shipped)` prose.

  A **partially** shipped idea stays put, carrying a Shipped line and naming the sub-slices that
  remain. Never leave a *fully* shipped idea in place: its `Priority:` line keeps counting toward
  the open backlog, so `/project-status` over-reports that tier.

## Session continuity: handoffs and the work log

Mid-task state lives in `<data_root>/project-tracking/handoffs/` — **one live file per
paused effort**, `handoffs/<effort-slug>.md` (slug: short kebab descriptor, stable across
re-pauses). A handoff is working state, not history: re-pausing **refreshes the same file**
(update `Paused:`, rewrite sections; never a second file for one effort), and completing the
work **deletes it** — `/project-log done` checks `handoffs/` for a file whose `Records:`
line names the A-id being closed (fallback: slug match against the record title) and, on
confirmation, deletes it and appends `- Handoff: <slug> (closed)` to the record moving to
`resolved.md`. Record shape: `templates/handoff.md` — header lines (`Paused:`, `Resume-by:`,
`Records:`, `Branch:`), a **For you** block (3–5 plain lines), then Mission / In flight /
At start, read / Traps / Next steps / Out of scope. **Calibrate to the task**: a small
continuation gets Mission + In flight + Next steps only; never ceremonialize trivia. Every
path or figure named in a handoff is verified against the live workspace before writing — a
handoff that transmits a stale path is worse than none. Handoff files name records by plain
id and are not part of the machine-linted graph (the tracking-wikilink human contract).
Written by `/handoff`; surfaced at SessionStart by `hooks/capture-cadence.sh`; listed by
`/project-status`.

Session accomplishments live in `<data_root>/project-tracking/work-log.md` (created on
first use, header `# Work log`), appended by `/work-journal log`, one dated entry per
session:

    ## YYYY-MM-DD - <session focus, one phrase>
    - <2-5 bullets of what was done>
    - Commits: <shas or "none">
    - Records: <A-/D- ids touched, or "none">

`/project-log discovery` appends investigation findings to the same file, one dated entry
per finding:

    ## YYYY-MM-DD - discovery: <one-line finding>
    - <1-3 bullets: what was found, where, what it might change>

A discovery is work-state. A finding that is a durable fact about the codebase (it would
survive this effort) belongs in memory via `/ingest`, not here — the memory/tracking
boundary above decides, and content is never duplicated across the two.

## Meetings

`/project-log meeting` captures a structured meeting as
`<data_root>/project-tracking/meetings/YYYY-MM-DD-<slug>.md` (date = the meeting's; slug =
short kebab topic): attendees, narrative notes, open questions. Decisions and actions raised
in the meeting are never recorded in the meeting file alone — each is extracted as a real
`D-`/`A-` record in the ledgers (same templates, same IDs), the record body naming the
meeting file and the meeting file listing the extracted ids at its top. The ledgers stay the
single source of truth; the meeting file holds the narrative they should not.

## Release notes

`/project-log release-notes` renders git history + the decisions log into grouped,
plain-English notes appended (newest first) to `RELEASES.md` — at the repo root in in-repo
mode; at `<data_root>/RELEASES.md` in sidecar mode (the repo tree is never touched). The
hard rule: **never invent a change** — every line traces to a real commit or `D-` record.

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
- completed / checked `- [x]` / changelog "done" → **docs-only mode: skip** (a resolved record
  needs a real commit ref, which prose cannot supply — run `/tracking-adopt git`); **git mode:
  cross-match** against the mined units (see "Git-history archaeology" below) — matched → enriches
  that unit's single record, unmatched → stays skipped and reported;
- durable knowledge / imperative / about-the-person → **out of lane, skip** (knowledge is
  `/memory-adopt`'s job).

**IDs:** new records use date-slug IDs; pre-existing `#`/letter IDs in source docs are legacy —
grandfathered, never rewritten (see IDs above). **Workstreams:** tag against the repo's
`## Workstreams` list; when bootstrapping a repo that has none, propose an inferred set from the
scanned docs for confirmation. **Source docs are read-only** — never modified (not even `CLAUDE.md`).
**Idempotent:** before proposing, skip any record whose slug or content is already in tracking.
**Never write secrets.** Apply only on explicit confirmation.

### Git-history archaeology (`/tracking-adopt git`)

The explicit `git` mode adds **git history** as a source and produces **`resolved.md` records
only** — the one record type prose cannot legitimize, because a resolved record needs a real
`Commit:` ref. One record per **merged unit**: a merge commit, a squash commit carrying a `(#N)`
PR marker in its subject, or a model-grouped run of related direct-to-main commits;
chore/typo/CI/formatting/version-bump noise is skipped, never recorded.

**Bound:** default = since the newest reachable tag if one exists, else the last ~30 merged
units; an explicit git range argument (`v1.0..HEAD`, `HEAD~50..`, `--all`) overrides. Over ~30
candidates → propose the newest ~30 and report how to continue with an explicit range.

**Record shape:** the action template plus `- Completed:` (merge date) and `- Commit:` (SHA, plus
`(PR #N)` when known); ID = `A-<merge-date>-slug` — dated by when the work **landed**, so imports
sort naturally and re-runs mint identical slugs; `Created:` = the PR open date when enrichment
supplies it, else the merge date; Status `done`; a 2–4 line body from the PR body / commit
messages ending `Imported from git history by /tracking-adopt git.`

**Enrichment is opportunistic:** with a GitHub remote and a working `gh`/GitHub MCP, fetch PR
title/body/open-date; on **any** failure (no remote, no auth, offline) degrade silently to commit
messages. Never required, never blocks.

**Dedup key: the SHA/PR#.** Skip any candidate whose SHA or PR number already appears in
`resolved.md` — covers prior imports *and* organic `/project-log done` records. Slug/content
match is secondary. Re-running the same range proposes nothing new.

**Out of scope (deliberate):** decision mining from commit/PR prose ("chose X because Y" → `D-`)
and open branches/stale issues → `action-items.md` — fuzzy and noisy; deferred, not implied.

## Propagation across checkouts (sidecar workspaces)

In a marked workspace, several checkout folders may be checkouts of ONE project — grouped
automatically by normalized `origin` URL (`scripts/checkout-groups.sh`; zero config), keyed
by folder basename like the sidecar data roots (`conventions/data-root.md`). Two optional,
**append-only** lines on **action** records (open or resolved) carry propagation state;
both are meaningless in in-repo mode, where checkouts share tracking files through git:

- `- Propagation: all | <folder>, <folder>` — written at most once; declares which of the
  project's checkouts need this change. `all` is dynamic: every checkout in the project's
  group **at read time**. Its presence is what makes a record matrix-relevant.
- `- Propagated-to: <folder> YYYY-MM-DD [sha-or-PR#]` — one line per landing, appended in
  landing order (the `Superseded-by:` pattern: append, never edit).

**Read rule:** covered = the record's home checkout (the folder whose data root holds the
record) once the record is done, plus every `Propagated-to:` folder; pending = target set
minus covered. A `Propagated-to:` folder outside the current group reads as unknown —
lenient, never an error (folders get renamed or removed). Written by
`/project-log propagated`; rendered by `/project-status matrix`. The body line-ceiling and
the memory/tracking boundary apply unchanged.

## Concurrency

`action-items.md`, `decisions-log.md`, `resolved.md`, and `ideas.md` are append-heavy and
declared `merge=union` in the target repo's `.gitattributes`, so concurrent appends from
different branches/PRs auto-merge instead of conflicting. (Periodically scan for duplicate
lines from a bad union resolution.)
