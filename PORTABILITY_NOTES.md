# Portability Notes

## Install on a new machine / new job

```
/plugin marketplace add MDesai31/workspace-os
/plugin install workspace-os
```

Reload the session if the skills don't appear immediately (plugins load at session start). After
that, `/project-init`, `/project-log`, `/project-plan`, `/ingest`, `/memory-lint`,
`/memory-sync`, `/memory-adopt`, and `/tracking-adopt` are available in every repo on that machine.

## Updating the engine

Improve a skill or the conventions → commit and `git push` this repo → on each machine, update
the plugin (`/plugin` update, or `git pull` the marketplace clone) and reload. Every project picks
up the change — nothing to copy per-repo.

## What travels vs. what stays

- **Travels (this plugin):** skills, conventions, templates. Generic, project-agnostic.
- **Stays (per repo):** the actual tracking data in `<repo>/docs/project-tracking/` and the
  knowledge base in `<repo>/docs/memory/`. Both are version-controlled with that project and never
  leave it.

## Adopting it in a repo

Run `/project-init` once in the repo. It stamps the tracking files, adds the `merge=union`
`.gitattributes`, and seeds that repo's workstream tags. From then on, use `/project-log` and
`/project-plan`.

If the repo already has existing docs (README, design notes, CLAUDE.md reference content), run
`/memory-adopt` instead of starting empty — it scans, proposes a mapping, and applies only on
confirmation (opt-in, propose→confirm→apply).

If the repo has existing roadmaps, TODO lists, or prior planning docs, run `/tracking-adopt` — it routes roadmap entries → ideas, recorded decisions → decisions-log, and open TODOs → action-items. The `git` mode additionally mines merged git history into resolved-record proposals (local git is the base; `gh` enrichment is optional).

## Not included (future slices)

A `finish-task`-style closing ritual; a meta/management panel; remaining adoption sub-slices
(foreign memory-format conversion); and the cross-repo portfolio
registry. Each is its own future slice — see `docs/specs/` and
`docs/project-tracking/ideas.md`.
