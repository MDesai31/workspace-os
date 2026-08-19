# Memory provenance fields — `verified-against` + `applies-to`

**Date:** 2026-08-19
**Status:** approved
**Decision:** D-20260819-memory-provenance-fields (to be logged)
**Ideas:** memory-volatility-field, memory-applies-to-field (both closed by this slice)

## 1. What and why

Two optional, additive fields on the memory fact frontmatter. Absent, behaviour is exactly what it
is today; no existing fact needs editing.

**`verified-against: <sha> <date>`** closes a gap the citation lint cannot reach. `--check-citations`
(v0.17.0) answers *"is this citation structurally valid right now?"* — it resolves the cited path
under `--src-root` and checks the symbol's definition block against the live filesystem. It is blind
to a different failure: a citation can resolve perfectly while the function it points at has been
rewritten underneath, so the fact's **claim** is wrong even though its **anchor** is fine. Recording
the sha a fact was last confirmed against turns "should I re-verify this?" from a judgment into a
computation: did the cited files change between that sha and HEAD.

**`applies-to: branch:<name> | repo:<name>`** scopes the rare genuinely branch-specific or
repo-specific fact via frontmatter rather than a directory. The use-audit feedback (2026-08-12)
found that naming the split *inside* a shared file already works well
(`scheduling-checkout-roles-original-vs-uat.md` does this and reads better than two divergent
copies). This field covers the residue at a fraction of the cost of a per-branch directory, and
keeps ONE index.

## 2. Rejected: a `volatility` enum

The `memory-volatility-field` idea offered a fork: a categorical `volatility: stable | measured |
pinned`, or the concrete `verified-against` line, or both. **The enum is rejected.**

It is hand-maintained metadata that no tool can validate, which is the exact shape of the `Priority:`
field that went stale on four shipped ideas and made `/project-status` over-report the high tier
(cleaned up in PR #25, cause fixed in PR #26). Adding a second unvalidatable field would reintroduce
the failure mode we just removed, and it would drift *silently*, because staleness is invisible by
definition.

The counter-argument, recorded because it is real: not every fact cites code, so `verified-against`
says nothing about durable domain knowledge with no sha to anchor to. The answer is that **absence
already carries that meaning.** A fact with no `verified-against` is one nobody anchored to code,
which is the same population the enum would have labelled `stable`. The signal survives without a
field to maintain.

## 3. Schema

Appended to the fact frontmatter in `conventions/memory.md` § Fact schema:

```
---
name: <kebab-slug>
description: <one-line summary>
type: domain | convention | reference
verified-against: <sha> <YYYY-MM-DD>     # optional
applies-to: branch:<name> | repo:<name>  # optional
---
```

- **`verified-against`** — a 7-to-40 character hex sha, one space, an ISO date. The sha is the
  **source repo being cited**, NOT the memory repo. In sidecar mode these are different git repos:
  facts live in `<workspace_root>`, the cited code lives in the target repo. Stating this in the
  schema is load-bearing; without it people will record the memory repo's sha, which is meaningless.
- **`applies-to`** — an explicit `branch:` or `repo:` prefix. The idea record's shorthand
  (`applies-to: <branch|repo>`) is ambiguous: given a bare `main`, nothing distinguishes a branch
  named `main` from a repo named `main`. The prefix removes the ambiguity. **Absent = applies to the
  whole repo, all branches**, which is the overwhelming majority of facts.

Both are optional. Neither is a fail gate. Neither changes `MEMORY.md`; the index format is
untouched.

## 4. What consumes them

### 4.1 `verified-against` → a fourth citation bucket

`check_citations()` gains **UNVERIFIED-SINCE**, advisory, alongside the existing STALE (fatal),
UNRESOLVABLE (advisory) and UNANCHORED (advisory).

For each fact carrying the field, with cited paths already resolved by the existing pass:

```
git -C <src_root> diff --name-only <sha>..HEAD -- <resolved cited paths>
```

Any output means the cited code moved since verification → UNVERIFIED-SINCE. This folds into
`--check-citations` rather than becoming its own mode: it is the same input, the same file walk, and
the same per-fact loop, and `/memory-lint` already wires that flag so it arrives with no new
plumbing.

**Batch by distinct sha, one `git diff` per sha, and intersect in Python** — do not shell out per
fact. After a bulk `/ingest` session most facts share a sha, so the per-fact form would run the same
diff dozens of times.

**Advisory, never fatal.** A changed file does not prove the claim is wrong, only that nobody has
confirmed it since. It must not affect the exit code, or a single upstream commit would turn every
base's lint red.

### 4.2 Graceful degradation (required)

`--check-citations` needs no git today. Folding this in must not change that. Each of the following
reports the fact as **unverifiable** in a one-line note, never as an error and never as a failure:

- `src_root` is not a git repository, or `git` is not on PATH
- the recorded sha is not an object in that repo (shallow clone, wrong repo, rewritten history)
- the field is malformed (bad sha shape, missing or unparseable date)

### 4.3 `applies-to` → reported, not gated

`memory_graph.py` parses it and surfaces it in the report (a scoped-facts line, and in
`--search`/`--backlinks` output where a fact carries it). No gate, no fail condition, no index
change. The value of the field is that a human reading a fact knows its scope; lint support is
presentation only.

## 5. Write path

`/ingest` stamps `verified-against` when **both**: the fact it is about to write carries a `path:NNN`
or `` `path::symbol` `` citation, AND `src_root` resolves to a git repo. The value is
`git rev-parse --short HEAD` plus today's date. It appears in `/ingest`'s batch proposal like any
other field, so it is visible and editable before write. Note `/ingest` has a pre-confirmed
batch-write path (the capture-cadence flow) where confirmation is a final check rather than a full
review; the stamp rides along there too, which is acceptable because the value is mechanical (HEAD
and today) rather than a judgment.

`applies-to` is never auto-stamped. It is authored deliberately or not at all.

**Out of scope for this slice:** a `/memory-lint` re-stamp flow ("this fact is UNVERIFIED-SINCE, and
you have now re-read it, update the sha"). It is the obvious follow-up and should be logged as an
idea, not built here.

## 6. Files touched

- `conventions/memory.md` — § Fact schema gains both fields; the sidecar sha note.
- `templates/memory/README.md` — the **vendor-neutral operator's manual**, which is the canonical
  statement of this schema and must stay consistent with the convention file. Existing stamped bases
  pick the update up via `/make-portable refresh` (v0.20.0).
- `scripts/memory_graph.py` — two frontmatter regexes, the UNVERIFIED-SINCE bucket in
  `check_citations()` + `print_citations()`, `applies-to` in the report. Note the existing
  frontmatter regexes scan `text[:400]`; confirm two extra lines cannot push `name:`/`description:`
  out of that window, and widen the slice if they can.
- `skills/ingest/SKILL.md` — the stamping rule.
- `skills/memory-lint/SKILL.md` — describe the new bucket.
- `tests/test-memory-graph.sh` + fixtures.

## 7. SoT boundary

`conventions/memory.md` is the plugin-internal source; `templates/memory/README.md` is the portable
statement. **Both must be updated in the same change** — they are the one place this repo has a
genuine duplication, and it is deliberate (a stamped base must be self-describing without the
plugin). No new conventions file.

## 8. Ship shape

- Plugin version 0.20.0 → 0.21.0.
- Tracking: `D-20260819-memory-provenance-fields` (decision, records the rejected enum),
  `A-20260819-memory-provenance-fields` (action → resolved at close-out). Both ideas
  `memory-volatility-field` and `memory-applies-to-field` are closed by this slice and graduate out
  of `ideas.md` per `conventions/project-tracking.md` § Lifecycle (the completion exit added in #26),
  taking their inbound wikilinks with them.
- Branch + PR, matching recent practice.

## 9. Success criteria

- (a) `validate-plugin.py` green; `memory_graph.py --check` clean on this repo.
- (b) A fixture fact with `verified-against` pointing at a sha **before** a change to its cited file
  reports UNVERIFIED-SINCE; the same fact stamped at HEAD does not.
- (c) UNVERIFIED-SINCE never changes the exit code: a base with one is still `--check-citations`
  clean as far as CI is concerned.
- (d) All three degradation paths (non-git src_root, unknown sha, malformed field) report
  unverifiable and exit 0.
- (e) A fact with neither field behaves byte-identically to today — existing fixtures unchanged and
  still passing.
- (f) `applies-to` appears in the report and gates nothing.
- (g) The schema in `conventions/memory.md` and `templates/memory/README.md` matches, verified by a
  test or an explicit diff check.

## 10. Non-goals

- The `volatility` enum (§2).
- A `/memory-lint` re-stamp flow (§5) — log as an idea.
- Any change to `MEMORY.md`, the index format, or retrieval.
- Any migration of existing facts. Both fields are optional; a base with none behaves as today.
