---
name: memory-adopt
description: Adopt a repo's existing documentation into docs/memory/, or convert a foreign memory store (a notes/ dir, an Obsidian-style vault) with the foreign mode. Use when starting workspace-os in a repo that already has docs (README, design notes, an overgrown CLAUDE.md) or an existing memory/notes system you want reshaped into the shared memory layer. Opt-in; propose-confirm-apply; never auto-runs.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[path or glob to limit the scan] | foreign <store-path>"
---

# Memory Adopt

Reshape a repo's **pre-existing** knowledge docs into `<data_root>/memory/` (`docs/memory/` in
in-repo mode), in workspace-os style. The fact schema, the boundary test, and the **adoption
routing + instruction-file trim + idempotency** rules live in this plugin's `conventions/memory.md`
(see "Adopting existing docs") — read it and follow it exactly; do not restate the rules here.

This is **opt-in and non-destructive to free-form docs**: `README`/`NOTES`/`docs/**` are read
only. The only files ever edited are **instruction files** (`CLAUDE.md`, `AGENTS.md`, and resolved
`@import` targets), and only an approved trim, and only with your confirmation.

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in every repo-tier
   mode; never hardcode `docs/…`.
   With no `data_root` (`workspace-root` mode) see `conventions/data-root.md`
   § "No repo tier". Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).
1. **Bootstrap if needed.** If `<data_root>/memory/` does not exist, scaffold it like
   `/project-init`'s memory step: copy this plugin's `templates/memory/MEMORY.md` →
   `<data_root>/memory/MEMORY.md`. *(in-repo only:)* add the line `@docs/memory/MEMORY.md` to the
   repo's `CLAUDE.md` (append if not present; create `CLAUDE.md` with just that line if there is
   none); add `docs/memory/MEMORY.md merge=union` to the repo's `.gitattributes` (append if not
   present). *(sidecar:)* the CLAUDE.md import is replaced by the plugin's SessionStart hook — do
   nothing; append the `merge=union` line to `<workspace_root>/.gitattributes` instead, rekeyed
   as in `/project-init` (drop the `docs/` prefix, prefix `<repo-folder-name>/`).
2. **Scan candidates.** Build the candidate set per `conventions/memory.md` — instruction files
   (`CLAUDE.md`, `AGENTS.md`) and free-form docs (`README*`, `docs/**/*.md`, `NOTES*`, `RUNNING.md`,
   `CONTRIBUTING.md`, `ARCHITECTURE.md`, `DEVELOPMENT.md`), honoring the optional path/glob
   argument. **Resolve `@import`s** in instruction files recursively (cycle-guarded, depth cap 5,
   repo-relative only) and add the targets as instruction files. **Exclude** `<data_root>/memory/`
   and `<data_root>/project-tracking/`. **Check for a foreign memory store** (the detection
   signals in `conventions/memory.md` § "Adopting a foreign memory store"): on a hit, name the
   store, point the user at `/memory-adopt foreign <path>`, and leave its files out of this
   scan. List what you'll consider, marking which are instruction files.
3. **Classify** each chunk through the gates in `conventions/memory.md`: → a memory fact (pick
   `domain|convention|reference`), → stays in its instruction file (imperative), or → skip (work-state /
   not-knowledge / about-the-person).
4. **Dedup.** Read existing `<data_root>/memory/`; if a proposed fact's slug already exists or its
   content is clearly already present, mark it "already adopted — skip." Do not propose duplicates.
5. **Secret-scan** each proposed fact — keys/tokens/bearer values/`.env`-style `KEY=value`. If a
   chunk contains a secret, do not propose it as a fact; flag it for the user instead.
6. **Propose one batch** for review — a table: each source → proposed facts (`slug`, `type`,
   one-line); for each instruction file, the lines to extract → memory **and** the exact proposed trim; plus
   what **stays** and what's **skipped**, each with a one-line rationale naming the deciding gate.
   In sidecar mode this proposal is ADVISORY-ONLY: present the suggested trim but never edit the
   repo's CLAUDE.md (conventions/data-root.md safety invariant).
7. **Confirm.** Wait for the user to approve / edit / drop. Write nothing before this.
8. **Apply.** For each approved fact: write `<data_root>/memory/<slug>.md` (fact schema from
   conventions) and append its index line to `MEMORY.md` under the matching type section
   (replacing the `_No facts yet._` placeholder if present). For each approved trim: remove
   exactly those lines from the instruction file they live in (`CLAUDE.md` or the `@import`
   target), preserving the rest of the file. **Never modify free-form source docs.**
9. **Report** what was created, the instruction-file trim(s) applied (if any), and what was skipped + why.
   Do **not** commit — leave everything staged-ready.

## Foreign store mode: `/memory-adopt foreign <path>`

Store-level conversion of an existing memory system (a `memory/`/`notes/` dir, an
Obsidian-style vault) into `<data_root>/memory/` schema. The detection signals, the full
conversion mapping (slug/description/type/body/links/frontmatter), and the routing for
notes that are not facts (procedures → `/playbook adopt`, work-state → `/tracking-adopt`)
live in `conventions/memory.md` § "Adopting a foreign memory store" — read it and follow it
exactly.

1. Run steps 0-1 above (resolve, bootstrap). `<path>` must exist and contain `.md` files;
   if it does not look like a store per the conventions' signals, say what's missing and ask
   before proceeding anyway.
2. Read every `.md` in the store (the store is **read-only** throughout — conversion copies,
   never moves or deletes). Build the per-note conversion table per the conventions mapping.
3. Then the normal ritual, unchanged: dedup (step 4), secret-scan (step 5), propose the
   whole batch (step 6 — the table shows each note → fact slug/type/one-line, splits,
   reroutes, flattened links, and skips with the deciding gate), confirm (step 7), apply
   (step 8: fact files + index lines).
4. Report per step 9, plus the conventions' retire reminder: the foreign store still exists
   and is now the second store — retiring it is the user's call, never this skill's.

