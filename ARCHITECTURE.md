# Architecture

`workspace-os` is a Claude Code plugin (the engine) that operates on a per-repo data layer.

## Three layers

1. **Engine (this plugin, portable).** Skills, hooks, scripts, the conventions docs, the
   templates, and the policy packs. Installed
   once into `~/.claude`, available in every repo, updated centrally. This is the only thing you
   carry job-to-job.
2. **Data (per-repo, version-controlled — location RESOLVED, never assumed).** Default (in-repo
   mode): `<repo>/docs/project-tracking/*.md` (tracking records, including live handoff records
   under `project-tracking/handoffs/`), `<repo>/docs/memory/*.md` (a shared knowledge base,
   indexed by `MEMORY.md` and surfaced via a `@docs/memory/MEMORY.md` import in the repo's
   CLAUDE.md), and `<repo>/docs/playbooks/*.md` (trigger-surfaced procedures) — living with each
   project's code and readable by Claude in that project's sessions.
   In a **marked workspace** (`_meta/workspace.json` — see `conventions/data-root.md`), the same
   data layer lives OUT of tree in a local-only `_meta/<repo>/` sidecar git repo instead
   (enterprise repos stay byte-identical to origin); memory gains a workspace tier
   (`_meta/memory/`) shared across the workspace's repos.
3. **Portfolio (deferred).** A future cross-repo registry. Not built in this version.

## How the pieces relate

```
/project-init ──stamps──▶ <repo>/docs/project-tracking/ + docs/memory/   (from templates/)
              └─ adds @docs/memory/MEMORY.md to the repo's CLAUDE.md
              (also stamps the portable layer: operator's manual, memory_graph.py, AGENTS.md, CLAUDE.md bridge)
/make-portable -> retrofits an existing docs/memory/ base with the portable layer   (operator's manual, memory_graph.py, AGENTS.md, CLAUDE.md bridge; add-only, idempotent)
/make-portable refresh -> re-copies plugin-owned files only (manual + memory_graph.py; confirm-gated, never AGENTS.md/facts/index)
/workspace-init ──marks──▶ <workspace>/_meta/ (sidecar git repo, no remote) + workspace.json
resolve-data-root.sh ──answers──▶ mode + data_root   (run FIRST by every skill/hook)
sidecar-memory-context.sh ──SessionStart──▶ injects _meta memory (workspace tier, then repo tier)
/project-log  ──writes──▶ action-items.md · decisions-log.md · resolved.md   (propagated: appends Propagated-to: lines)
/project-plan ──writes──▶ ideas.md
/handoff      ──writes──▶ project-tracking/handoffs/<slug>.md   (live per-effort record; refreshed on re-pause, deleted on done)
/work-journal ──reads──▶ git history × tracking   (summary; log mode appends work-log.md)
/ingest       ──writes──▶ docs/memory/<slug>.md + MEMORY.md index
/memory-lint  ──checks──▶ docs/memory/ index + wikilink integrity
/memory-search ──queries──▶ docs/memory/ facts, by keyword or backlinks   (read-only)
/memory-sync  ──migrates▶ a ~/.claude fact ──▶ docs/memory/
/memory-adopt ──reshapes▶ existing docs ──▶ docs/memory/  (+ proposed CLAUDE.md trim)
/tracking-adopt ──routes──▶ existing roadmap/TODO docs ──▶ docs/project-tracking/  (git mode: merged history ──▶ resolved.md)
/project-status ──reads──▶ docs/project-tracking/ (all four files; read-only report/brief)
/project-status matrix ──groups──▶ a workspace's checkouts by origin URL (scripts/checkout-groups.sh) × Propagated-to: lines
/guardrails   ──authors──▶ guardrails.json rules via scripts/guardrails-upsert.sh   (dry-run proven, confirm-gated)
/guardrails pack ──imports──▶ packs/<name>.json via scripts/pack-import.sh   (per-rule pack stamp + _packs ledger; idempotent)
/playbook     ──writes──▶ docs/playbooks/<slug>.md   (adopt reshapes an existing how-to doc)
/continuity   ──scaffolds▶ <repo>/CONTINUITY.md   (bus-factor runbook)
guardrail.sh  ──reads──▶ <repo>/.claude/guardrails.json   (PreToolUse deny/warn on Bash|Edit|Write)
playbook-surface.sh ──surfaces──▶ a matching playbook, once per session   (PreToolUse deny-once or PostToolUse context)
dispatch-ledger.sh ──appends──▶ ~/.claude/workspace-os/dispatch-ledger.jsonl   (PostToolUse on dispatches; sizes only, local-only)
capture-cadence.sh ──SessionStart──▶ capture nudge + live handoffs list
  tracking skills ──read──▶ conventions/project-tracking.md   (schema + lifecycle, SoT)
  memory skills   ──read──▶ conventions/memory.md             (schema + boundary test, SoT)
```

- **The guardrail engine** (`hooks/guardrail.sh`) is a PreToolUse hook: built-in warn advisories
  (possible secrets, force-push, `rm -rf`) and hard denies for high-confidence secrets, plus
  declarative per-repo rules in `.claude/guardrails.json` (`bash`/`write` rules, `deny` blocks /
  `warn` advises). Rules are authored conversationally via `/guardrails` (every write goes through
  `scripts/guardrails-upsert.sh`) or imported as versioned **policy packs** from `packs/<name>.json`
  via `/guardrails pack` (format SoT: `conventions/packs.md`; imported rules carry a `pack` stamp so
  re-import replaces only them, never hand-authored rules). The engine fails open when the config is
  absent. Same engine/data split as the rest of the plugin.
- **Skills** are model-interpreted instructions (`SKILL.md`). They contain no rules of their own
  beyond orchestration — the schema, ID scheme, and lifecycle live once in
  `conventions/project-tracking.md`, so there's no drift.
- **Templates** are the empty scaffolds `/project-init` copies into a new repo.
- **Data** never lives in this plugin — it lives in each target repo.

## Why a plugin, not a template repo

A template is a one-time scaffold that goes stale. A plugin is carried and updated centrally, so
every project on every machine gets an improvement the moment it lands. The bootstrap value of a
template is folded into `/project-init`.
