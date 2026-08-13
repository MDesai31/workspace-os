---
name: project-log
description: Log a project action item, decision, or mark one done, in the repo's project tracking. Use whenever a decision (a choice + why), an action to do, or a completed item arises - proactively, not only when asked. Accumulate candidates and propose them as a batch at a natural stopping point rather than interrupting mid-task. The general-purpose tracking entry point.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[action|decision|model-decision|done] <workstream> <details>   (e.g. action data/pipeline \"fix the X gap\")"
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

### Quick-add (no mode keyword)
Infer from the wording: "should/decided/use X instead" → decision; model/experiment vocabulary
("champion/challenger", "promoted the model", "chose <architecture>", "validated with
walk-forward", a run ID) → model-decision; "fix/add/remove/implement" → action; an `A-id` +
"done/close/finished" → done. If ambiguous, ask.

## After writing
Show the user the exact record you added (or moved) and which file it's in. Do **not** commit
unless asked — leave it staged-ready.
