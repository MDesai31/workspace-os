# One project, many checkouts - propagation schema + branch matrix - design

- Date: 2026-08-28
- Status: accepted (design approved; implementation pending)
- Workstream: schema

## Problem

In a marked workspace, several checkout folders are often branches of ONE repo (the UDX
workspace: four folders, one origin), but the plugin models each folder as an independent
data root. The 2026-08 EC2 audit measured the consequence that remains after v0.22.1 fixed
the link-resolution half: propagation state has no schema, so a record's status fell back to
freeform prose ("fixed, pushed, deployed... Not yet applied to develop-scheduling") because
`open`/`done` cannot say "landed in two of four checkouts". Nothing can answer "which
checkouts still need this fix" without re-deriving it by hand.

## Goals

- A schema for propagation state on action records: which checkouts a change must land in
  (intent) and where it has landed (fact), both append-only and `merge=union`-safe.
- A deterministic answer to "which folders are checkouts of the same project" with zero
  hand-authored config.
- A read-only matrix view: records x checkouts, landed/pending/not-applicable per cell.
- A conversational write path so the fact lines actually get written (the audit's
  hand-authored-config lesson).

## Non-goals

- No in-repo mode support: in-repo checkouts share tracking files through git itself
  (branches merge); the independent-data-root problem is sidecar-only. Decided in
  brainstorming, 2026-08-28.
- No hook-detected propagation (watching sibling checkouts for landings) - fuzzy and heavy;
  the conversational mode plus cadence nudge is the write path.
- No standalone `/branch-matrix` skill - the view is a `/project-status` mode.
- No `D-` record propagation - decisions are reasoning, not deployable diffs; `A-` records
  only.
- No `finding-record-class` bundling - same schema file, separate slice.

## Decisions

- **Grouping is automatic, by normalized git remote URL.** Folders directly under the
  workspace root whose `origin` URL normalizes to the same key are one project. No
  `workspace.json` declaration, no override (YAGNI until a real no-remote case appears):
  the audit's core finding is that automatic surfaces get adopted (6-9/10) and hand-authored
  config does not (1-3/10). Folders with no git repo or no `origin` remote simply do not
  group and never appear in the matrix.
- **Intent and fact are separate lines.** A single "landed here" line with an implicit
  "all checkouts" target cannot express the real case from the audit (a fix relevant to a
  subset of checkouts). `Propagation:` declares the target set once; `Propagated-to:`
  records each landing. Both are appended lines, never edits - the `Superseded-by:`
  pattern.
- **The target set `all` is dynamic.** `Propagation: all` means "every checkout in this
  project's group at read time": a new checkout folder makes pending cells appear, a
  removed folder drops its column. The matrix reflects the current workspace, not a
  snapshot. A record that must not track future checkouts lists folders explicitly.
- **Checkouts are keyed by folder name** - the same key the sidecar data roots already use
  (`conventions/data-root.md`: "Repos are keyed by folder name").

## Design

### 1. Schema (`conventions/project-tracking.md`, new section)

Two optional, append-only lines on **action records** (open or resolved), valid only in
sidecar workspaces:

```
- Propagation: all | <folder>, <folder>
- Propagated-to: <checkout-folder> YYYY-MM-DD [sha-or-PR#]
```

- `Propagation:` is written at most once (first `/project-log propagated` on the record, or
  at `action` creation when the need is already known). It makes the record
  **matrix-relevant**; records without it never appear in the matrix.
- `Propagated-to:` - one line per landing, appended in landing order. The sha/PR is
  optional (opportunistic, like `Commit:` on done).
- **Read rule:** covered = the record's home checkout (the folder whose data root holds the
  record) once the record is done, plus every `Propagated-to:` folder. Pending = target set
  minus covered. A `Propagated-to:` line naming a folder outside the current group renders
  under a one-line "unknown folders" note - lenient, never an error (the folder may have
  been renamed or removed).
- The memory/tracking boundary is untouched: these are status lines, not evidence blocks;
  the ~40-line body ceiling still applies.

### 2. `scripts/checkout-groups.sh` - deterministic grouping

    checkout-groups.sh <workspace_root>

For each directory directly under `<workspace_root>` (excluding `_meta`): if it is a git
repo with an `origin` remote, normalize the URL - strip scheme, credentials, and trailing
`.git`; rewrite `git@host:path` to `host/path`; lowercase the host - and emit one line:

    project=<repo-basename> key=<normalized-url> folder=<name> branch=<current-branch>

Detached HEAD emits `branch=` empty. Non-repos and no-remote folders are skipped silently.
Fail-loud only when `<workspace_root>` is missing/unreadable (a read tool that errors should
say so - the summary-script posture). Plain bash + git, no jq. Skills consume these lines
and never re-derive grouping in prose.

### 3. `/project-status matrix` - the view (read-only)

New mode keyword `matrix` in the existing skill. Behavior:

- Resolve the data root. Mode `in-repo` -> one line ("matrix applies to marked workspaces
  only") and stop. Modes `sidecar`/`workspace-meta` -> proceed with the workspace root.
- Run `checkout-groups.sh`; no groups with >= 2 folders -> one-line empty state.
- For every folder in each multi-checkout project, read `_meta/<folder>/project-tracking/`
  `action-items.md` + `resolved.md` (lenient parse, per the house rule); select records
  carrying a `Propagation:` line.
- Render one table per project: header names the project and its checkouts (with current
  branches); one row per record (`<ID> (home: <folder>)`); cells `landed <date>` /
  `pending` / `n/a` (not in target set). Close with a per-checkout summary: "`<folder>`
  still needs: <IDs>" - the exact question the audit asked. Wide tables ride the existing
  recent-window rule (records resolved > ~60 days with no pending cells are elided with a
  count).
- Stays read-only: no propose/confirm gate, writes nothing - the skill's existing contract.

### 4. `/project-log propagated <A-id> <folder> [sha]` - the write path

New mode in the existing skill:

- Resolve the data root; in-repo -> not applicable, stop.
- Run `checkout-groups.sh`; locate `<A-id>` across the project's tracking roots
  (`action-items.md`, then `resolved.md`, in every grouped folder's data root - the record
  may live in a sibling checkout's root).
- `<folder>` must be one of the project's checkouts; otherwise list the valid folders and
  stop.
- If the record has no `Propagation:` line, propose one (default `all`) and append it on
  confirmation before the fact line.
- Append `- Propagated-to: <folder> <today> [sha]`. Skip-if-present (same folder already
  recorded -> say so, write nothing). Sidecar auto-commit after the write, as with every
  sidecar write.
- `hooks/capture-cadence.sh` gains one cadence line so "the fix landed in another checkout"
  prompts the capture conversationally.

### 5. Testing

`tests/test-checkout-groups.sh` (plain bash; tmpdir fixture), registered in
`.github/workflows/ci.yml`:

- fixture workspace: `_meta/workspace.json` + folder A (`https://Host/Org/Repo.git`) +
  folder B (`git@host:org/repo.git`) + folder C (different remote) + folder D (no remote) +
  folder E (not a git repo).
- A and B group under one key (normalization across scheme/case/`.git`); C is its own
  group; D and E absent from output.
- branch field: named branch reported; detached HEAD -> empty.
- missing workspace root -> non-zero exit with a message.

Matrix rendering and the `propagated` mode are skill prose, exercised by dogfooding (the
same posture as every other tracking-skill mode).

### 6. Packaging & close-out

- `plugin.json` -> 0.25.0.
- Conventions: the new "Propagation across checkouts" section (§1) in
  `conventions/project-tracking.md`.
- SKILL.mds: `matrix` mode in `/project-status`, `propagated` mode in `/project-log`.
- README + GUIDE: mention both modes (doc-freshness gate).
- Tracking (dogfood, at each step): idea graduates to `A-20260828-checkout-propagation`;
  the intent/fact two-line schema logged as `D-20260828-propagation-intent-fact-lines`;
  idea's remaining-halves annotations closed out on ship.

## Error handling

`checkout-groups.sh` fails loud on a bad workspace root, skips non-candidates silently.
The matrix view degrades per its empty states (wrong mode, no groups, no matrix-relevant
records) and parses records leniently. The `propagated` mode validates the folder against
the group and refuses unknown IDs with the searched locations listed - a write tool should
not guess. No hook touches the new schema, so nothing here can break a session.

## Open questions

None - scope (sidecar-only), grouping (auto by remote URL), view home (`/project-status
matrix`), and write path (`/project-log propagated`) decided in brainstorming, 2026-08-28.
