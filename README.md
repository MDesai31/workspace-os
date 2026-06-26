# workspace-os

A portable personal **project operating system** — a Claude Code plugin you install once per
machine and carry job-to-job. It provides command-driven project tracking across your separate
project repos: log actions and decisions, capture future ideas, and bootstrap a new repo's
tracking in one command.

The engine travels with you; the **data lives in each project's own repo**
(`<repo>/docs/project-tracking/`), version-controlled with that project's code.

## Install

On any machine:

```
/plugin marketplace add MDesai31/workspace-os
/plugin install workspace-os
```

Improve the engine → `git push` to this repo → reinstall/update, and every project on every
machine gets the upgrade.

## Skills

- **`/project-init`** — bootstrap a repo: stamp `docs/project-tracking/` + `.gitattributes`, seed the repo's workstream tags.
- **`/project-log`** — `action` / `decision` / `done`: append typed, ID'd records; completing an action moves it to the resolved record.
- **`/project-plan`** — capture a *future* intent (the why + rough timing) without starting it.

## How it works

See [`conventions/project-tracking.md`](conventions/project-tracking.md) for the record schema,
ID scheme, and lifecycle — the single source of truth all three skills follow. Architecture and
portability details are in [`ARCHITECTURE.md`](ARCHITECTURE.md) and
[`PORTABILITY_NOTES.md`](PORTABILITY_NOTES.md).
