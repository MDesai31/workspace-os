# Sidecar data layer (workspace `_meta/`) — Design Spec

**Date:** 2026-07-07
**Status:** Approved design, ready for plan
**Ideas:** partially resolves the "where does the registry live" blocker in `portfolio-registry`
(`ideas.md`)
**Relates to:** `ARCHITECTURE.md` (engine/data split — the "Data (per-repo, version-controlled)"
assumption is what this spec extends), `hooks/guardrail.sh`, `conventions/project-tracking.md`,
`conventions/memory.md`, [[SP4-meta-onboarding]]

---

## 1. Summary

workspace-os today stamps its data layer **inside** each target repo (`docs/project-tracking/`,
`docs/memory/`, a `@docs/memory/MEMORY.md` CLAUDE.md import, `.claude/guardrails.json`) and
version-controls it with the project. That breaks in an employer context where the repos are
enterprise-owned: personal tracking/memory artifacts cannot be committed to them, untracked
in-tree files are a contamination risk, and the data must still persist locally with history.

This spec adds a second **data-location mode** — *sidecar* — without changing the record formats,
conventions, or engine. A workspace directory (e.g. `~/Codebase/`) is marked by a
`_meta/workspace.json` file; every repo under a marked workspace stores its data layer in
`_meta/<repo-folder-name>/` instead of in-tree. `_meta/` is its own git repo with **no remote**
(local commits give full history/recovery), and no skill or hook ever writes inside an enterprise
repo's working tree. Unmarked machines behave exactly as today — in-repo mode remains the default
for personal projects.

"Where does the data live" changes from *assumed* to *resolved*: one shared script answers it,
and every skill runs that script first.

## 2. Scope

**In:**
- `scripts/resolve-data-root.sh` — the single mode/data-root resolver (walk-up marker search).
- `/workspace-init` — new skill: create `_meta/`, write `workspace.json`, `git init`, first commit.
- `/project-init` sidecar behavior: stamp `_meta/<repo>/` from the same templates; skip all
  in-repo edits (no CLAUDE.md import line, no `.claude/guardrails.json`).
- Data-path adjustment in `/project-log`, `/project-plan`, `/ingest`, `/memory-lint`,
  `/memory-sync`, `/memory-adopt`, `/tracking-adopt`: resolve first, then proceed; sidecar
  writers auto-commit to `_meta/` after each write.
- SessionStart hook: in sidecar mode, inject `_meta/<repo>/memory/MEMORY.md` (+ workspace-level
  `_meta/memory/MEMORY.md` if present) as session context.
- `hooks/guardrail.sh` fallback: if `<repo>/.claude/guardrails.json` is absent, read
  `<data_root>/guardrails.json`.
- Two-tier memory in sidecar workspaces: workspace tier (`_meta/memory/`) + repo tier, the
  tier test in `conventions/memory.md`, `/ingest` tier routing, `/memory-lint` cross-tier
  wikilink resolution.
- Conventions: one new canonical "Data-root resolution" section; the repo-tree-untouched
  invariant made explicit.
- Tests: resolver behavior matrix + a repo-tree-untouched assertion after each skill runs in a
  marked workspace.

**Out (YAGNI / deferred):**
- Any remote/sync for `_meta/` (the marker file could later carry a `"remote"` policy field;
  not built now — the driving constraint is local-only).
- Cross-repo portfolio registry features beyond the free `_meta/` root home (aggregation,
  `projects.md` schema, `/project-status` — stays in `portfolio-registry`).
- Migration tooling between modes (moving an existing in-repo data layer into a sidecar, or
  back). Manual `git mv` is acceptable until a real need appears.
- Multi-workspace nesting rules beyond "nearest marker wins".

## 3. Mode resolution (the core mechanism)

A **workspace** is any directory that directly contains `_meta/workspace.json`:

```json
{
  "workspace-os": "sidecar",
  "workspace": "acme-work"
}
```

`scripts/resolve-data-root.sh`, run from anywhere inside a repo, resolves:

1. Find the repo root (`git rev-parse --show-toplevel`).
2. Walk up from the repo root's parent looking for `_meta/workspace.json` (nearest marker wins).
3. **Found** → `mode=sidecar`, `data_root=<workspace>/_meta/<repo-folder-name>`,
   `workspace=<name from marker>`.
4. **Not found** → `mode=in-repo`, `data_root=<repo>/docs` (today's layout:
   `docs/project-tracking/`, `docs/memory/`).

Output is plain `key=value` lines consumable by skills and hooks alike:

```
mode=sidecar
data_root=/home/me/Codebase/_meta/repo-a
workspace=acme-work
```

Decisions locked in during design:

- **Sidecar always wins in a marked workspace.** If a repo under a marked workspace also has
  in-repo `docs/project-tracking/`, the sidecar is authoritative and the in-repo copy is ignored.
  The workspace declares the mode; there is no per-repo override. Rationale: one unambiguous
  machine-level switch ("work laptop = work mode"), no config drift per repo.
- **Repos are keyed by folder name** under the workspace, not by remote URL. Renaming a repo
  folder means renaming its `_meta/` entry. Rationale: readable, deterministic, no network.
- **Resolution logic exists once** — in the script, referenced by a single canonical paragraph in
  `conventions/` — never restated per-skill. Skills take `mode`/`data_root` as given and never
  compute data paths themselves. Skills announce the resolved mode in their output
  (e.g. "logging to sidecar: `_meta/repo-a/…`") so a wrong resolution is immediately visible.
- A bare `_meta/` folder without `workspace.json` marks nothing.

## 4. Sidecar layout

`_meta/` mirrors the in-repo data layer one level down, per repo — same templates, same record
schemas, `docs/` prefix dropped (there is no code to sit next to):

```
Codebase/                      ← workspace (work machine)
├── repo-a/                    ← enterprise repo, byte-identical to origin
├── repo-b/                    ← enterprise repo, byte-identical to origin
└── _meta/                     ← local git repo, NO remote
    ├── workspace.json         ← the marker (§3)
    ├── memory/                ← optional workspace-level, cross-repo facts + MEMORY.md
    ├── repo-a/
    │   ├── project-tracking/  ← action-items.md · decisions-log.md · resolved.md · ideas.md · README.md
    │   ├── memory/            ← MEMORY.md index + fact files
    │   ├── guardrails.json
    │   ├── CONTINUITY.md      ← same per-repo optional artifacts as in-repo mode
    │   └── MODEL_LOG.md
    └── repo-b/
        └── (same shape)
```

- `_meta/` is a full git repo: `git log`/`diff`/`checkout <commit> -- <file>` give history and
  recovery with zero remote. Skills that write records auto-commit after each write (sidecar
  mode only), so history granularity is per-record with no user discipline required.
- Workspace-level files directly under `_meta/` (e.g. `_meta/memory/`) are the natural home for
  cross-repo notes — the `portfolio-registry` "home above the repos" question is answered for
  the single-workspace case.
- **Two-tier memory.** Work repos are often separate parts of one overall project (e.g. a
  forecasting repo and a scheduling repo), so memory splits into a **repo tier**
  (`_meta/<repo>/memory/` — facts specific to one repo) and a **workspace tier**
  (`_meta/memory/` — facts true across the project: shared domain vocabulary, the data contract
  between the systems, environment/infra facts, team conventions). Each tier keeps its own
  `MEMORY.md` index. **Tier test** (added to `conventions/memory.md`, alongside the existing
  CLAUDE.md↔memory boundary test): *would this fact be just as true and useful in every repo of
  this workspace? → workspace tier; otherwise → repo tier.* Cross-tier wikilinks are allowed
  (e.g. a repo fact linking `[[shared-data-contract]]`).
- **No off-machine backup exists by design** (local-only constraint). If the machine has a
  corporate backup covering the codebase directory, `_meta/.git` rides along.

## 5. Skill changes

Every data-touching skill gets the same step 1: run the resolver, use its output.

| Skill | Sidecar-mode behavior |
|---|---|
| `/workspace-init` (new) | Create `_meta/`, write `workspace.json`, `git init`, initial commit. Separate skill (operates on a workspace, not a repo). |
| `/project-init` | Stamp `_meta/<repo>/` from the same `templates/`; **skip both in-repo edits** (no CLAUDE.md import line, no `.claude/guardrails.json`); commit the scaffold to `_meta/`. |
| `/project-log`, `/project-plan`, `/memory-sync` | Read/write via `data_root`; behavior otherwise unchanged; writers auto-commit to `_meta/`. |
| `/ingest` | Writes via `data_root`, defaulting to the **repo tier**; applies the tier test (§4) and proposes the workspace tier when a fact clearly spans repos (propose→confirm, same pattern as adoption). An explicit user scope request always wins. Auto-commits. |
| `/memory-lint` | Lints the resolved repo tier; in sidecar mode also resolves wikilinks against the workspace tier (`_meta/memory/`) so cross-tier links don't read as broken. Runnable at the workspace root to lint the workspace tier itself. |
| `/memory-adopt`, `/tracking-adopt` | Route extracted facts/records to `data_root`. The "proposed CLAUDE.md trim" step becomes **advisory-only** (suggest, never edit the enterprise repo). |
| `/continuity` | `CONTINUITY.md` lives at `_meta/<repo>/CONTINUITY.md`. |

In-repo mode is untouched: unmarked machines/paths hit today's code paths exactly, including
data commits riding with the project repo.

**Safety invariant (conventions, explicit):** in sidecar mode, no workspace-os skill or hook may
create, modify, or stage any file inside the repo's working tree.

## 6. Memory surfacing and guardrails (out-of-tree replacements)

Two features currently depend on writing into the repo:

- **Memory surfacing.** In-repo mode uses a `@docs/memory/MEMORY.md` import in the repo's
  CLAUDE.md. Sidecar mode instead ships a **SessionStart hook** (registered in
  `hooks/hooks.json`): it runs the resolver; if `mode=sidecar`, it emits the **workspace-tier
  index first** (`_meta/memory/MEMORY.md`, when present), then the repo-tier index
  (`_meta/<repo>/memory/MEMORY.md`) — general context before specific, so a session in either
  repo sees both tiers. Functionally equivalent to the import, zero repo footprint. If
  `mode=in-repo`, the hook exits silently (the CLAUDE.md import already covers it).
- **Guardrails.** `hooks/guardrail.sh` gains one fallback: if `<repo>/.claude/guardrails.json`
  is absent, read `<data_root>/guardrails.json`. In-repo config wins where present; the engine
  keeps failing open when neither exists.

## 7. Testing

Extend the existing bash test harness (`tests/`):

- **Resolver matrix:** marked workspace → sidecar; unmarked → in-repo; marker in a grandparent
  directory → sidecar (nearest wins); marked workspace where the repo *also* has in-repo docs →
  sidecar wins; `_meta/` without `workspace.json` → in-repo; not inside a git repo → error.
- **Repo-tree-untouched invariant:** in a fixture marked workspace, run each data-writing skill
  path and assert `git status --porcelain` in the target repo is empty afterwards.
- **Guardrail fallback:** rules in `<data_root>/guardrails.json` fire when the in-repo file is
  absent; in-repo file wins when both exist.
- **SessionStart hook:** emits workspace-tier then repo-tier index content in sidecar mode;
  repo tier only when no workspace tier exists; silent in in-repo mode and when no memory index
  exists.
- **Two-tier lint:** a repo-tier fact wikilinking a workspace-tier fact passes `--check` in
  sidecar mode; a genuinely broken link still fails.

## 8. Tracking close-out

- Log the design decision (`D-20260707-sidecar-data-layer`) and an action record for the build.
- Update `portfolio-registry` in `ideas.md`: the "where does it live" blocker is answered for the
  single-workspace case (`_meta/` root).
- Update `ARCHITECTURE.md` layer 2 wording ("Data (per-repo, version-controlled)") to describe
  both locations, once implemented.
