# `/ingest gotcha:` - stale-prior capture that routes to both homes - Design Spec

**Date:** 2026-07-27
**Status:** Approved design, ready for plan
**Idea:** `memory-backlinks-search` (the note-templates half; the first and only flavor is the
stale-prior/gotcha type from `stale-priors-memory`), `ideas.md`
**Relates to:** `skills/ingest/SKILL.md` (the skill this extends), `conventions/memory.md` (the
boundary test + fact schema this rides on), `scripts/resolve-data-root.sh` (in-repo vs sidecar
resolution), `D-20260626-repo-canonical-memory` (costly-first -> CLAUDE.md is the intended home),
`D-20260627-memory-adopt-claudemd-scope` (confirmed opt-in flows may write CLAUDE.md; only the
passive default never does)

---

## 1. Summary

Complete the "note-templates" half of `memory-backlinks-search` for its one named flavor: the
**stale-prior / gotcha** ("your training prior says X; in this repo it is actually Y"). Today
`/ingest` runs the boundary test and, when a fact is costly-if-unseen (belongs in CLAUDE.md),
simply tells the user and stops - it only ever writes `docs/memory/`. This slice teaches `/ingest`
to **route a gotcha to whichever home the boundary test picks**: a confirmed imperative bullet in a
managed CLAUDE.md section when costly-first, or a `docs/memory/` fact with a consistent gotcha body
shape when consult-when-relevant.

The write into CLAUDE.md is the substance. It is consistent with existing precedent
(`/memory-adopt` already writes a CLAUDE.md summary section and trims CLAUDE.md, both with
confirmation - `D-20260627-memory-adopt-*`), and with the routing the boundary rule already
mandates (`D-20260626`: costly-first -> CLAUDE.md). The mechanical, error-prone part (idempotent
insert into an always-loaded file) is isolated in a small tested helper script, not left to
model judgment.

**Deliberately narrow:** the CLAUDE.md-write path fires **only** for the explicit `gotcha:` trigger.
A normal `/ingest` fact behaves exactly as today (costly-first still tells-and-stops). This is the
surgical "stale-prior flow only" scope, not a general upgrade of `/ingest`.

## 2. Scope

**In:**
- `skills/ingest/SKILL.md` - a `gotcha:` branch: recognize the explicit trigger, run the existing
  boundary test, and route YES -> managed CLAUDE.md bullet (confirmed, in-repo only) / NO ->
  `docs/memory/` fact with the gotcha body shape. Non-gotcha `/ingest` is untouched.
- `scripts/claude-md-upsert.sh` (new) - a deterministic, idempotent helper that inserts one bullet
  into a named managed section of a given CLAUDE.md file.
- `tests/test-claude-md-upsert.sh` (new) - plain-bash coverage for the helper.
- `conventions/memory.md` - a new "Recurring flavors" subsection formalizing the stale-prior flavor
  and its two body shapes once, as the single source both the skill and a human author follow.
- Docs + tracking close-out: `plugin.json` version bump; `ideas.md` marks the note-templates half
  (gotcha flavor) shipped; `resolved.md` action record; `decisions-log.md` decision record.

**Out (YAGNI / deferred):**
- **General `/ingest` CLAUDE.md upgrade.** Only the explicit `gotcha:` trigger writes CLAUDE.md; a
  plain costly-first fact still tells-and-stops as today.
- **More flavors than gotcha.** The idea framed a "templates set"; exactly one flavor is named
  today. The "Recurring flavors" subsection is structured so a second flavor is a later additive
  entry, not a rebuild.
- **Property-views by type/tag.** The other remaining half of `memory-backlinks-search`; a separate
  future slice. No new `type` and no `tags:` field here.
- **CLAUDE.md write in sidecar mode.** Cannot touch the repo working tree (sidecar + employer-repo
  guarantee); the YES path falls back to tell-and-stop there.
- **Removing or editing an existing bullet.** The helper is add-only (insert-or-skip). Retiring a
  stale-prior is a manual edit.
- **Standalone template skeleton files** under `templates/`. The flavor lives as a documented
  convention + the shapes the skill writes, to avoid a skeleton drifting from actual output.

## 3. Architecture

```
/ingest "gotcha: <prior-vs-reality>"   (skills/ingest/SKILL.md)
  |
  step 0  detect the leading `gotcha:` / `stale-prior:` keyword -> gotcha branch
  |         (absent -> the existing /ingest flow, unchanged)
  step 1  boundary test (conventions/memory.md): costly-if-unseen?
  |
  |-- YES (costly-first) ----------------------------------------------------
  |     in-repo mode:  build the imperative bullet, CONFIRM, then call
  |       scripts/claude-md-upsert.sh <claude_md> "<section>" "<bullet>"
  |     sidecar mode:  cannot write the repo tree -> tell-and-stop (report why)
  |
  |-- NO (consult-when-relevant) --------------------------------------------
        write a docs/memory/ fact via the existing steps 3-7 (type/slug/
        secret-scan/write/index), using the gotcha body shape

scripts/claude-md-upsert.sh   (deterministic, idempotent, tested)
  reads a CLAUDE.md file, finds the managed section, inserts the bullet or
  skips an exact duplicate; never removes; confirm happens in the skill first.
```

The skill owns judgment (is it a gotcha, which home, is there a same-topic collision to raise with
the user, the confirm gate). The script owns the mechanical file surgery (find section, dedup,
insert, write) so the one action that can damage an always-loaded file is deterministic and
covered by tests.

## 4. The `gotcha:` branch in `/ingest`

Inserted into `skills/ingest/SKILL.md` ahead of the current Step 1, gated on the trigger:

- **Trigger:** the argument begins with `gotcha:` or `stale-prior:` (case-insensitive). Without it,
  `/ingest` runs exactly as today - no behavior change for normal facts.
- **Boundary test (reuse):** apply the existing conventions test. A pure stale-prior ("the model
  will confidently do the wrong thing") is usually YES; a "we chose differently, and why" prior is
  usually NO. The skill states the verdict to the user.
- **YES, in-repo mode:**
  1. Construct the imperative bullet (see Section 5 shape).
  2. Check the target section for a **same-topic** bullet already present. If one exists with
     different content, surface it and ask the user (update-by-hand vs add-anyway); do not
     auto-edit the existing line.
  3. Show the exact bullet + the target file path and **get explicit confirmation**.
  4. Call `scripts/claude-md-upsert.sh`. Report what the script did (created section / appended /
     skipped duplicate).
- **YES, sidecar mode:** do not write. Explain that the costly-first bullet belongs in the repo's
  CLAUDE.md, which sidecar mode never touches, and suggest the user add it by hand. Stop.
- **NO (either mode):** fall through to `/ingest`'s existing Steps 2-9 (tier test in sidecar, type,
  slug, secret scan, write fact, update index, commit in sidecar), using the gotcha body shape for
  the fact. The `docs/memory/` path needs no new machinery.
- **Secret scan applies on both paths** (reuse the existing rule): never write a key/token/`.env`
  value into CLAUDE.md or a fact.

## 5. Body shapes (the "note-template")

**CLAUDE.md bullet (YES path)** - imperative, one line, costly-first:

```
- <topic>: use <Y>, NOT <X> (training prior is wrong here). <one-clause why or [[link]]>
```

Example: `- Prisma import: use @/generated/prisma/client, NOT @prisma/client (training prior is wrong here).`

**`docs/memory/` fact (NO path)** - the existing fact schema with a consistent gotcha body:

```
---
name: <slug>
description: training prior wrong for <topic>
type: convention
---
Training prior says <X>. In this repo it is actually <Y>.
Why: <reason>. See [[<related-fact-or-D-record>]].
```

`type: convention` is the default ("how it really works here"); `/ingest` still asks when unclear.
No schema change - this uses the existing `domain | convention | reference` set.

**The convention** (`conventions/memory.md`, new "Recurring flavors" subsection) records the flavor
once: its name, the two body shapes above, the routing (the boundary test picks the home), and the
in-repo-only limit on the CLAUDE.md bullet. Both the skill and a human author follow this one
source rather than a separate skeleton file.

## 6. The helper: `scripts/claude-md-upsert.sh`

Pure bash + coreutils, matching `resolve-data-root.sh` (portable, no new deps).

**Invocation:** `claude-md-upsert.sh <claude_md_path> "<section_heading>" "<bullet_text>"`
- `<claude_md_path>` - the CLAUDE.md to edit (the skill resolves it: repo root via
  `git rev-parse --show-toplevel`, else `$CLAUDE_PROJECT_DIR` / `$PWD`).
- `<section_heading>` - the exact managed heading, `## Stale priors (training vs reality)`.
- `<bullet_text>` - the full bullet line including the leading `- `.

**Behavior:**
1. Missing/unreadable `<claude_md_path>` -> exit non-zero with a message on stderr; write nothing.
   (The skill decides what to tell the user; it never creates CLAUDE.md itself.)
2. **Exact-duplicate guard (idempotency):** if `<bullet_text>` already appears as a line in the file
   (whitespace-trimmed exact match), change nothing; print `skipped: already present`; exit 0.
3. **Section absent:** append `<section_heading>` followed by `<bullet_text>`. Placement: if the
   file's last non-blank line begins with `@` (a trailing import block), insert immediately before
   that block; otherwise append at end of file. Print `created section`; exit 0.
4. **Section present:** append `<bullet_text>` as the last line of that section (before the next
   `##`/`#` heading or EOF). Print `appended`; exit 0.
5. Preserve the rest of the file byte-for-byte (only insert lines; never reorder or reformat).

Exit codes: `0` success including the idempotent skip; non-zero only for a missing/unwritable file
or bad arguments. The script never prompts (the confirm gate is the skill's job).

## 7. Sidecar behavior

- **gotcha + YES in sidecar** -> tell-and-stop. The bullet belongs in the repo's root CLAUDE.md,
  which sidecar mode (and the employer-repo never-touch guarantee) forbids writing. Report the
  reason and suggest a manual add.
- **gotcha + NO in sidecar** -> the existing `/ingest` sidecar path: tier test, write the fact under
  the chosen tier's `memory/`, update that tier's `MEMORY.md`, commit in the `_meta` workspace.
- Consequence stated plainly (also in the convention doc): this feature's CLAUDE.md path is
  **in-repo only**; sidecar workspaces (e.g. the UDX day-job repos) get the `docs/memory/` half only.

## 8. Testing

- **`tests/test-claude-md-upsert.sh`** (plain bash, substring + exit-code assertions, fixture
  CLAUDE.md files, matching `tests/test-memory-graph.sh` style):
  - section absent -> section created + bullet present; exit 0.
  - section present -> bullet appended under it; exit 0.
  - exact-duplicate bullet -> file unchanged, `skipped: already present`, exit 0 (idempotent re-run).
  - trailing `@import` line -> new section inserted **before** the import block, import still last.
  - missing target file -> non-zero exit, nothing written.
  - rest-of-file preserved (a sentinel line elsewhere is untouched).
- **Live dogfood** (the skill is prose, so verify end-to-end): on a scratch in-repo repo run
  `/ingest gotcha: <prior-vs-reality>` that tests YES -> confirm the bullet lands and a re-run is
  idempotent; a NO gotcha -> confirm a `docs/memory/` fact + index line; then run once in a
  sidecar-marked tree -> confirm the YES path falls back to tell-and-stop and writes nothing in the
  repo tree.
- `scripts/validate-plugin.py` passes; existing `tests/test-memory-graph.sh` stays green (untouched).

## 9. Changes by file

- **`scripts/claude-md-upsert.sh`** (new) - the idempotent section-bullet upsert (Section 6).
- **`tests/test-claude-md-upsert.sh`** (new) + fixtures - the Section 8 cases.
- **`skills/ingest/SKILL.md`** - the `gotcha:` branch (Section 4): trigger detection, boundary-test
  routing, YES -> confirm + call the helper (in-repo) / tell-and-stop (sidecar), NO -> existing fact
  flow with the gotcha shape. Existing non-gotcha behavior unchanged.
- **`conventions/memory.md`** - the "Recurring flavors" subsection (Section 5): the stale-prior
  flavor, both body shapes, routing, in-repo-only note.
- **`.claude-plugin/plugin.json`** - version bump `0.14.0 -> 0.15.0`; mention gotcha capture in the
  description prose if it fits without noise.
- **`docs/project-tracking/`** - on completion: `resolved.md` action record `A-20260727-ingest-gotcha`;
  `decisions-log.md` decision `D-20260727-ingest-gotcha-claudemd` (/ingest may write a confirmed
  CLAUDE.md bullet for the explicit gotcha trigger, in-repo only; consistent with
  `D-20260627-memory-adopt-claudemd-scope`); update `memory-backlinks-search` in `ideas.md` to mark
  the note-templates half (gotcha flavor) shipped, property-views remaining.
- **`README.md` / `ARCHITECTURE.md`** - a short line on `/ingest gotcha:` if the memory section
  warrants it; match how `/ingest` is documented there, skip if it adds noise.

## 10. Open questions

None blocking. Decisions resolved in brainstorming:
- trigger = **explicit `gotcha:` / `stale-prior:` keyword** (not model-inferred), so a normal fact
  never silently mutates CLAUDE.md;
- routing = **the existing boundary test** picks the home (YES -> CLAUDE.md bullet, NO -> fact);
- CLAUDE.md write = **a small tested helper** (`claude-md-upsert.sh`), not model-driven Edit, with
  confirm-before-write in the skill and exact-duplicate idempotency in the script;
- scope = **gotcha flavor only, in-repo only**; general `/ingest` upgrade, more flavors, and
  property-views all deferred;
- posture = an **extension consistent with** `D-20260627-memory-adopt-claudemd-scope` (confirmed
  opt-in CLAUDE.md writes are allowed), recorded as its own `D-` record, not a silent reversal.
