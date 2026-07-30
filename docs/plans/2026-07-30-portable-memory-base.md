# Portable Memory Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every memory base workspace-os produces self-describing and vendor-neutral, so a cold non-Claude agent can read and maintain it with plain file operations.

**Architecture:** A deterministic, tested helper `scripts/stamp-portable-layer.sh` copies a portable operator's manual and vendors `memory_graph.py` into a base, and (in-repo) ensures `AGENTS.md` + a `CLAUDE.md` bridge exist. Both `/project-init` and the new `/make-portable` skill are thin callers of that helper. `AGENTS.md` becomes the canonical always-loaded home; the shipped `/ingest gotcha:` write retargets there. All new content is vendor-neutral prose; the plugin, skills, and hooks stay Claude-only.

**Tech Stack:** Bash (helper + plain-bash test harness), Markdown (templates/manual/skills), stdlib Python (`memory_graph.py`, vendored not modified), `scripts/validate-plugin.py`.

## Global Constraints

- **No em dashes (U+2014)** anywhere in added code, script output, templates, skill/convention/doc text, or commit messages. Plain ASCII only (hyphens, `->`).
- **Add-only and idempotent** for every stamping operation: never modify or reorder existing facts, the `MEMORY.md` index, or existing lines; a re-run adds nothing new. Exit non-zero only on bad args or a missing source / unwritable destination.
- **Sidecar safety invariant:** in sidecar mode never create, modify, or stage any file inside the repo's working tree. All portable-layer files go under `_meta/`.
- **No new runtime dependencies.** Pure bash + coreutils (like `claude-md-upsert.sh` / `resolve-data-root.sh`); tests stay plain bash. `memory_graph.py` is copied verbatim, never edited.
- **Canonical always-loaded file is `AGENTS.md`** (in-repo). `CLAUDE.md` is a bridge that imports `@AGENTS.md` and `@docs/memory/MEMORY.md`. Costly-first facts (including the gotcha write) target `AGENTS.md` in-repo.
- **Managed AGENTS.md heading (exact):** `## Stale priors (training vs reality)` (same string the shipped gotcha feature and `claude-md-upsert.sh` use).
- **Manual filename:** `docs/memory/README.md` in-repo; `_meta/conventions/memory-base-guide.md` sidecar.
- **Vendored validator path:** `docs/tools/memory_graph.py` in-repo; `_meta/tools/memory_graph.py` sidecar. The validator is tooling, kept OUT of the memory fact folder; sidecar matches the existing `_meta/tools/` convention (e.g. `nbtool.py`). The manual (`README.md`) stays in the base folder. `memory_graph.py`'s `--root` defaults to `docs/memory` relative to the working directory, so `python docs/tools/memory_graph.py --check` from the repo root still resolves correctly.
- **Version bump on completion:** minor (`0.15.0 -> 0.16.0`).
- **Record IDs (today's date):** action `A-20260730-portable-memory-base`; decision `D-20260730-agents-md-canonical`.
- **Read-only elsewhere:** do not modify `scripts/memory_graph.py` (only copy it), `scripts/claude-md-upsert.sh`, `tests/test-claude-md-upsert.sh`, or unrelated skills.

---

### Task 1: The portable templates (operator's manual + AGENTS.md) and MEMORY.md header repoint

Static content the helper later copies. TDD via content-assertion: write a test that greps for required sections, watch it fail, then create the templates.

**Files:**
- Create: `templates/memory/README.md` (the operator's manual)
- Create: `templates/AGENTS.md` (the vendor-neutral entry point)
- Modify: `templates/memory/MEMORY.md` (repoint the header from the plugin cache to `./README.md`)
- Create: `tests/test-portable-templates.sh`

**Interfaces:**
- Produces: `templates/memory/README.md`, `templates/AGENTS.md` (copied verbatim by `stamp-portable-layer.sh` in Task 2). `AGENTS.md` MUST contain the exact managed heading `## Stale priors (training vs reality)`.

- [ ] **Step 1: Write the failing test harness**

Create `tests/test-portable-templates.sh`:

```bash
#!/usr/bin/env bash
# Content assertions for the portable templates (deps: bash + coreutils only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
MAN="$ROOT/templates/memory/README.md"
AGENTS="$ROOT/templates/AGENTS.md"
IDX="$ROOT/templates/memory/MEMORY.md"
pass=0; fail=0
assert() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }
has() { grep -qF -e "$2" "$1"; }
hasre() { grep -qE -e "$2" "$1"; }

# manual exists and covers the required sections
[ -f "$MAN" ]; assert "manual exists" $?
has "$MAN" "name:"; assert "manual: schema frontmatter" $?
hasre "$MAN" "domain \| convention \| reference|domain, convention"; assert "manual: type vocabulary" $?
has "$MAN" "AGENTS.md"; assert "manual: boundary names AGENTS.md" $?
has "$MAN" "memory_graph.py --check"; assert "manual: validator command" $?
has "$MAN" "[[supersedes::"; assert "manual: typed wikilink grammar" $?
has "$MAN" "broken wikilink"; assert "manual: validator checks in prose" $?
has "$MAN" "source-verified"; assert "manual: provenance tiers" $?
has "$MAN" "/ingest"; assert "manual: names the Claude shortcut" $?

# AGENTS.md exists, thin entry point with the managed section
[ -f "$AGENTS" ]; assert "agents exists" $?
has "$AGENTS" "docs/memory/MEMORY.md"; assert "agents: points to index" $?
has "$AGENTS" "docs/memory/README.md"; assert "agents: points to manual" $?
has "$AGENTS" "## Stale priors (training vs reality)"; assert "agents: managed gotcha heading" $?
has "$AGENTS" "Always-loaded"; assert "agents: always-loaded section" $?

# MEMORY.md header points at the local manual, not the plugin cache
has "$IDX" "./README.md"; assert "index header points at local manual" $?
grep -qF "conventions/memory.md" "$IDX" && { echo "FAIL: index still points at plugin cache"; fail=$((fail+1)); } || { echo "PASS: index no plugin-cache pointer"; pass=$((pass+1)); }

# no em dashes in the new templates
for f in "$MAN" "$AGENTS"; do
  if grep -qP '\x{2014}' "$f"; then echo "FAIL: em dash in $f"; fail=$((fail+1)); else echo "PASS: no em dash in $(basename "$f")"; pass=$((pass+1)); fi
done

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-portable-templates.sh`
Expected: FAIL (templates do not exist yet; most asserts fail).

- [ ] **Step 3: Create the operator's manual**

Create `templates/memory/README.md`:

```markdown
# Memory base - operator's manual

This directory is a durable, version-controlled knowledge base about this codebase. It is plain
markdown: one fact per file, plus a hand-curated index (`MEMORY.md`). No database, no vector store,
no proprietary index. Any agent or human can read and maintain it with basic file operations.

The Claude Code plugin `workspace-os` provides shortcuts (`/ingest`, `/memory-lint`, `/memory-search`)
that automate the steps below. You do not need them. This manual is the whole procedure.

## The fact schema

Each fact is one file, `<slug>.md`, where `<slug>` is short-kebab-case:

```
---
name: <slug>            # MUST equal the filename stem
description: <one-line summary used to judge relevance at recall>
type: domain | convention | reference
---

<the fact. Cite evidence (file:line). Link related facts/records with [[wikilink]].>
```

Types: `domain` (architecture, structure, domain model), `convention` (how-we-do-it-here),
`reference` (pointers to external resources). Decisions (a choice + why) do NOT go here; they belong
in the project-tracking decisions log.

## Where a fact belongs (the boundary rule)

> "If an agent would make a costly mistake before it went looking, the fact must be seen up front."

- **Costly-if-unseen -> your always-loaded instruction file.** That is `AGENTS.md` (read by most
  agents) or, for Claude Code, `CLAUDE.md`. In this repo `CLAUDE.md` imports `AGENTS.md`, so
  `AGENTS.md` is the single canonical home. Put such facts there as imperative bullets.
- **Only needed when the topic comes up -> this base**, read on demand.

## How to add a fact (what `/ingest` automates)

1. Apply the boundary rule. If costly-first, write an imperative bullet in `AGENTS.md` instead and stop.
2. Otherwise write `docs/memory/<slug>.md` with the frontmatter above; `name:` must match the stem.
3. Add one line to `MEMORY.md` under the matching type section:
   `- [<name>](<slug>.md) - <hook from the description>`
4. Never write secrets (keys, tokens, `.env` values).

## The wikilink grammar

- Plain `[[target]]` - a "related" edge.
- Typed predicate `[[supersedes::target]]`, `[[blocked_by::target]]`, `[[depends_on::target]]`, etc.
- Aliased `[[type::target|label]]`.
- Targets may be fact slugs or tracking records (`A-...`, `D-...`).

## Checking integrity (what `/memory-lint` automates)

Run the vendored validator (stdlib Python, no dependencies), which lives in the base's `tools/`
folder (separate from the fact files):

`python docs/tools/memory_graph.py --check`

run from the repo root (its default `--root` is `docs/memory`). In a sidecar `_meta` layout run
`python _meta/tools/memory_graph.py --check --root _meta/memory` and `--root _meta/<repo>/memory`,
with `--link-root` for cross-tier links. It reports and exits non-zero
on any of these, which you can also verify by hand:

- **broken wikilink** - a `[[target]]` whose target has no fact file and is not a known tracking record.
- **index parity** - every fact file has exactly one `MEMORY.md` line, and every line has a file.
- **orphans** - facts nothing links to (informational).
- **typed-edge coverage** - how many links carry a predicate (informational).

## Provenance

Two trust tiers, marked in the fact body:
- **source-verified** - distilled from something an agent actually read (code, a CLI, a captured file).
- **attested** - from a person or a console the agent could not reach; include a re-verify command if
  one exists and a dated stamp.

## Deferred (not yet portable)

Project-tracking records (`action-items`, `decisions-log`) are maintained the same plain-markdown way
but their schema is not yet documented here. Enforcement hooks (guardrails, auto-lint) are Claude Code
runtime features and do not travel; a successor agent has the data and this procedure, not the automation.
```

- [ ] **Step 4: Create the AGENTS.md template**

Create `templates/AGENTS.md`:

```markdown
# Agent Instructions

This repo keeps a durable knowledge base under `docs/memory/`. It is plain markdown, readable and
maintainable by any agent or human without special tooling.

## Before working here
- Read `docs/memory/MEMORY.md` first - the index of what is known about this codebase (one line per
  fact). Open the specific fact files it lists when relevant.
- `docs/memory/README.md` is the operator's manual: the schema, and how to read, verify, and add
  facts with plain file operations (no plugin, no slash commands).

## Maintaining the base
- Add a fact: follow the procedure in `docs/memory/README.md`.
- Check integrity: `python docs/tools/memory_graph.py --check` (stdlib Python, no dependencies).

## Always-loaded instructions
<!-- Costly-if-unseen facts - ones an agent must see BEFORE acting or it makes a wrong move first -
     go here as imperative bullets. Empty until the first such fact is recorded. -->

## Stale priors (training vs reality)
<!-- Managed section. Bullets of the form: "<topic>: use <Y>, NOT <X> (training prior is wrong here)."
     Written by the workspace-os /ingest gotcha: shortcut, or by hand following the same shape. -->
```

- [ ] **Step 5: Repoint the MEMORY.md template header**

Read `templates/memory/MEMORY.md`. Its header currently points readers at the plugin's
`conventions/memory.md` for the schema. Replace that pointer with a pointer to the local manual.
Change the schema-pointer line so it reads (keep the rest of the template intact):

```markdown
> Schema and how to maintain this base: see `./README.md` (the operator's manual). It is
> self-contained - no plugin required.
```

Remove any line that directs the reader to the plugin's `conventions/memory.md`.

- [ ] **Step 6: Run the harness to verify it passes**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-portable-templates.sh`
Expected: final line `N passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add templates/memory/README.md templates/AGENTS.md templates/memory/MEMORY.md tests/test-portable-templates.sh
git commit -m "feat(memory): portable operator's manual + AGENTS.md templates"
```

---

### Task 2: The `stamp-portable-layer.sh` helper + tests

The deterministic core shared by `/project-init` and `/make-portable`. TDD: harness first.

**Files:**
- Create: `scripts/stamp-portable-layer.sh`
- Create: `tests/test-stamp-portable-layer.sh`

**Interfaces:**
- Consumes: `templates/memory/README.md`, `templates/AGENTS.md` (Task 1), and the sibling `scripts/memory_graph.py`.
- Produces: `scripts/stamp-portable-layer.sh`, invoked with flags:
  `--manual-dest <path> --graph-dest <path> [--agents <path>] [--claude-bridge <path>] [--manual-template <path>] [--agents-template <path>] [--graph-src <path>]`.
  Copies manual + validator to the dests (add-only: skip if the dest exists); if `--agents` given, ensures that file exists (copy the AGENTS template if absent, else leave); if `--claude-bridge` given, ensures the two lines `@AGENTS.md` and `@docs/memory/MEMORY.md` are present (append missing ones, create the file if absent, never duplicate). Template/source flags default to the plugin-relative paths and exist for test isolation. Prints one status line per action. Exit 0 on success (including all-idempotent), 2 on bad args, 1 on missing source template or unwritable destination.

- [ ] **Step 1: Write the failing test harness**

Create `tests/test-stamp-portable-layer.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash tests for scripts/stamp-portable-layer.sh (deps: bash + coreutils only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/../scripts/stamp-portable-layer.sh"
MANT="$HERE/../templates/memory/README.md"
AGT="$HERE/../templates/AGENTS.md"
GSRC="$HERE/../scripts/memory_graph.py"
pass=0; fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
assert() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }
countF() { grep -cF -e "$2" "$1" 2>/dev/null || echo 0; }

# case 1: in-repo full stamp into a fresh base (validator goes to docs/tools/)
d="$TMP/repo1"; mkdir -p "$d/docs/memory"
out="$(bash "$S" --manual-dest "$d/docs/memory/README.md" --graph-dest "$d/docs/tools/memory_graph.py" \
  --agents "$d/AGENTS.md" --claude-bridge "$d/CLAUDE.md")"; ec=$?
[ "$ec" = 0 ]; assert "in-repo: exit 0" $?
[ -f "$d/docs/memory/README.md" ]; assert "in-repo: manual copied" $?
[ -f "$d/docs/tools/memory_graph.py" ]; assert "in-repo: graph vendored to tools/" $?
[ -f "$d/AGENTS.md" ]; assert "in-repo: AGENTS.md created" $?
grep -qF "## Stale priors (training vs reality)" "$d/AGENTS.md"; assert "in-repo: AGENTS managed heading" $?
grep -qF "@AGENTS.md" "$d/CLAUDE.md"; assert "in-repo: bridge @AGENTS.md" $?
grep -qF "@docs/memory/MEMORY.md" "$d/CLAUDE.md"; assert "in-repo: bridge @index" $?

# case 2: idempotent re-run adds nothing, no dup bridge lines, files unchanged
before="$(cat "$d/CLAUDE.md")"
out="$(bash "$S" --manual-dest "$d/docs/memory/README.md" --graph-dest "$d/docs/tools/memory_graph.py" \
  --agents "$d/AGENTS.md" --claude-bridge "$d/CLAUDE.md")"; ec=$?
[ "$ec" = 0 ]; assert "rerun: exit 0" $?
[ "$(countF "$d/CLAUDE.md" "@AGENTS.md")" = 1 ]; assert "rerun: bridge not duplicated" $?
[ "$before" = "$(cat "$d/CLAUDE.md")" ]; assert "rerun: CLAUDE.md unchanged" $?

# case 3: pre-existing CLAUDE.md with only the index import -> bridge adds only @AGENTS.md
d3="$TMP/repo3"; mkdir -p "$d3/docs/memory"; printf '# Proj\n\n@docs/memory/MEMORY.md\n' > "$d3/CLAUDE.md"
bash "$S" --manual-dest "$d3/docs/memory/README.md" --graph-dest "$d3/docs/tools/memory_graph.py" \
  --agents "$d3/AGENTS.md" --claude-bridge "$d3/CLAUDE.md" >/dev/null; ec=$?
[ "$ec" = 0 ]; assert "existing-claude: exit 0" $?
[ "$(countF "$d3/CLAUDE.md" "@docs/memory/MEMORY.md")" = 1 ]; assert "existing-claude: index not duplicated" $?
[ "$(countF "$d3/CLAUDE.md" "@AGENTS.md")" = 1 ]; assert "existing-claude: agents added once" $?

# case 4: sidecar-style call (manual to conventions/, graph to tools/, no agents/bridge)
d4="$TMP/meta"; mkdir -p "$d4/conventions" "$d4/tools"
out="$(bash "$S" --manual-dest "$d4/conventions/memory-base-guide.md" --graph-dest "$d4/tools/memory_graph.py")"; ec=$?
[ "$ec" = 0 ]; assert "sidecar: exit 0" $?
[ -f "$d4/conventions/memory-base-guide.md" ]; assert "sidecar: guide copied" $?
[ -f "$d4/tools/memory_graph.py" ]; assert "sidecar: graph vendored to tools/" $?
[ ! -f "$d4/AGENTS.md" ]; assert "sidecar: no AGENTS.md written" $?

# case 5: existing manual dest is left as-is (add-only)
d5="$TMP/repo5"; mkdir -p "$d5/docs/memory"; printf 'SENTINEL\n' > "$d5/docs/memory/README.md"
bash "$S" --manual-dest "$d5/docs/memory/README.md" --graph-dest "$d5/docs/memory/memory_graph.py" >/dev/null
grep -qF "SENTINEL" "$d5/docs/memory/README.md"; assert "add-only: existing manual preserved" $?

# case 6: missing source template -> exit 1
bash "$S" --manual-dest "$TMP/x/README.md" --graph-dest "$TMP/x/g.py" --manual-template "$TMP/nope.md" >/dev/null 2>&1
[ "$?" = 1 ]; assert "missing-src: exit 1" $?

# case 7: bad args -> exit 2
bash "$S" --manual-dest "$TMP/y/README.md" >/dev/null 2>&1; [ "$?" = 2 ]; assert "badargs: exit 2" $?

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-stamp-portable-layer.sh`
Expected: FAIL / nonzero (the script does not exist yet).

- [ ] **Step 3: Implement the helper**

Create `scripts/stamp-portable-layer.sh`:

```bash
#!/usr/bin/env bash
# Stamp the portable (vendor-neutral) layer into a memory base. Deterministic core shared by
# /project-init and /make-portable. Add-only and idempotent: copies the operator's manual and the
# vendored validator into the base, and (in-repo) ensures AGENTS.md + the CLAUDE.md bridge imports
# exist. Never modifies facts or the index. The confirm gate, mode resolution, and index/INDEX
# enrichment are the caller's job.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manual_template="$here/../templates/memory/README.md"
agents_template="$here/../templates/AGENTS.md"
graph_src="$here/memory_graph.py"
manual_dest=""; graph_dest=""; agents=""; claude_bridge=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manual-dest) manual_dest="$2"; shift 2;;
    --graph-dest) graph_dest="$2"; shift 2;;
    --agents) agents="$2"; shift 2;;
    --claude-bridge) claude_bridge="$2"; shift 2;;
    --manual-template) manual_template="$2"; shift 2;;
    --agents-template) agents_template="$2"; shift 2;;
    --graph-src) graph_src="$2"; shift 2;;
    *) echo "usage: stamp-portable-layer.sh --manual-dest P --graph-dest P [--agents P] [--claude-bridge P]" >&2; exit 2;;
  esac
done
if [ -z "$manual_dest" ] || [ -z "$graph_dest" ]; then
  echo "usage: stamp-portable-layer.sh --manual-dest P --graph-dest P [--agents P] [--claude-bridge P]" >&2
  exit 2
fi

copy_if_absent() { # src dest label
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$src" ] || [ ! -r "$src" ]; then echo "error: missing source: $src" >&2; exit 1; fi
  if [ -f "$dest" ]; then echo "$label: exists"; return 0; fi
  mkdir -p "$(dirname "$dest")" || { echo "error: cannot create dir for $dest" >&2; exit 1; }
  cp "$src" "$dest" || { echo "error: cannot write $dest" >&2; exit 1; }
  echo "$label: created"
}

copy_if_absent "$manual_template" "$manual_dest" "manual"
copy_if_absent "$graph_src" "$graph_dest" "graph"

if [ -n "$agents" ]; then
  copy_if_absent "$agents_template" "$agents" "agents"
fi

if [ -n "$claude_bridge" ]; then
  if [ ! -f "$claude_bridge" ]; then
    mkdir -p "$(dirname "$claude_bridge")" || { echo "error: cannot create dir for $claude_bridge" >&2; exit 1; }
    printf '# Project instructions\n\n' > "$claude_bridge" || { echo "error: cannot write $claude_bridge" >&2; exit 1; }
  fi
  for line in "@AGENTS.md" "@docs/memory/MEMORY.md"; do
    if grep -qF -e "$line" "$claude_bridge"; then
      echo "bridge: present $line"
    else
      printf '%s\n' "$line" >> "$claude_bridge"
      echo "bridge: added $line"
    fi
  done
fi

exit 0
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-stamp-portable-layer.sh`
Expected: final line `N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add scripts/stamp-portable-layer.sh tests/test-stamp-portable-layer.sh
git commit -m "feat(memory): add stamp-portable-layer.sh (shared portable-layer stamper)"
```

---

### Task 3: `/project-init` stamps the portable layer (both modes)

Wire the helper into project-init and repoint the CLAUDE.md step to the bridge. Prose skill; verified by `validate-plugin.py` and the controller's live dogfood.

**Files:**
- Modify: `skills/project-init/SKILL.md`

**Interfaces:**
- Consumes: `scripts/stamp-portable-layer.sh` (Task 2).
- Produces: `/project-init` leaving a portable base (manual + vendored validator + AGENTS.md + CLAUDE.md bridge in-repo; manual + validator under `_meta/conventions/` + enriched `INDEX.md` in sidecar).

- [ ] **Step 1: Replace the retrieval-wiring step with the portable-layer stamp**

In `skills/project-init/SKILL.md`, replace step `3b` (the `**Wire retrieval** *(in-repo only)*` step that currently only adds `@docs/memory/MEMORY.md`) with:

```markdown
3b. **Stamp the portable layer.** Run the shared stamper so the base is self-describing and
    vendor-neutral. `${CLAUDE_PLUGIN_ROOT}` is this plugin's root.
    - *(in-repo)*:
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest docs/memory/README.md --graph-dest docs/tools/memory_graph.py --agents AGENTS.md --claude-bridge CLAUDE.md`
      This copies the operator's manual (into the base folder) and vendors `memory_graph.py` (into
      `docs/tools/`, separate from the facts), creates `AGENTS.md` (the vendor-neutral entry point,
      canonical home for costly-first facts), and ensures `CLAUDE.md` imports `@AGENTS.md` and
      `@docs/memory/MEMORY.md` (the bridge). Add-only and idempotent.
    - *(sidecar)*: run with only the copy dests under `_meta/` (never the repo tree):
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest <workspace_root>/conventions/memory-base-guide.md --graph-dest <workspace_root>/tools/memory_graph.py`
      (the guide with the other playbooks in `conventions/`; the validator in `tools/` next to any
      existing tools). Then enrich `<workspace_root>/INDEX.md`: add a pointer to
      `conventions/memory-base-guide.md` as the schema/how-to source and a one-line "Link grammar"
      note. Do not create a repo `AGENTS.md`/`CLAUDE.md` in sidecar mode.
```

- [ ] **Step 2: Update the Notes section pointer**

In `skills/project-init/SKILL.md` Notes, change the line that says memory schema/rules live in
`conventions/memory.md` to also note that each base now carries a self-contained operator's manual
(`docs/memory/README.md` in-repo, `_meta/conventions/memory-base-guide.md` sidecar) stamped by the
portable-layer step, and that `AGENTS.md` is the canonical always-loaded file (`CLAUDE.md` bridges to it).

- [ ] **Step 3: Verify the plugin validates**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py`
Expected: passes (exit 0).

- [ ] **Step 4: Controller live dogfood (recorded in the task report)**

Because `/project-init` is `disable-model-invocation: true`, the controller (not a subagent) drives it: on a scratch in-repo git repo, follow the updated steps and confirm the stamper produces `docs/memory/README.md`, `docs/tools/memory_graph.py`, `AGENTS.md` (with the managed heading), and a `CLAUDE.md` containing both bridge imports; a second run adds nothing. On a scratch sidecar workspace, confirm the guide lands under `_meta/conventions/` and the validator under `_meta/tools/`, `INDEX.md` gains the pointers, and the repo working tree is untouched. Record the outcome in the task report.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add skills/project-init/SKILL.md
git commit -m "feat(memory): /project-init stamps the portable layer + CLAUDE.md bridge"
```

---

### Task 4: The `/make-portable` retrofit skill

A thin skill that adds the portable layer to an already-initialized base. Prose skill; verified by `validate-plugin.py` and controller dogfood.

**Files:**
- Create: `skills/make-portable/SKILL.md`

**Interfaces:**
- Consumes: `scripts/stamp-portable-layer.sh` (Task 2), `scripts/resolve-data-root.sh`.
- Produces: `/make-portable` adding the portable layer to an existing base, add-only, both modes.

- [ ] **Step 1: Write the skill**

Create `skills/make-portable/SKILL.md`:

```markdown
---
name: make-portable
description: Add the portable (vendor-neutral) layer to an already-initialized memory base so a non-Claude agent can read and maintain it. Stamps the operator's manual, vendors memory_graph.py, and (in-repo) ensures AGENTS.md + the CLAUDE.md bridge. Add-only and idempotent; never touches facts or the index.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
argument-hint: "(no args - operates on the current repo's resolved memory base)"
---

# Make Portable

Add the vendor-neutral portable layer to an EXISTING memory base. Idempotent and add-only: it never
modifies facts or the `MEMORY.md` index. For a brand-new repo use `/project-init` instead (it stamps
this layer as part of bootstrap).

## Steps

1. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and
   parse `mode`/`data_root` (+ `workspace_root` in sidecar). Announce the mode.
2. **Refuse if there is no base.** If `<data_root>/memory/` does not exist, stop and point the user
   at `/project-init`.
3. **Stamp the portable layer** via the shared stamper:
   - *(in-repo)*:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest docs/memory/README.md --graph-dest docs/tools/memory_graph.py --agents AGENTS.md --claude-bridge CLAUDE.md`
   - *(sidecar)*:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/stamp-portable-layer.sh" --manual-dest <workspace_root>/conventions/memory-base-guide.md --graph-dest <workspace_root>/tools/memory_graph.py`
     then enrich `<workspace_root>/INDEX.md` with a pointer to `conventions/memory-base-guide.md` and
     a one-line "Link grammar" note (add-only; skip if already present). Never write the repo tree.
4. **Report** each stamper status line (created vs exists), the mode, and that facts/index were untouched.
   In sidecar mode do not commit unless the user asks; in in-repo mode leave changes staged-ready.
```

- [ ] **Step 2: Verify the plugin validates (skill is registered)**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py`
Expected: passes; skill count increases by one.

- [ ] **Step 3: Controller live dogfood (recorded in the task report)**

Controller drives it (skill is `disable-model-invocation`). On a scratch base that has `docs/memory/`
but no portable layer, follow the steps and confirm the manual (`docs/memory/README.md`), the
validator (`docs/tools/memory_graph.py`), `AGENTS.md`, and the `CLAUDE.md` bridge appear and
facts/index are byte-unchanged; a second run adds nothing. Record the outcome.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add skills/make-portable/SKILL.md
git commit -m "feat(memory): add /make-portable retrofit skill"
```

---

### Task 5: Retarget the `/ingest gotcha:` costly-first write to AGENTS.md

Costly-first facts are canonical in `AGENTS.md` now, so the gotcha write must target it (in-repo). Prose skill; the underlying `claude-md-upsert.sh` is unchanged (it already takes any path). Verified by controller dogfood; existing helper tests stay green.

**Files:**
- Modify: `skills/ingest/SKILL.md`

**Interfaces:**
- Consumes: `scripts/claude-md-upsert.sh` (unchanged), `AGENTS.md` (Task 1 template / stamped by Task 3-4).
- Produces: `/ingest gotcha:` writing the stale-prior bullet to `AGENTS.md`'s `## Stale priors (training vs reality)` section in in-repo mode.

- [ ] **Step 1: Repoint the in-repo gotcha branch**

In `skills/ingest/SKILL.md`, in the Step 1 routing block, find the `**YES (costly-first), gotcha,
in-repo mode:**` branch. It currently resolves the repo `CLAUDE.md` path and calls
`claude-md-upsert.sh` against it. Change it to target `AGENTS.md`:
- Resolve the `AGENTS.md` path (repo root: `git rev-parse --show-toplevel`/AGENTS.md, else
  `$CLAUDE_PROJECT_DIR`/`$PWD`). If `AGENTS.md` does not exist, note that the base may not be
  portable yet and suggest `/make-portable`, then proceed to create/append via the helper (the
  helper creates the managed section if absent).
- Keep the same managed heading string `## Stale priors (training vs reality)` and the same bullet
  shape. The call becomes:
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/claude-md-upsert.sh" "<agents_md>" "## Stale priors (training vs reality)" "<bullet>"`.
- Update the surrounding prose and the confirm/report text to say `AGENTS.md` instead of `CLAUDE.md`
  (the confirm still shows the exact bullet + the target path). Everything else about the branch
  (same-topic collision check, confirm-before-write, report the status word, stop) is unchanged.

- [ ] **Step 2: Update the convention cross-reference**

In `conventions/memory.md` (Recurring flavors subsection) and any spot in `skills/ingest/SKILL.md`
that says the costly-first gotcha bullet goes to `CLAUDE.md`, change it to `AGENTS.md` (the canonical
always-loaded file; `CLAUDE.md` imports it). Do not restate the boundary rule; just fix the target file name.

- [ ] **Step 3: Confirm existing helper tests still pass (unchanged helper)**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-claude-md-upsert.sh`
Expected: `27 passed, 0 failed` (helper untouched; this is a regression guard).

- [ ] **Step 4: Controller live dogfood (recorded in the task report)**

Controller drives `/ingest gotcha:` (skill is `disable-model-invocation`) on a scratch in-repo base
that has an `AGENTS.md`: confirm the bullet lands in `AGENTS.md`'s `## Stale priors` section (not
`CLAUDE.md`), a second identical run reports `skipped: already present`, and no duplication. Record the outcome.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add skills/ingest/SKILL.md conventions/memory.md
git commit -m "feat(memory): /ingest gotcha: writes costly-first facts to AGENTS.md (canonical)"
```

---

### Task 6: Conventions drift line, version bump, and close-out

Bound drift, bump the version, and record the action + decision. Last, so records reference real commits.

**Files:**
- Modify: `conventions/memory.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `docs/project-tracking/ideas.md`
- Modify: `docs/project-tracking/resolved.md`
- Modify: `docs/project-tracking/decisions-log.md`
- Modify (optional): `README.md`, `ARCHITECTURE.md`

**Interfaces:**
- Consumes: the commits from Tasks 1-5.
- Produces: version `0.16.0`; `A-20260730-portable-memory-base`; `D-20260730-agents-md-canonical`.

- [ ] **Step 1: Add the drift-control line to conventions/memory.md**

In `conventions/memory.md`, near the schema definition, add one line: the canonical vendor-neutral
statement of the schema and maintenance procedure is the portable operator's manual template
(`templates/memory/README.md`), stamped into each base; this convention file is the plugin-internal
source and should stay consistent with that template. Plain ASCII, no em dashes.

- [ ] **Step 2: Bump the version**

In `.claude-plugin/plugin.json`, change the version to:

```json
  "version": "0.16.0",
```

- [ ] **Step 3: Mark the shipped work in ideas.md**

In `docs/project-tracking/ideas.md`, under `### vendor-neutral-runtime`, append a line immediately
after the `- Priority:` line noting the survival half shipped:

```markdown
- **Shipped (2026-07-30, the bus-factor/survival half):** the portable-artifacts slice - each base now carries a self-describing operator's manual + vendored `memory_graph.py`, a vendor-neutral `AGENTS.md` entry point (canonical costly-first home), and a `CLAUDE.md` bridge; `/project-init` stamps it and `/make-portable` retrofits existing bases (both modes). See `resolved.md` A-20260730-portable-memory-base and `decisions-log.md` D-20260730-agents-md-canonical. Remaining (this idea): the ~80% multi-vendor USE via an MCP server + scripts-core refactor.
```

- [ ] **Step 4: Append the action record to resolved.md**

Append to `docs/project-tracking/resolved.md` (newest at the end):

```markdown
### A-20260730-portable-memory-base - portable (vendor-neutral) memory base (v0.16.0)
- Workstream: memory
- Status: done
- Created: 2026-07-30
- Completed: 2026-07-30
- Commit: <fill from git log after Task 5; branch feature/portable-memory-base - list all task SHAs>

Made every memory base workspace-os produces self-describing and vendor-neutral: a de-skilled
operator's manual (`templates/memory/README.md`) + vendored `memory_graph.py` + a thin `AGENTS.md`
entry point + a `CLAUDE.md` bridge, stamped by a shared tested helper `scripts/stamp-portable-layer.sh`.
`/project-init` stamps it (both modes) and `/make-portable` retrofits existing bases. `AGENTS.md` is
now the canonical always-loaded home; the `/ingest gotcha:` write retargets there (D-20260730-agents-md-canonical).
Skills/hooks/plugin stay Claude-only. Spec: `docs/specs/2026-07-30-portable-memory-base-design.md`.
Plan: `docs/plans/2026-07-30-portable-memory-base.md`. Ships the survival half of `[[vendor-neutral-runtime]]`;
multi-vendor USE (MCP) remains.
```

- [ ] **Step 5: Append the decision record to decisions-log.md**

Append to `docs/project-tracking/decisions-log.md` (append-only, newest at the end):

```markdown
### D-20260730-agents-md-canonical - AGENTS.md is the canonical always-loaded instruction file; CLAUDE.md bridges to it
- Workstream: memory
- Created: 2026-07-30
- Rationale: portability to a non-Claude successor requires costly-first facts to live where any agent
  reads them. `AGENTS.md` is the cross-vendor always-loaded convention, so it becomes canonical and
  `CLAUDE.md` is reduced to a bridge that imports it (`@AGENTS.md` + `@docs/memory/MEMORY.md`). This
  extends D-20260727-ingest-gotcha-claudemd: the costly-first home moves from `CLAUDE.md` to the
  vendor-neutral `AGENTS.md` (which `CLAUDE.md` now imports), and the `/ingest gotcha:` write retargets
  there in in-repo mode. Sidecar mode is unaffected (repo tree untouched; costly-first stays manual).
- Spawns: none

Full design: `docs/specs/2026-07-30-portable-memory-base-design.md`. Plan: `docs/plans/2026-07-30-portable-memory-base.md`.
```

- [ ] **Step 6: (Optional) README / ARCHITECTURE line**

If `README.md` or `ARCHITECTURE.md` lists the skills or the memory layer, add a short parallel line
for `/make-portable` (add the portable vendor-neutral layer to an existing base) and note that
`/project-init` now stamps it. Match existing phrasing; plain ASCII. Skip if it would add noise.

- [ ] **Step 7: Verify**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py && bash tests/test-portable-templates.sh && bash tests/test-stamp-portable-layer.sh && bash tests/test-claude-md-upsert.sh`
Expected: validate passes; each harness ends `N passed, 0 failed`.

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add conventions/memory.md .claude-plugin/plugin.json docs/project-tracking/ideas.md docs/project-tracking/resolved.md docs/project-tracking/decisions-log.md README.md ARCHITECTURE.md
git commit -m "docs(memory): v0.16.0 portable-memory-base close-out (drift line, records)"
```

(Drop `README.md`/`ARCHITECTURE.md` from the `git add` if Step 6 made no change.)

---

## Verification (whole feature)

- `tests/test-portable-templates.sh`, `tests/test-stamp-portable-layer.sh` each end `N passed, 0 failed`; the pre-existing `tests/test-claude-md-upsert.sh` (27) and `tests/test-memory-graph.sh` stay green.
- `scripts/validate-plugin.py` passes; `/make-portable` is registered.
- **Live dogfood (not just harnesses):** `/project-init` (both modes) stamps a portable base; `/make-portable` retrofits an existing base add-only; `/ingest gotcha:` writes to `AGENTS.md`; sidecar never writes the repo tree.
- A cold-read check: the stamped `docs/memory/README.md` alone describes the schema, the boundary rule (naming `AGENTS.md`), the add-a-fact and lint procedures, and the wikilink grammar - no plugin reference required.
- No em dashes in any added line; version `0.16.0` consistent across `plugin.json` and the records; `A-20260730-portable-memory-base` and `D-20260730-agents-md-canonical` cross-reference the spec, plan, and each other.
