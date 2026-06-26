# workspace-os — Design Spec (SP1: plugin scaffold + project tracking)

**Status:** approved design, pre-implementation
**Date:** 2026-06-26
**Note on location:** this spec currently lives in the Options Analyzer repo for convenience;
it relocates into the new `workspace-os` repo when implementation begins.

## 1. Goal & context

Build a **portable personal "project operating system"** — a Claude Code plugin the user
installs once per machine and carries job-to-job, which provides command-driven project
tracking across their separate project repos (Options Analyzer, klapp, and future projects).

Modeled on the *structure* of a colleague's `keystone-engine` plugin (patterns only, no
proprietary content). That full system is a platform; this spec is **only the first slice
(SP1)**. The remaining slices are named in §8 as future work, each to get its own spec.

**Why a plugin, not a template repo:** a template is a one-time scaffold that goes stale; a
plugin is carried and updated centrally, so every project on every machine benefits from an
improvement the moment it lands. This is the difference between "a skeleton I copied" and "a
smart engine I bring with me."

**Why this fits the user:** they run multiple projects (a portfolio) but in *separate git
repos*, unlike the colleague's monorepo. A plugin operates in whatever repo is current and
writes data there, so the multi-repo structure stops being an obstacle.

## 2. Architecture (three layers)

1. **Engine (portable plugin)** — the `workspace-os` repo: skills, conventions, templates.
   Installed into `~/.claude`, available in every repo, updated centrally.
2. **Data (per-repo)** — `<repo>/docs/project-tracking/*.md`, the typed records the skills
   write, version-controlled with each project's code.
3. **Portfolio (deferred)** — a future cross-repo registry. Out of scope for SP1.

The plugin is the only thing carried job-to-job. Data stays with each project. Portfolio is a
later bolt-on (see §8).

## 3. Packaging & portability

`workspace-os` is its own git repo, structured as a Claude Code plugin:

```
workspace-os/
  .claude-plugin/plugin.json        # plugin manifest
  .claude-plugin/marketplace.json   # marketplace entry, so /plugin can install it
  skills/
    project-log/SKILL.md
    project-plan/SKILL.md
    project-init/SKILL.md
  templates/                        # what /project-init stamps into a new repo
    README.md
    action-items.md
    ideas.md
    decisions-log.md
    resolved.md
    gitattributes                   # becomes .gitattributes (merge=union lines)
  conventions/project-tracking.md   # ID scheme, entry schema, lifecycle — single source of truth
  README.md
  ARCHITECTURE.md
  PORTABILITY_NOTES.md
```

**Install / carry job-to-job:** on any machine, `/plugin marketplace add MDesai31/workspace-os`
then `/plugin install workspace-os`. Improve the engine → `git push` → reinstall/update and all
projects get the upgrade. (Same distribution model as the superpowers plugin.)

## 4. Per-repo data schema

The engine formalizes **typed, ID'd records** inside `docs/project-tracking/`:

| File | Holds | Written by |
|---|---|---|
| `action-items.md` | open action records | `/project-log action` |
| `resolved.md` | done records (archived on completion) | `/project-log done` |
| `decisions-log.md` | decision records (append-only) | `/project-log decision` |
| `ideas.md` | future intents with timing→priority | `/project-plan` |
| `README.md` | index (manual) | — |

**Entry schema** (example action record):
```
### A-20260626-symbol-matching — thread symbol through chain select
- Workstream: data/pipeline
- Status: open
- Created: 2026-06-26
(body: detail prose)
```
Decisions use `D-YYYYMMDD-slug`.

**IDs:** date-slug (`A-YYYYMMDD-slug` / `D-YYYYMMDD-slug`), assigned at creation, never
renumbered — collision-proof across parallel branches with no coordination. Pre-existing
`#`/letter items are **grandfathered** as legacy IDs; only new entries use date-slug.

**Lifecycle:**
- `action` → lands `open` in `action-items.md`.
- `done A-…` → stamped completion date + commit ref, **moved** to `resolved.md` (keeps the
  open list lean — the reason the roadmap was partitioned in the first place).
- `plan` → lands in `ideas.md`; graduates to `action-items.md` when it goes active.

**Workstream tags:** a small per-repo enum (the cross-cutting axis, replacing the colleague's
project codes). Seeded by `/project-init`. OA: `data/pipeline · strategy · ML · risk · ops`.
Each repo defines its own.

**Concurrency:** `action-items.md`, `decisions-log.md`, `resolved.md`, `ideas.md` are
`merge=union` in `.gitattributes` so concurrent appends across branches auto-merge.

## 5. Skills (SP1 ships three)

**`/project-log`** — three modes:
- `/project-log action <workstream> <desc>` → new `A-…` in `action-items.md`, status `open`.
- `/project-log decision <workstream> <desc>` → new `D-…` in `decisions-log.md`; prompts for
  rationale; offers to link any action items it spawns.
- `/project-log done <A-id> [commit]` → stamp completion date + commit ref, move record to
  `resolved.md`.

**`/project-plan <desc>`** — capture a *future* intent without starting it: name, workstream,
the why/context, rough timing → priority (`high/mid/low/someday`), and "what future-us needs
to start." Writes to `ideas.md`. Plans, does not execute.

**`/project-init`** — bootstrap a fresh repo: stamp `docs/project-tracking/` (the 5 files) from
templates, add `.gitattributes` union-merge lines, and seed the repo's workstream list (asks
the user). One command to drop the engine into klapp or any new project.

All three read the single `conventions/project-tracking.md` for the ID scheme, entry schema,
and lifecycle rules (rules live in one place, not restated per skill).

## 6. Conventions doc (`conventions/project-tracking.md`)

Single source of truth the skills reference:
- ID format and the never-renumber rule; legacy-ID grandfathering.
- The entry templates (action / decision / idea) field-by-field.
- The lifecycle state machine (open → done→moved; idea → graduated).
- Workstream-tag rules (per-repo enum, where it's stored).
- The union-merge requirement.

## 7. Verification (acceptance walkthrough)

Skills are markdown instructions, so verification is observed behavior in a throwaway scratch
repo:
1. `/project-init` in an empty dir → the 5 files + `.gitattributes` exist; workstreams seeded.
2. `/project-log action data/pipeline "test item"` → a correct `A-…` record appears in
   `action-items.md` with status `open`.
3. `/project-log done A-…` → the record is gone from `action-items.md` and present in
   `resolved.md` with a completion date + commit ref.
4. `/project-plan "someday: X"` → an entry appears in `ideas.md` with priority `someday`.

**First real-world use:** install `workspace-os`; `/project-init` **klapp** (no tracking yet)
as the live bootstrap test; begin using `/project-log` on Options Analyzer.

## 8. Scope boundaries

**In SP1:** the `workspace-os` plugin repo (manifest + marketplace), the three skills, the five
templates + `.gitattributes`, the conventions doc, the data schema.

**Out of SP1 (future slices, each its own spec):**
- **SP2 — Memory reconciliation:** how an in-repo structured memory relates to the existing
  `~/.claude` auto-memory (reconcile, don't duplicate).
- **SP3 — finish-task orchestration:** wrap the *existing* CI/PR/`/code-review` flow into one
  closing ritual.
- **SP4 — Meta + onboarding (optional):** workspace config panel, hooks-registry/manage_hooks,
  `project-guide`, the `blank-module` extension template.
- Additional `/project-log` modes (discovery / meeting / release-notes).
- The cross-repo **portfolio registry** (Layer 3).
- Engine **hooks** (e.g. a Stop-hook nudge, a CI link-guard).

**Explicitly not rebuilt (already covered by the user's setup):** session-compaction handling,
brainstorming and other superpowers skills, and the CI/PR/review flow already in place.

## 9. Fit with existing

- **OA `docs/project-tracking/`** (already created) is the schema's first consumer; existing
  items keep legacy IDs, new ones use date-slug. Optional later retrofit, not required.
- **Auto-memory (`MEMORY.md`)** — untouched in SP1; SP2 reconciles.
- **CI / PR / `/code-review`** — untouched; SP3 wraps.

## 10. Open items

- Plugin repo name: **`workspace-os`** (decided).
- This spec relocates from the OA repo into `workspace-os` at implementation start.
