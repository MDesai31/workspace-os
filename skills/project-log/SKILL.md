---
name: project-log
description: Log a project action item, decision, discovery, finding (an open question that closes on evidence), or meeting, mark an item done, close a finding with a verdict, or cut release notes, in the repo's project tracking. Use whenever a decision (a choice + why), an action to do, an investigation finding, an open question, or a completed item arises - proactively, not only when asked. Accumulate candidates and propose them as a batch at a natural stopping point rather than interrupting mid-task. The general-purpose tracking entry point.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[action|decision|model-decision|done|propagated|discovery|finding|verdict|meeting|release-notes] <args>"
---

# Project Log

Append typed records to this repo's `<data_root>/project-tracking/` (`docs/project-tracking/` in
in-repo mode). All record formats, the ID rule, and the lifecycle live in this plugin's
`conventions/project-tracking.md` — read it and follow it exactly; do not restate the rules here.

**Prerequisite:** the repo must already have `<data_root>/project-tracking/` (run
`/project-init` if not). If it's missing, stop and say so.

**Workstream validation:** the tag must be one listed under `## Workstreams` in
`<data_root>/project-tracking/README.md`. If the given tag isn't there, list the valid ones and
ask.

## Step 0

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in BOTH modes; never
   hardcode `docs/…`. Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).

## Modes

### `action <workstream> <details>`
Mint `A-<today>-<slug>` (today = `date +%Y%m%d`; slug = short kebab of the title). Append the
**action template** to `action-items.md` with status `open`. Replace the
"_No open items yet._" placeholder if it's still there.

### `decision <workstream> <details>`
Mint `D-<today>-<slug>`. If the user didn't give a rationale, ask for one. Append the
**decision template** to `decisions-log.md` (append-only) with `Status: accepted`; include the
`Consequences:` line only when there are follow-on effects worth recording, and drop the
`Supersedes:` line entirely when nothing is being replaced. If the decision implies new work, ask
whether to also create linked action item(s) and, if yes, run `action` mode for each and fill the
decision's `Spawns:` line with their IDs.

**Supersession:** if the decision reverses or replaces a prior one (the user names an old `D-` id,
or says "instead of / reversing / supersedes …" — confirm the target id if inferred), fill
`Supersedes: [[supersedes::D-old-id]]` in the new record AND append exactly one line to the old
record's list: `- Superseded-by: [[superseded_by::D-new-id]]`. That appended line is the **only**
permitted change to an existing decision record — never edit its `Status:` or any other line
(the read rule lives in the conventions doc).

### `model-decision <workstream> <details>`
A DS/ML decision (architecture choice, feature set, validation protocol, champion/challenger
call). Mint a normal `D-<today>-<slug>` and append the **model-decision template variant** to
`decisions-log.md` — same file, same append-only + supersession rules as `decision` mode. Fill
the typed fields from what the user gives; ask only for the ones that guard against future
confusion: `Dataset` (vintage/cutoff), `Validation` (protocol + leakage guards), and `Run` (the
MLflow/W&B run ID or URL; if the repo has no tracker, offer the ledger fallback — a
`<data_root>/models/<model-name>.md` (`docs/models/<model-name>.md` in in-repo mode) from
`templates/MODEL_LOG.md`, per the conventions' "run layer"
section — and point `Run:` at its row). **Never copy a metrics table into the record** — one
headline number, the run pointer owns the rest. If this is a champion promotion, apply the supersession protocol
against the old champion's record (`Outcome: challenger-promoted` + `Supersedes:` + the one
appended `Superseded-by:` line).

### `done <A-id> [commit]`
Complete an action:
1. Find the `<A-id>` record in `action-items.md`.
2. Append to its body:
   ```
   - Completed: <today>
   - Commit: <commit arg, or the current HEAD short sha if available, else "n/a">
   ```
3. **Remove the whole record from `action-items.md`** and **append it to `resolved.md`**.
   (If removing it leaves `action-items.md` with no records, restore the "_No open items yet._"
   placeholder.)
4. **Handoff check** (`conventions/project-tracking.md` § "Session continuity"): look in
   `<data_root>/project-tracking/handoffs/` for a file whose `Records:` line names this
   `<A-id>` (fallback: slug match against the record title). If found, propose deleting it;
   on confirmation delete the file and append `- Handoff: <slug> (closed)` to the record
   being moved. Never delete unconfirmed.

### `propagated <A-id> <folder> [sha]`
Record that a change landed in another checkout of this project
(`conventions/project-tracking.md` § "Propagation across checkouts"). Sidecar workspaces
only — `mode=in-repo` → say propagation applies to marked workspaces only, and stop.

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/checkout-groups.sh" "<workspace_root>"` and
   group its lines by `key=`.
2. Locate `<A-id>` in `action-items.md`, then `resolved.md`, under
   `<workspace_root>/<f>/project-tracking/` for EVERY folder `<f>` in the grouped projects
   — the record may live in a sibling checkout's root. Not found → list the locations
   searched and stop (a write tool should not guess).
3. `<folder>` must be in the record's project group; otherwise list the valid folders and
   stop.
4. If the record has no `- Propagation:` line, propose one (default `all`) and append it on
   confirmation before anything else.
5. Append `- Propagated-to: <folder> <today YYYY-MM-DD> [sha]` to the record's body —
   unless a `Propagated-to:` line for that folder already exists (then say so and write
   nothing). Sidecar auto-commit applies (Step 0).

### `discovery <details>`
An investigation finding — lighter than a decision. Route before writing
(`conventions/project-tracking.md` § "Session continuity"):

1. **Durable fact about the codebase** (would survive this effort) → this is memory, not
   tracking: hand off to `/ingest` and write nothing here. Never duplicate into both.
2. **Work-state finding** → append the dated discovery entry (the conventions' shape) to
   `<data_root>/project-tracking/work-log.md`; create the file with a `# Work log` header
   on first use.
3. Then ask: does this change anything? Offer to chain into `decision` or `action` mode.

### `meeting <date and/or notes>`
Structured meeting capture (`conventions/project-tracking.md` § "Meetings"):

1. Parse date (default today; convert relative dates), topic slug, attendees, and content.
2. Write `<data_root>/project-tracking/meetings/YYYY-MM-DD-<slug>.md`: attendees, narrative
   notes, open questions.
3. Extract each decision/action the meeting raised as a real record via `decision` /
   `action` mode (the ledgers stay SoT); the record body names the meeting file, and the
   meeting file lists the extracted ids at its top.
4. Show the meeting file and the extracted records for review.

### `finding <details>`
A question or finding that closes on **evidence**, not work
(`conventions/project-tracking.md` § the Finding template — read the boundary rules there).
Mint `F-<today>-<slug>`; phrase the title as a question. Ask for `Awaiting:` (who/what owes
the evidence) and `Closes-on:` (what settles it) if not inferable. Append to `findings.md`,
replacing the `_No open findings yet._` placeholder if present.

### `verdict <F-id> <verdict> <evidence>`
Close a finding — nothing was done, something was learned. Locate `<F-id>` in `findings.md`
(missing → say so, stop). `<verdict>` must be one of the conventions' enum
(`bug|behavior|latent|answered|moot`); ask for the evidence line if not given. Append
`- Verdict:`, `- Evidence:`, `- Completed: <today>` and move the record to `resolved.md`.
Then chain by verdict: `bug` → offer `action` mode (fill `Spawns:`); `latent` → offer
`/project-plan`; `behavior` worth keeping long-term → offer `/ingest` (record stays as
provenance, linked, never duplicated).

### `release-notes [since:<ref|date>] [audience:team|leadership]`
Git history + the decisions log → notes people will read
(`conventions/project-tracking.md` § "Release notes"). **Never invent a change** — every
line traces to a real commit or `D-` record; read `git show <sha> --stat` before describing
a cryptic subject.

1. Window: `since:` if given, else since the last tag (`git describe --tags --abbrev=0`),
   else the last ~20 commits.
2. Group commits by theme/version markers (`v\d+\.\d+`) — grouping and translation are the
   value, never one line per commit. Map `D-` records created in the window to the groups
   they explain.
3. Audience `team` (default): concise, technical-but-readable. `leadership`: outcomes and
   impact, no code/file jargon.
4. Render: a dated window header, `Highlights` (2-4 lines), grouped changes citing `D-` ids,
   `Still open` (work explicitly flagged pending). Propose it; on confirmation prepend under
   a new dated heading (newest first) to `RELEASES.md` — repo root in in-repo mode,
   `<data_root>/RELEASES.md` in sidecar (never the repo tree). Sidecar auto-commit (Step 0).

### Quick-add (no mode keyword)
Infer from the wording: "should/decided/use X instead" → decision; model/experiment vocabulary
("champion/challenger", "promoted the model", "chose <architecture>", "validated with
walk-forward", a run ID) → model-decision; "fix/add/remove/implement" → action; an `A-id` +
"done/close/finished" → done; "found/noticed/turns out/discovered" → discovery; "is this a
bug or intended", "need to confirm", "waiting on <someone> to verify", "open question" →
finding; an `F-id` + an outcome → verdict; structured meeting sections (attendees, agenda,
action items) → meeting. If ambiguous, ask.

## After writing
Show the user the exact record you added (or moved) and which file it's in. Do **not** commit
unless asked — leave it staged-ready.
