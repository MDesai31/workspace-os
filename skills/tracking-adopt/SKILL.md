---
name: tracking-adopt
description: Adopt a repo's existing roadmap / TODO / decision docs into docs/project-tracking/, and (git mode) its merged git history into resolved.md. Use when starting workspace-os in a repo that already has work-state docs or a real commit history you want captured as tracking records. Opt-in; propose-confirm-apply; never auto-runs.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[path or glob to limit the scan] | git [range]   (docs scan by default; git mode mines merged history — default bound: newest tag, else last ~30 merged units)"
---

# Tracking Adopt

Reshape a repo's **pre-existing work-state** docs — roadmaps, TODOs, and recorded decisions — into
`<data_root>/project-tracking/` (`docs/project-tracking/` in in-repo mode), in workspace-os style.
The record schema, IDs, workstreams, and the **adoption routing + idempotency** rules live in this
plugin's `conventions/project-tracking.md` (see "Adopting existing docs") — read it and follow it
exactly; do not restate the rules here.

This is **opt-in and non-destructive to source docs**: every source doc (including `CLAUDE.md`) is
read only. The skill writes only under `<data_root>/project-tracking/` (plus the bootstrap
`merge=union` lines — to the repo's `.gitattributes` in in-repo mode, to
`<workspace_root>/.gitattributes` in sidecar, never the repo tree), and only with your
confirmation. It is the tracking-side sibling of `/memory-adopt`, which owns durable knowledge;
the two are complementary.
The explicit **`git` mode** (`/tracking-adopt git [range]`) additionally mines merged git history
into `resolved.md` — see "Git mode" below.

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in BOTH modes; never
   hardcode `docs/…`. Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).
1. **Bootstrap if needed.** If `<data_root>/project-tracking/` does not exist, scaffold it like
   `/project-init`: copy this plugin's `templates/{action-items,ideas,decisions-log,resolved}.md`
   and `templates/README.md` into `<data_root>/project-tracking/`; append the `merge=union` lines
   from `templates/gitattributes` *(in-repo:)* to the repo's `.gitattributes` (if not already
   present) *(sidecar:)* to `<workspace_root>/.gitattributes` instead, rekeyed as in
   `/project-init` (drop the `docs/` prefix, prefix `<repo-folder-name>/`) — never the repo's
   `.gitattributes`. For the workstream enum, **propose a set inferred from the scanned docs** (Step 2) for the user to
   confirm/edit, then write it into the README's `## Workstreams`.
2. **Scan candidates.** Glob `README*`, `docs/**/*.md`, `NOTES*`, `CLAUDE.md`, `TODO*`/`TODOS*`,
   `CHANGELOG*`/`RELEASES*` (honor the optional path/glob argument). **Exclude**
   `<data_root>/project-tracking/` and `<data_root>/memory/`. Detect tracking-content by section
   headers (Roadmap, Future, Post-MVP, Out-of-scope, Backlog, TODO, Key decisions) and checkbox
   lists. List what you'll consider.
3. **Classify** each detected chunk through the routing in `conventions/project-tracking.md`: → an
   idea (`ideas.md`), → a `D-` decision (`decisions-log.md`), → an `A-` action (`action-items.md`),
   → skip in docs-only mode (completed → `resolved.md` via the git mode below), or → out-of-lane (durable knowledge →
   `/memory-adopt`).
4. **Dedup.** Read existing `<data_root>/project-tracking/`; if a proposed record's slug already
   exists or its content is clearly already present, mark it "already adopted — skip." Grandfather
   any pre-existing `#`/letter IDs in sources (reference as-is, never rewrite).
5. **Secret-scan** each proposed record — keys/tokens/bearer values/`.env`-style `KEY=value`. If a
   chunk contains a secret, do not write it into a record; flag it for the user instead.
6. **Propose one batch** for review, grouped by target file: each source → proposed records
   (`ID`/name, target, one-line) with the deciding signal and source location; plus the
   proposed/confirmed workstream set; plus what's skipped / out-of-lane, each with a one-line reason.
7. **Confirm.** Wait for the user to approve / edit / drop. Write nothing before this.
8. **Apply.** Append each approved record to its target file using the templates in
   `conventions/project-tracking.md`. When a target file still shows its italic placeholder line
   (`_No ideas captured yet._`, `_No open items yet._`, `_No decisions logged yet._`), replace it.
   **Never modify source docs.** In sidecar mode, write routed records to
   `<data_root>/project-tracking/` only; source docs in the repo tree are read, summarized, and
   left byte-identical — any "archive/trim the source doc" step becomes advisory-only.
9. **Report** what was created per file, what was skipped (+ why), and what's out-of-lane for
   `/memory-adopt`. Do **not** commit — leave everything staged-ready.

## Git mode (`/tracking-adopt git [range]`)

Adds **git history** as a source; routes to **`resolved.md` only**. The routing, record shape,
bound, and dedup rules live in `conventions/project-tracking.md` ("Git-history archaeology") —
read them and follow them exactly; do not restate them here. Steps 0–1 above (data root,
bootstrap) run unchanged; then:

G2. **Bound the walk.** With a `[range]` argument, pass it to `git log` verbatim. Otherwise:
    default branch = `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||'`
    (fallback: the current branch); bound = `$(git describe --tags --abbrev=0 <branch>)..<branch>` when a tag
    exists, else the last ~30 merged units. Announce the resolved bound.
G3. **Mine candidate units.** Walk
    `git log --first-parent --date=short --pretty=format:'%h%x09%ad%x09%s%x09%b%x1e' <bound>`
    on the default branch. One unit per: **merge commit**; **squash commit with a `(#N)` PR
    marker** in its subject; a **model-grouped run of related direct-to-main commits**
    (judgment). Skip noise — chore/typo/CI/formatting/version-bump — never record it.
G4. **Enrich opportunistically.** If a GitHub remote exists and `gh` (or the GitHub MCP) works,
    fetch `gh pr view <N> --json title,body,createdAt` for candidate PR numbers. On **any**
    failure, degrade silently to commit messages — enrichment never blocks or fails the run.
G5. **Cross-match doc-completed items.** Run the docs scan (Step 2 globs) for **completed items
    only** (checked `- [x]`, changelog "done"); match each against the mined units by content
    similarity. Matched → enrich that unit's single record (the doc phrasing may improve the
    title/body); never a second record. Unmatched → skip and report — prose alone does not
    legitimize a resolved record.
G6. **Dedup.** Primary key = **SHA/PR#**: skip any candidate whose SHA or PR number already
    appears in `resolved.md` (prior imports and organic `/project-log done` records alike).
    Secondary: slug/content, as in Step 4 above.
G7. **Secret-scan** each proposed record — commit messages and PR bodies can carry tokens
    (same rule as Step 5 above).
G8. **Propose one batch:** one `resolved.md` record per unit, per the SoT record shape
    (`A-<merge-date>-slug`, `Created:`/`Completed:`/`Commit:`, Status `done`, workstream from the
    repo enum, 2–4 line body + provenance line). Each proposal shows the SHA/PR# and the
    enrichment/cross-match source. Over ~30 candidates → propose the newest ~30 and say how to
    continue with an explicit range.
G9. **Confirm → Apply → Report** exactly as Steps 7–9 above. Replace `resolved.md`'s italic placeholder line on first write (the shipped template's is `_Nothing resolved yet._`) — match the italic line, not a fixed string. All sidecar rules and the
    no-auto-commit rule apply unchanged.

## Known limitations

- **Git mode routes to `resolved.md` only.** Decision mining from commit/PR prose and open
  branches/stale issues → `action-items.md` are deliberately deferred (fuzzy, noisy); inline code
  `// TODO`s are not mined.
- **Candidate set is fixed** to the globs above (minus `<data_root>/project-tracking/` and
  `<data_root>/memory/`). Other docs are scanned only if named in the path/glob argument.
