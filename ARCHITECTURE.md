# Architecture

`workspace-os` is a Claude Code plugin (the engine) that operates on a per-repo data layer.

## Three layers

1. **Engine (this plugin, portable).** Skills, the conventions doc, and the templates. Installed
   once into `~/.claude`, available in every repo, updated centrally. This is the only thing you
   carry job-to-job.
2. **Data (per-repo, version-controlled).** `<repo>/docs/project-tracking/*.md` (tracking records)
   and `<repo>/docs/memory/*.md` (a shared knowledge base, indexed by `MEMORY.md` and surfaced via
   a `@docs/memory/MEMORY.md` import in the repo's CLAUDE.md) — living with each project's code and
   readable by Claude in that project's sessions.
3. **Portfolio (deferred).** A future cross-repo registry. Not built in this version.

## How the pieces relate

```
/project-init ──stamps──▶ <repo>/docs/project-tracking/ + docs/memory/   (from templates/)
              └─ adds @docs/memory/MEMORY.md to the repo's CLAUDE.md
/project-log  ──writes──▶ action-items.md · decisions-log.md · resolved.md
/project-plan ──writes──▶ ideas.md
/ingest       ──writes──▶ docs/memory/<slug>.md + MEMORY.md index
/memory-lint  ──checks──▶ docs/memory/ index + wikilink integrity
/memory-sync  ──migrates▶ a ~/.claude fact ──▶ docs/memory/
/memory-adopt ──reshapes▶ existing docs ──▶ docs/memory/  (+ proposed CLAUDE.md trim)
/tracking-adopt ──routes──▶ existing roadmap/TODO docs ──▶ docs/project-tracking/  (slice 1: docs-only)
  tracking skills ──read──▶ conventions/project-tracking.md   (schema + lifecycle, SoT)
  memory skills   ──read──▶ conventions/memory.md             (schema + boundary test, SoT)
```

- **Skills** are model-interpreted instructions (`SKILL.md`). They contain no rules of their own
  beyond orchestration — the schema, ID scheme, and lifecycle live once in
  `conventions/project-tracking.md`, so there's no drift.
- **Templates** are the empty scaffolds `/project-init` copies into a new repo.
- **Data** never lives in this plugin — it lives in each target repo.

## Why a plugin, not a template repo

A template is a one-time scaffold that goes stale. A plugin is carried and updated centrally, so
every project on every machine gets an improvement the moment it lands. The bootstrap value of a
template is folded into `/project-init`.
