# Data-Root Resolution

Where a repo's workspace-os data lives is **resolved, never assumed**. The single source of
truth is `scripts/resolve-data-root.sh`; skills and hooks consume its `key=value` output and
never compute data paths themselves. Skills announce the resolved mode in their report
(e.g. "logging to sidecar: `_meta/repo-a/project-tracking/action-items.md`").

## Modes

| mode | when | data_root | tracking | memory |
|---|---|---|---|---|
| `in-repo` | default (no marked workspace) | `<repo>/docs` | `<data_root>/project-tracking/` | `<data_root>/memory/` |
| `sidecar` | repo sits under a marked workspace | `<workspace>/_meta/<repo-folder-name>` | same shape | same shape |
| `workspace-meta` | CWD is inside `_meta/` itself | the `_meta` dir | none | `<data_root>/memory/` (workspace tier) |
| `workspace-root` | CWD is under a marked workspace but **not in any git repo** | none (no repo tier) | none | `<workspace_root>/memory/` (workspace tier) |

## The marker

A **workspace** is any directory that directly contains `_meta/workspace.json`:

    { "workspace-os": "sidecar", "workspace": "<name>" }

- **Sidecar always wins in a marked workspace.** In-repo `docs/project-tracking|memory` under a
  marked workspace are ignored even if present. There is no per-repo override — the workspace
  declares the mode.
- The resolver walks up from the repo root's parent; the **nearest** marker wins. With no git
  repo at all it walks up from CWD itself and reports `workspace-root`, so hooks needing only
  the workspace tier still fire from the workspace root; an unmarked non-git dir still errors. A bare
  `_meta/` without `workspace.json` (or with `"workspace-os"` ≠ `"sidecar"`) marks nothing.
- Repos are keyed by **folder name**. Renaming a repo folder means renaming its `_meta/` entry.

## No repo tier (`workspace-root` mode)

`workspace-root` is the one mode with **no `data_root`**: CWD is under a marked workspace but
in no git repo, so there is no repo to key data by. Skills must branch on `data_root` being
empty rather than assuming a repo tier — otherwise they build paths from the filesystem root
(`/project-tracking/…`) out of an unset variable. This matters more since v0.33.0, because
`hooks/capture-cadence.sh` now fires in this mode and actively invites `/ingest`,
`/project-log`, and `/handoff` from a context that has no repo tier to write to.

- **Tracking skills stop.** There is no repo-tier `project-tracking/` here. Say that the user
  needs to be inside one of the workspace's repos, name them if useful, and stop. Never write
  tracking to the workspace tier as a substitute — the tiers are not interchangeable.
- **Memory skills use the workspace tier**, `<workspace_root>/memory/`. The tier test in
  `conventions/memory.md` already routes workspace-wide facts there; a repo-specific fact
  authored from here belongs to a repo, so it waits until you are in one.
- **Read-only skills** that build a path from `data_root` (`/memory-search`, `/memory-lint`)
  point at `<workspace_root>/memory` in this mode, not `<data_root>/memory`.
- **Workspace-tier writes here are not auto-committed.** The auto-commit rule below is scoped
  to `sidecar` mode, so the same `_meta/` write is versioned or not depending on where you
  stood when you made it. Recorded rather than papered over; unifying it is its own decision.

## The sidecar `_meta/` repo

`_meta/` is its own git repo with **no remote** (local-only by design: full history and
recovery via `git log`/`diff`/`checkout` without pushing anywhere). Skills that write records
in sidecar mode **auto-commit to `_meta/` after each write** — per-record history with no user
discipline required. In-repo mode keeps today's behavior (data commits ride with the project
repo; skills do not auto-commit).

## Safety invariant (sidecar mode)

**No workspace-os skill or hook may create, modify, or stage any file inside the repo's
working tree.** This includes the CLAUDE.md memory-import line and `.claude/guardrails.json`
(replaced by the SessionStart memory hook and the guardrail sidecar fallback respectively).
`hooks/guardrail.sh` warns as a backstop if a write targets the repo's data-layer paths in
sidecar mode. Tests assert the resolver, hooks, and fixtures keep the repo tree byte-identical.

## Two-tier memory (sidecar workspaces)

See `conventions/memory.md` § "Two-tier memory in sidecar workspaces" for the tier test,
`/ingest` routing, and cross-tier wikilinks.
