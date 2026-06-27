---
name: ingest
description: Capture a durable project fact into this repo's shared memory. Use when the user states a non-obvious fact about THIS codebase worth keeping — architecture rationale, a domain rule, a gotcha to look up later (not an always-needed instruction), or a reference pointer. Writes a fact file under docs/memory/ and updates the index.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "<the fact to remember>  (e.g. \"we use Auth.js v5 beta because X\")"
---

# Ingest

Author a durable fact into this repo's canonical shared memory at `docs/memory/`. The schema,
types, the CLAUDE.md-vs-memory boundary test, the index format, and the retrieval model all live
in this plugin's `conventions/memory.md` — read it and follow it exactly; do not restate the
rules here.

**Prerequisite:** the repo must have `docs/memory/` (run `/project-init` if not). If it's
missing, stop and say so.

## Steps

1. **Apply the boundary test** (conventions/memory.md): "If the model didn't see this until it
   went looking, would it make a costly mistake first?" If **YES**, this belongs in CLAUDE.md,
   not memory — tell the user and stop. If it's a **decision** (a choice + why), it belongs in
   `decisions-log.md` — offer `/project-log decision` instead and stop.
2. **Pick the type** — `domain | convention | reference` (see conventions). Ask only if unclear.
3. **Mint the slug** — short kebab-case from the fact's gist; ensure no existing
   `docs/memory/<slug>.md` collision (suffix `-2`, etc. if needed). The `name:` frontmatter
   must equal the filename stem.
4. **Secret scan** — never write keys/tokens/`.env`-style values. If the fact contains one,
   refuse and tell the user.
5. **Write the fact file** `docs/memory/<slug>.md` using the fact schema from conventions
   (frontmatter `name`/`description`/`type` + body; link related facts/decisions with
   `[[wikilink]]`).
6. **Update the index** — append `- [<name>](<slug>.md) — <hook>` under the matching type
   section in `docs/memory/MEMORY.md` (replace a `_No facts yet._` placeholder if present).
7. **Report** the file written and the index line added. Do **not** commit unless asked.
