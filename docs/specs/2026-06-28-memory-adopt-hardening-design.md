# /memory-adopt hardening — Design Spec (@import resolution + wider candidate set)

**Date:** 2026-06-28
**Status:** Approved design, ready for plan
**Idea:** `adoption-import` sub-slices (c) + (d), `ideas.md`
**Relates to:** `/memory-adopt` (D-20260626-memory-adopt-design), CLAUDE.md scope decision
(D-20260627-memory-adopt-claudemd-scope), `conventions/memory.md` (SoT)

---

## 1. Summary

Two gaps surfaced by the 2026-06-27 klapp dogfood of `/memory-adopt`:

- **(c) `@import`s are invisible.** `CLAUDE.md` is scanned as a single file; any `@path` it imports
  (e.g. `@AGENTS.md`) is always-loaded into the model's context but is never followed, so its
  content escapes classification.
- **(d) The candidate set is too narrow.** Defaults are `README*`, `docs/**/*.md`, `NOTES*`,
  `CLAUDE.md`. Common knowledge-bearing root docs (`AGENTS.md`, `RUNNING.md`, …) are scanned only if
  named in the path/glob argument.

This change closes both by introducing one explicit concept — the **always-loaded instruction
file** — and resolving `@import`s recursively.

Same contract as today: **propose → confirm → apply**, free-form source docs are **read-only**, the
skill **never commits**, re-runs are **idempotent**, and the passive default still never auto-touches
existing docs.

## 2. Scope

**In:**
- Define an **instruction-file class** in `conventions/memory.md` and generalize the existing
  CLAUDE.md trim rule to it.
- Resolve `@import`s recursively when scanning instruction files.
- Widen the default candidate set.
- Update `skills/memory-adopt/SKILL.md` steps to match; **delete** its "Known limitations" block
  (residual sub-slices are tracked in `ideas.md`).
- Tracking close-out: action record + decision record; move ideas sub-slices (c)/(d) to resolved.

**Out:**
- Foreign memory-format conversion — sub-slice (a), separate future slice.
- Any change to `/ingest`, `/memory-sync`, `/project-init`, or the bootstrap behavior.
- Changing how the path/glob **argument** works (it still limits the scan when provided).

## 3. The instruction-file class

The deciding distinction is **always-loaded instruction content** vs **free-form docs**:

| Class | Members | Edit policy |
|---|---|---|
| **Instruction files** | `CLAUDE.md`, `AGENTS.md`, and any file reached via `@import` resolution | **Trimmable** — memory-eligible (non-imperative) lines may be removed, confirm-first, structure-preserving — exactly the rule applied to `CLAUDE.md` today |
| **Free-form docs** | `README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md` | **Read-only** — extract to memory, never modify the source |

Rationale: the value of trimming `CLAUDE.md` is reducing always-loaded context once knowledge lives
in on-demand memory. `@import` targets and `AGENTS.md` are *also* always-loaded (by Claude Code via
import, and by sibling agents respectively), so the same rationale and the same trim rule apply.

Trimming an `@import` target trims **that target file**, not `CLAUDE.md`. The classification gates
(memory fact vs stays-as-imperative vs skip) are unchanged — only the set of files the trim rule may
act on widens.

## 4. Gap (c): `@import` resolution

When scanning an instruction file, parse bare `@path` lines (Claude Code import syntax: a bare `@`
followed by a path, not the `@import` keyword) and recursively scan the targets as additional
instruction files.

Rules:
- **Recursive**, matching how Claude Code actually loads imports. Maintain a **cycle guard** (each
  resolved path scanned at most once) and a **depth cap of 5**.
- **Repo-relative paths only.** Skip `@~/...`, absolute paths, and any path resolving outside the
  repo (user-global / not version-controlled). Note skipped imports in the report; do not pull them
  in.
- **Always exclude** `@docs/memory/MEMORY.md` and anything under `docs/memory/` or
  `docs/project-tracking/` — these are workspace-os's own layers. (`@docs/memory/MEMORY.md` is the
  line bootstrap itself adds.)
- **Dedup across discovery paths:** a file reached both as a default candidate and via `@import` is
  scanned once. A file's membership in the instruction-file class is sticky — if reached via
  `@import` it is trimmable even if it would otherwise be free-form.

## 5. Gap (d): wider default candidate set

Default candidates become:

- **Instruction class:** `CLAUDE.md`, `AGENTS.md`
- **Free-form:** `README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`, `CONTRIBUTING.md`,
  `ARCHITECTURE.md`, `DEVELOPMENT.md`

Unchanged: exclusions (`docs/memory/`, `docs/project-tracking/`), the optional path/glob argument
limiting the scan, and the bootstrap step (still touches only `CLAUDE.md`).

## 6. Changes by file

- **`conventions/memory.md`** — "Adopting existing docs (`/memory-adopt`)" section: add the
  instruction-file class table, generalize the trim rule from "only CLAUDE.md" to the instruction
  class, add the `@import` resolution rules, and update the candidate list.
- **`skills/memory-adopt/SKILL.md`** — Step 2 (scan): new candidate globs + import resolution as part
  of building the candidate set. Step 3 (classify) / Step 8 (apply): trim may target any
  instruction file, not just `CLAUDE.md`. **Delete** the "Known limitations" section. Keep the
  defer-to-conventions framing (no rule duplication).
- **`docs/project-tracking/`** — on completion: action record (this work), decision record
  (instruction-file class + recursive @import), and move ideas sub-slices (c)/(d) to `resolved.md`.

## 7. Verification

- `scripts/validate-plugin.py` passes (SKILL.md frontmatter `name`/`description` intact).
- Conventions ↔ SKILL.md consistency: candidate list and trim policy match between the two files;
  no rule is stated in SKILL.md that contradicts conventions.
- Dogfood reasoning re-check against klapp's `CLAUDE.md → @AGENTS.md`: `AGENTS.md` is now discovered
  (via import and as a default candidate), classified, and trimmable.
- No regressions to bootstrap / argument behavior (spot-read the unchanged steps).

## 8. Open questions

None. All three design decisions resolved during brainstorming:
trim scope = instruction-file class (trimmable); import depth = recursive (guarded, cap 5);
candidate set = AGENTS.md + curated free-form root docs.
