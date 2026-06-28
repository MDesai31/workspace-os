---
name: tracking-adopt
description: Adopt a repo's existing roadmap / TODO / decision docs into docs/project-tracking/. Use when starting workspace-os in a repo that already has work-state docs (a README roadmap, a TODO file, design-doc decisions) and you want them captured as tracking records. Opt-in; propose-confirm-apply; never auto-runs.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[path or glob to limit the scan]   (default: the repo's common doc locations)"
---

# Tracking Adopt

Reshape a repo's **pre-existing work-state** docs — roadmaps, TODOs, and recorded decisions — into
`docs/project-tracking/`, in workspace-os style. The record schema, IDs, workstreams, and the
**adoption routing + idempotency** rules live in this plugin's `conventions/project-tracking.md`
(see "Adopting existing docs") — read it and follow it exactly; do not restate the rules here.

This is **opt-in and non-destructive to source docs**: every source doc (including `CLAUDE.md`) is
read only. The skill writes only under `docs/project-tracking/` (plus the bootstrap `.gitattributes`
lines), and only with your confirmation. It is the tracking-side sibling of `/memory-adopt`, which
owns durable knowledge; the two are complementary.

## Steps

1. **Bootstrap if needed.** If `docs/project-tracking/` does not exist, scaffold it like
   `/project-init`: copy this plugin's `templates/{action-items,ideas,decisions-log,resolved}.md`
   and `templates/README.md` into `docs/project-tracking/`; append the `merge=union` lines from
   `templates/gitattributes` to the repo's `.gitattributes` (if not already present). For the
   workstream enum, **propose a set inferred from the scanned docs** (Step 2) for the user to
   confirm/edit, then write it into the README's `## Workstreams`.
2. **Scan candidates.** Glob `README*`, `docs/**/*.md`, `NOTES*`, `CLAUDE.md`, `TODO*`/`TODOS*`,
   `CHANGELOG*`/`RELEASES*` (honor the optional path/glob argument). **Exclude**
   `docs/project-tracking/` and `docs/memory/`. Detect tracking-content by section headers (Roadmap,
   Future, Post-MVP, Out-of-scope, Backlog, TODO, Key decisions) and checkbox lists. List what
   you'll consider.
3. **Classify** each detected chunk through the routing in `conventions/project-tracking.md`: → an
   idea (`ideas.md`), → a `D-` decision (`decisions-log.md`), → an `A-` action (`action-items.md`),
   → skip-for-now (completed → `resolved.md`, a later slice), or → out-of-lane (durable knowledge →
   `/memory-adopt`).
4. **Dedup.** Read existing `docs/project-tracking/`; if a proposed record's slug already exists or
   its content is clearly already present, mark it "already adopted — skip." Grandfather any
   pre-existing `#`/letter IDs in sources (reference as-is, never rewrite).
5. **Secret-scan** each proposed record — keys/tokens/bearer values/`.env`-style `KEY=value`. If a
   chunk contains a secret, do not write it into a record; flag it for the user instead.
6. **Propose one batch** for review, grouped by target file: each source → proposed records
   (`ID`/name, target, one-line) with the deciding signal and source location; plus the
   proposed/confirmed workstream set; plus what's skipped / out-of-lane, each with a one-line reason.
7. **Confirm.** Wait for the user to approve / edit / drop. Write nothing before this.
8. **Apply.** Append each approved record to its target file using the templates in
   `conventions/project-tracking.md`. When a target file still shows its italic placeholder line
   (`_No ideas captured yet._`, `_No open items yet._`, `_No decisions logged yet._`), replace it.
   **Never modify source docs.**
9. **Report** what was created per file, what was skipped (+ why), and what's out-of-lane for
   `/memory-adopt`. Do **not** commit — leave everything staged-ready.

## Known limitations

- **Slice 1 is docs-only.** Completed work is not adopted (it belongs in `resolved.md`, which needs
  a real commit ref); git-history reconstruction for docs-poor repos is a later slice.
- **Candidate set is fixed** to the globs above (minus `docs/project-tracking/` and `docs/memory/`).
  Other docs are scanned only if named in the path/glob argument. Inline code `// TODO`s are not mined.
