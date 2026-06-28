---
name: memory-adopt
description: Adopt a repo's existing documentation into docs/memory/. Use when starting workspace-os in a repo that already has docs (README, design notes, an overgrown CLAUDE.md) and you want that knowledge reshaped into the shared memory layer. Opt-in; propose-confirm-apply; never auto-runs.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[path or glob to limit the scan]   (default: the repo's common doc locations)"
---

# Memory Adopt

Reshape a repo's **pre-existing** knowledge docs into `docs/memory/`, in workspace-os style. The
fact schema, the boundary test, and the **adoption routing + instruction-file trim + idempotency** rules
live in this plugin's `conventions/memory.md` (see "Adopting existing docs") — read it and follow
it exactly; do not restate the rules here.

This is **opt-in and non-destructive to free-form docs**: `README`/`NOTES`/`docs/**` are read
only. The only files ever edited are **instruction files** (`CLAUDE.md`, `AGENTS.md`, and resolved
`@import` targets), and only an approved trim, and only with your confirmation.

## Steps

1. **Bootstrap if needed.** If `docs/memory/` does not exist, scaffold it like `/project-init`'s
   memory step: copy this plugin's `templates/memory/MEMORY.md` → `docs/memory/MEMORY.md`; add the
   line `@docs/memory/MEMORY.md` to the repo's `CLAUDE.md` (append if not present; create
   `CLAUDE.md` with just that line if there is none); add `docs/memory/MEMORY.md merge=union` to
   `.gitattributes` (append if not present).
2. **Scan candidates.** Build the candidate set per `conventions/memory.md` — instruction files
   (`CLAUDE.md`, `AGENTS.md`) and free-form docs (`README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`,
   `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md`), honoring the optional path/glob
   argument. **Resolve `@import`s** in instruction files recursively (cycle-guarded, depth cap 5,
   repo-relative only) and add the targets as instruction files. **Exclude** `docs/memory/` and
   `docs/project-tracking/`. List what you'll consider, marking which are instruction files.
3. **Classify** each chunk through the gates in `conventions/memory.md`: → a memory fact (pick
   `domain|convention|reference`), → stays in CLAUDE.md (imperative), or → skip (work-state /
   not-knowledge / about-the-person).
4. **Dedup.** Read existing `docs/memory/`; if a proposed fact's slug already exists or its content
   is clearly already present, mark it "already adopted — skip." Do not propose duplicates.
5. **Secret-scan** each proposed fact — keys/tokens/bearer values/`.env`-style `KEY=value`. If a
   chunk contains a secret, do not propose it as a fact; flag it for the user instead.
6. **Propose one batch** for review — a table: each source → proposed facts (`slug`, `type`,
   one-line); for each instruction file, the lines to extract → memory **and** the exact proposed trim; plus
   what **stays** and what's **skipped**, each with a one-line rationale naming the deciding gate.
7. **Confirm.** Wait for the user to approve / edit / drop. Write nothing before this.
8. **Apply.** For each approved fact: write `docs/memory/<slug>.md` (fact schema from conventions)
   and append its index line to `MEMORY.md` under the matching type section (replacing the
   `_No facts yet._` placeholder if present). For each approved trim: remove exactly those lines
   from the instruction file they live in (`CLAUDE.md` or the `@import` target), preserving the
   rest of the file. **Never modify free-form source docs.**
9. **Report** what was created, the CLAUDE.md trim applied (if any), and what was skipped + why.
   Do **not** commit — leave everything staged-ready.

