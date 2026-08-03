---
name: ingest
description: Capture a durable project fact into this repo's shared memory. Use when the user states a non-obvious fact about THIS codebase worth keeping — architecture rationale, a domain rule, a gotcha to look up later (not an always-needed instruction), or a reference pointer. Writes a fact file under docs/memory/ and updates the index.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "<the fact to remember>  (e.g. \"we use Auth.js v5 beta because X\")"
---

# Ingest

Author a durable fact into this repo's canonical shared memory at `<data_root or chosen
tier>/memory/` (`docs/memory/` in in-repo mode). The schema, types, the CLAUDE.md-vs-memory
boundary test, the index format, and the retrieval model all live in this plugin's
`conventions/memory.md` — read it and follow it exactly; do not restate the rules here.

**Prerequisite — resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and parse `mode`/`data_root`
(+ `workspace_root` in sidecar mode) — see `conventions/data-root.md`. Memory lives at
`<data_root>/memory/`; if that directory is missing, stop and say so (run `/project-init`
first). Announce the resolved mode in your report. In sidecar mode never write inside the
repo's working tree.

## Steps

0. **Gotcha trigger (stale-prior flavor).** If the argument begins with `gotcha:` or `stale-prior:`
   (case-insensitive), strip the keyword and set a `gotcha` flag; the remainder is a stale-prior
   fact ("training prior says X; here it is actually Y"). See `conventions/memory.md` § Recurring
   flavors for the two body shapes. If the trigger is absent, ignore this step and proceed normally
   (no behavior change).
1. **Apply the boundary test** (conventions/memory.md): "If the model didn't see this until it
   went looking, would it make a costly mistake first?"
   - If it's a **decision** (a choice + why), it belongs in `decisions-log.md` - offer
     `/project-log decision` instead and stop.
   - **YES (costly-first), not a gotcha:** belongs in CLAUDE.md, not memory - tell the user and stop.
   - **YES (costly-first), gotcha, in-repo mode:** build the imperative bullet (conventions §
     Recurring flavors): `- <topic>: use <Y>, NOT <X> (training prior is wrong here). <why/[[link]]>`.
     Resolve the repo AGENTS.md path (`git rev-parse --show-toplevel`/AGENTS.md, else
     `$CLAUDE_PROJECT_DIR`/`$PWD`). If AGENTS.md does not exist, note that the base may not be
     portable yet and suggest `/make-portable`, then proceed to create/append via the helper (it
     creates the managed section if absent). Grep the managed section for a same-topic bullet; if
     one exists with different content, surface it and ask (add-anyway vs edit-by-hand) rather than
     auto-editing.
     Secret-scan the bullet first (the same rule as Step 5): if it contains a key, token, or
     `.env`-style value, refuse and stop without writing or displaying it.
     Show the exact bullet + the AGENTS.md path and get explicit confirmation, then run
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/claude-md-upsert.sh" "<agents_md>" "## Stale priors (training vs reality)" "<bullet>"`.
     Report the script's status word (`created section` / `appended` / `skipped: already present`)
     and stop.
   - **YES (costly-first), gotcha, sidecar mode:** the repo CLAUDE.md must not be touched in a
     sidecar workspace - tell the user the bullet belongs in the repo's CLAUDE.md and to add it by
     hand, and stop.
   - **NO (consult-when-relevant):** continue to the steps below and write a `docs/memory/` fact. If
     this is a gotcha, use the gotcha body shape (conventions § Recurring flavors): `type: convention`
     unless clearly `domain`; `description: training prior wrong for <topic>`; body `Training prior
     says <X>. In this repo it is actually <Y>. Why: <reason>. See [[<related>]].`
2. **Apply the tier test (sidecar mode only)** — conventions/memory.md § two-tier memory:
   "would this fact be just as true and useful in every repo of this workspace?" Default is
   the **repo tier** (`<data_root>/memory/`). If the test clearly passes, PROPOSE the
   workspace tier (`<workspace_root>/memory/`) and let the user confirm. An explicit user
   scope request ("workspace level", "just this repo") always wins. In in-repo mode skip
   this step. All later steps use the chosen tier's `memory/` dir and its `MEMORY.md`.
3. **Pick the type** — `domain | convention | reference` (see conventions). Ask only if unclear.
4. **Mint the slug** — short kebab-case from the fact's gist; ensure no existing
   `<data_root or chosen tier>/memory/<slug>.md` collision (suffix `-2`, etc. if needed). The
   `name:` frontmatter must equal the filename stem.
5. **Secret scan** — never write keys/tokens/`.env`-style values. If the fact contains one,
   refuse and tell the user.
6. **Write the fact file** `<data_root or chosen tier>/memory/<slug>.md` using the fact schema
   from conventions (frontmatter `name`/`description`/`type` + body; link related facts/decisions
   with `[[wikilink]]`).
7. **Update the index** — append `- [<name>](<slug>.md) — <hook>` under the matching type
   section in `<data_root or chosen tier>/memory/MEMORY.md` (replace a `_No facts yet._`
   placeholder if present).
8. **Commit (sidecar mode only)** — `git -C <workspace_root> add -A` then commit with message
   `ingest(<repo-folder-name or workspace>): <slug>`. In in-repo mode do not commit unless asked.
9. **Report** the file written, the tier chosen (sidecar), and the index line added.
