# Portability Notes

## Install on a new machine / new job

```
/plugin marketplace add MDesai31/workspace-os
/plugin install workspace-os
```

Reload the session if the skills don't appear immediately (plugins load at session start). After
that, `/project-init`, `/project-log`, `/project-plan`, `/ingest`, `/memory-lint`, and
`/memory-sync` are available in every repo on that machine.

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

## Not included (future slices)

A `finish-task`-style closing ritual; a meta/management panel; an `adoption-import` path for
reshaping existing repo docs into workspace-os style; and the cross-repo portfolio registry. Each
is its own future slice — see `docs/specs/` and `docs/project-tracking/ideas.md`.
