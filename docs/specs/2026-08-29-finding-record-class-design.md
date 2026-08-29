# Finding record class (F- records) — design

Date: 2026-08-29. Status: approved 2026-08-29. Closes the finding-record-class idea
(EC2 audit 2026-08-24).

## Problem

Investigations produce questions that close on **evidence arriving**, not on work finishing:
"is this a bug or intended behavior?", "does the vendor job really run at 02:00?", "waiting
on the team to confirm X". The schema's two shapes both misrepresent them — an `A-` record
implies work *you* will do; a `D-` record implies a choice *you* made. The measured symptom:
the UDX workspace grew a hand-maintained parallel register
(`_meta/pending-tracking/open-questions.md`) with its own verdict legend
(BUG / BEHAVIOR / LATENT / RESOLVED / TEAM) and a migration banner of items being hand-copied
into action records. A taxonomy the schema lacks always becomes a file the schema doesn't own.

## Design

### The record

`F-YYYYMMDD-slug`, living in a new `findings.md` (a queue, like `action-items.md` — the UDX
register proves the demand for a separate open-questions view):

    ### F-20260829-vendor-job-timing — does the vendor job actually run at 02:00 UTC?
    - Workstream: <tag>
    - Status: open
    - Created: 2026-08-29
    - Awaiting: <who/what owes the evidence: me | <person/role> | <event, e.g. "next 02:00 run">>
    - Closes-on: <what evidence settles it, one line>

    <1-5 lines: what was observed, why it matters, what it might change>

On close, two lines are added and the record moves to `resolved.md` (one archive;
`/work-journal` and `/project-status` cross-referencing keep working):

    - Verdict: bug | behavior | latent | answered | moot
    - Evidence: <what arrived, one line — a sha, a log line, "confirmed by <role> <date>">
    - Completed: YYYY-MM-DD

### The verdict enum (adapted from the UDX legend)

- `bug` — a defect confirmed; almost always `Spawns:` an `A-` record (the work is the
  action's, not the finding's).
- `behavior` — works as designed; no work, the record IS the documentation.
- `latent` — real but not currently biting; typically `Spawns:` an idea via `/project-plan`.
- `answered` — the generic "question settled" for non-defect questions.
- `moot` — overtaken by events; say what made it moot in Evidence.

UDX's TEAM is deliberately **not a verdict** — "waiting on the team" is ownership, which is
the `Awaiting:` field while open. A verdict says what the evidence showed; `Awaiting:` says
who owes it.

### Skill wiring

- **`/project-log finding <details>`** — open one (mints the F- id; asks for `Awaiting:` and
  `Closes-on:` if not inferable). Quick-add inference: "is this a bug or intended", "need to
  confirm", "waiting on <person> to verify", "open question".
- **`/project-log verdict <F-id> <verdict> <evidence>`** — close one (the closing verb is
  `verdict`, not `done`: nothing was *done*, something was *learned*). Moves the record to
  `resolved.md`; a `bug` verdict offers to chain into `action` mode and fill `Spawns:`.
- **`/project-status`** — an "Open findings" section (id — title — Awaiting — age) in report
  mode; brief mode lists stale findings (open >14 days) under their tier.
- **capture-cadence** — one nudge line: "an open question that closes on evidence ->
  /project-log finding".
- **`/project-init`** — stamps `findings.md` (new template, placeholder line).
- **`/tracking-adopt`** — routes open-question sections (verdict-legend keywords, "Open
  questions" headers, "waiting on X to confirm" items) to F- records; closed legend items
  with a verdict go to `resolved.md` as closed findings. This is the migration path for the
  UDX register (the adoption run itself happens on that machine).

### Deterministic layer

`memory_graph.py` learns the `F-` id shape wherever it harvests `A-`/`D-` today, so facts
can wikilink findings and `--check-tracking` covers `findings.md` (the 40-line boundary
applies to findings too). House-style test extension covers: F- link resolution + a
findings.md record over the boundary. This is the slice's only code change.

## Boundary rules

- A finding is a **question with an owner and a close condition** — not a discovery
  (`/project-log discovery` = a logged observation, no lifecycle), not an action (work you
  own), not an idea (intent, no evidence pending).
- Distinct from memory: a `behavior` verdict worth keeping long-term graduates to a
  `docs/memory/` fact via `/ingest` (the record stays as provenance; content not duplicated
  — link the fact).

## Non-goals

- No SLA/reminder machinery (staleness surfaces read-only in `/project-status brief`).
- No F- records in the propagation matrix (findings are per-repo questions, not landings).
- The UDX register's actual adoption — usage on the EC2 machine, not plugin work.

## Verification

- memory_graph extension: red-then-green cases in the existing graph test for F- link
  resolution and findings boundary check; full suite + validator green.
- Conventions stay SoT (template + § in project-tracking.md); skills point, never restate.
- Doc-freshness gate covers README/GUIDE mentions.

## Version

v0.32.0. Files touched: conventions/project-tracking.md, templates/findings.md,
skills/{project-log,project-status,project-init,tracking-adopt}/SKILL.md,
hooks/capture-cadence.sh (one line), scripts/memory_graph.py (+ its test), README, GUIDE.
