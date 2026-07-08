---
name: memory-sync
description: Migrate an existing fact from your personal ~/.claude auto-memory into a repo's shared docs/memory/. Use when a fact that landed in personal auto-memory is really project knowledge that belongs with the repo and its collaborators.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "<auto-memory fact name or description to migrate>"
---

# Memory Sync

Bridge: move ONE fact from the user's personal `~/.claude` auto-memory into THIS repo's shared
`<data_root>/memory/` (`docs/memory/` in in-repo mode), with confirmation. Schema, types, and the
boundary test live in this plugin's `conventions/memory.md`.

Direction is **one-way (personal → repo) by design**: git already carries repo memory across
machines, so this skill exists only to relocate facts that landed in the wrong store (including
ones auto-saved to `~/.claude` mid-session).

**Prerequisite:** the repo must have `<data_root>/memory/` (run `/project-init` if not).

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in BOTH modes; never
   hardcode `docs/…`. Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).

1. **Locate the source fact.** Auto-memory lives in the session's memory directory (the
   `~/.claude/.../memory/` dir referenced in this session's context). Find the file matching the
   user's argument by `name`/`description`. If ambiguous, list candidates and ask. If the exact
   path is unclear, use Bash to locate the file (e.g. `ls`/`grep` under the session's memory
   directory).
2. **Apply the boundary test + pick a type** (conventions/memory.md). Confirm it's genuinely
   repo-scoped knowledge — not an always-load instruction (→ CLAUDE.md), not a decision
   (→ decisions-log), not work-state like a goal/status/intent (→ tracking: `ideas.md`/`action-items.md`).
   If it fails, say so and stop.
3. **Secret scan.** Refuse if the fact contains secrets — look for patterns such as `api_key=`, tokens, bearer values, `.env`-style `KEY=value` credentials, or anything that looks like a credential value.
4. **Translate the schema.** Auto-memory frontmatter (`name` / `description` / `metadata.type`)
   → repo fact schema (`name` / `description` / `type`), using the **gates + type hints + slug
   rule** in `conventions/memory.md` (the two taxonomies differ; re-slug to clean kebab, and note
   some types — e.g. `user` — should not migrate).
5. **Confirm with the user** the exact target file path and translated content before writing.
6. **Write** `<data_root>/memory/<slug>.md` and append the index line to `MEMORY.md` (per
   conventions).
7. **Offer cleanup** — ask whether to remove the original auto-memory file (and its `MEMORY.md`
   index line) or leave it. **Default: leave it;** only remove on explicit confirmation.
8. **Report** what moved and where. Do **not** commit.
