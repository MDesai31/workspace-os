# Architecture

`workspace-os` is a Claude Code plugin (the engine) that operates on a per-repo data layer.

## Three layers

1. **Engine (this plugin, portable).** Skills, the conventions doc, and the templates. Installed
   once into `~/.claude`, available in every repo, updated centrally. This is the only thing you
   carry job-to-job.
2. **Data (per-repo, version-controlled — location RESOLVED, never assumed).** Default (in-repo
   mode): `<repo>/docs/project-tracking/*.md` (tracking records)
   and `<repo>/docs/memory/*.md` (a shared knowledge base, indexed by `MEMORY.md` and surfaced via
   a `@docs/memory/MEMORY.md` import in the repo's CLAUDE.md) — living with each project's code and
   readable by Claude in that project's sessions.
   In a **marked workspace** (`_meta/workspace.json` — see `conventions/data-root.md`), the same
   data layer lives OUT of tree in a local-only `_meta/<repo>/` sidecar git repo instead
   (enterprise repos stay byte-identical to origin); memory gains a workspace tier
   (`_meta/memory/`) shared across the workspace's repos.
3. **Portfolio (deferred).** A future cross-repo registry. Not built in this version.

## How the pieces relate

```
/project-init ──stamps──▶ <repo>/docs/project-tracking/ + docs/memory/   (from templates/)
              └─ adds @docs/memory/MEMORY.md to the repo's CLAUDE.md
/workspace-init ──marks──▶ <workspace>/_meta/ (sidecar git repo, no remote) + workspace.json
resolve-data-root.sh ──answers──▶ mode + data_root   (run FIRST by every skill/hook)
sidecar-memory-context.sh ──SessionStart──▶ injects _meta memory (workspace tier, then repo tier)
/project-log  ──writes──▶ action-items.md · decisions-log.md · resolved.md
/project-plan ──writes──▶ ideas.md
/ingest       ──writes──▶ docs/memory/<slug>.md + MEMORY.md index
/memory-lint  ──checks──▶ docs/memory/ index + wikilink integrity
/memory-search ──queries──▶ docs/memory/ facts, by keyword or backlinks   (read-only)
/memory-sync  ──migrates▶ a ~/.claude fact ──▶ docs/memory/
/memory-adopt ──reshapes▶ existing docs ──▶ docs/memory/  (+ proposed CLAUDE.md trim)
/tracking-adopt ──routes──▶ existing roadmap/TODO docs ──▶ docs/project-tracking/  (git mode: merged history ──▶ resolved.md)
guardrail.sh  ──reads──▶ <repo>/.claude/guardrails.json   (PreToolUse deny/warn on Bash|Edit|Write)
lint.sh       ──reads──▶ <repo>/.claude/lint.json   (PostToolUse: lints edited file → additionalContext for Claude)
  tracking skills ──read──▶ conventions/project-tracking.md   (schema + lifecycle, SoT)
  memory skills   ──read──▶ conventions/memory.md             (schema + boundary test, SoT)
```

- **The guardrail engine** (`hooks/guardrail.sh`) is a PreToolUse hook: warn-only built-in defaults
  (secrets, force-push, `rm -rf`) plus declarative per-repo rules in `.claude/guardrails.json`
  (`bash`/`write` rules, `deny` blocks / `warn` advises). Opt in by copying `templates/guardrails.json`;
  the engine fails open when the file is absent. Same engine/data split as the rest of the plugin.
- **The lint engine** (`hooks/lint.sh`) is the PostToolUse counterpart: after an `Edit`/`Write`/
  `MultiEdit`, it runs each linter a repo declares in `.claude/lint.json` (`{name, match, command}`)
  whose `match` regex matches the edited file's path, and feeds any diagnostics back to Claude as
  `additionalContext` ("fix if quick"); a clean file is silent. It ships **no built-in linters** and
  fails open when the config or a linter is absent — opt in by copying `templates/lint.json`.
- **Skills** are model-interpreted instructions (`SKILL.md`). They contain no rules of their own
  beyond orchestration — the schema, ID scheme, and lifecycle live once in
  `conventions/project-tracking.md`, so there's no drift.
- **Templates** are the empty scaffolds `/project-init` copies into a new repo.
- **Data** never lives in this plugin — it lives in each target repo.

## Why a plugin, not a template repo

A template is a one-time scaffold that goes stale. A plugin is carried and updated centrally, so
every project on every machine gets an improvement the moment it lands. The bootstrap value of a
template is folded into `/project-init`.
