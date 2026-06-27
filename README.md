# workspace-os

A portable personal **project operating system** — a Claude Code plugin you install once per
machine and carry job-to-job. It provides command-driven project **tracking** *and* a per-repo shared **memory** layer across
your separate project repos: log actions and decisions, capture future ideas, bootstrap a repo in
one command, and build a version-controlled knowledge base that travels with each repo.

The engine travels with you; the **data lives in each project's own repo**
(`<repo>/docs/project-tracking/` and `<repo>/docs/memory/`), version-controlled with that
project's code.

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
- **`/ingest`** — capture a durable project fact into `docs/memory/` + update the index.
- **`/memory-lint`** — check `docs/memory/` index / frontmatter / wikilink integrity.
- **`/memory-sync`** — migrate a fact from your `~/.claude` auto-memory into a repo's `docs/memory/`.
- **`/memory-adopt`** — adopt a repo's existing docs (README, design notes, CLAUDE.md reference content) into `docs/memory/` (opt-in, propose→confirm→apply).

## How it works

See [`conventions/project-tracking.md`](conventions/project-tracking.md) (tracking schema, IDs,
lifecycle) and [`conventions/memory.md`](conventions/memory.md) (memory schema + the
CLAUDE.md↔memory boundary test) — the single sources of truth the skills follow. Architecture and
portability details are in [`ARCHITECTURE.md`](ARCHITECTURE.md) and
[`PORTABILITY_NOTES.md`](PORTABILITY_NOTES.md).
