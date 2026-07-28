# `/ingest gotcha:` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach `/ingest` a `gotcha:` branch that routes a stale-prior via the existing boundary test: costly-first to a confirmed imperative bullet in a managed CLAUDE.md section (in-repo only, via a tested idempotent helper), consult-when-relevant to a `docs/memory/` fact with the gotcha body shape.

**Architecture:** A new deterministic helper `scripts/claude-md-upsert.sh` does the one risky thing (idempotent, add-only insert of a bullet into a named CLAUDE.md section). The `/ingest` skill gains a trigger-gated branch that reuses its existing boundary test, secret scan, and (for the NO path) its existing fact-writing steps; on the YES-in-repo path it confirms with the user then calls the helper. A `conventions/memory.md` subsection documents the flavor and both body shapes once. Non-gotcha `/ingest` is unchanged.

**Tech Stack:** Bash (helper + plain-bash test harness), markdown skill/convention files, `scripts/validate-plugin.py`.

## Global Constraints

- **Trigger-gated:** the CLAUDE.md-write path fires ONLY when the `/ingest` argument begins with `gotcha:` or `stale-prior:` (case-insensitive). A normal `/ingest` fact behaves exactly as today (costly-first still tells-and-stops). No general `/ingest` upgrade.
- **In-repo only for the CLAUDE.md bullet.** In sidecar mode the YES path must NOT write the repo working tree; it tells-and-stops. The NO path writes a `docs/memory/` fact in the chosen tier normally.
- **Confirm before any CLAUDE.md write.** The skill shows the exact bullet + target file path and gets explicit user confirmation before calling the helper. The helper never prompts.
- **The helper is add-only and idempotent.** It inserts or skips an exact-duplicate bullet; it never removes, reorders, or reformats existing lines. Exit 0 on success including the idempotent skip; non-zero only for a missing/unwritable file or bad args.
- **No new runtime dependencies.** Pure bash + coreutils (like `resolve-data-root.sh`). Tests stay plain bash. No new frontmatter `type`, no `tags:`.
- **Secret scan on both paths.** Never write a key/token/`.env` value into CLAUDE.md or a fact (reuse the existing `/ingest` rule).
- **No em dashes (U+2014)** anywhere in code, script output, skill/convention/doc text, or commit messages. Use plain ASCII.
- **Managed section heading (exact):** `## Stale priors (training vs reality)`.
- **Version bump on completion:** `0.14.0 -> 0.15.0`.
- **Record IDs (today's date):** action `A-20260727-ingest-gotcha`; decision `D-20260727-ingest-gotcha-claudemd`.
- **Read-only elsewhere:** do not modify `scripts/memory_graph.py`, `tests/test-memory-graph.sh`, or other skills.

---

### Task 1: The `claude-md-upsert.sh` helper + tests

The deterministic core. TDD: write the harness first, watch it fail, then implement the script.

**Files:**
- Create: `scripts/claude-md-upsert.sh`
- Create: `tests/test-claude-md-upsert.sh`

**Interfaces:**
- Produces: `scripts/claude-md-upsert.sh`, invoked `claude-md-upsert.sh <claude_md_path> "<section_heading>" "<bullet_text>"`. Prints exactly one status word to stdout: `created section` | `appended` | `skipped: already present`. Exit 0 on success (including the skip); 1 on missing/unwritable file; 2 on bad args. Add-only; preserves all other lines.

- [ ] **Step 1: Write the failing test harness**

Create `tests/test-claude-md-upsert.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash tests for scripts/claude-md-upsert.sh (deps: bash + coreutils only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/claude-md-upsert.sh"
SECTION="## Stale priors (training vs reality)"
BULLET="- Prisma import: use @/generated/prisma/client, NOT @prisma/client (training prior is wrong here)."
pass=0; fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

assert() { # assert "<name>" <exit-code-of-preceding-test>
  if [ "$2" -eq 0 ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}
contains() { case "$(cat "$1")" in *"$2"*) return 0;; *) return 1;; esac; }

# case 1: section absent -> created
f="$TMP/a.md"; printf '# Project\n\nSome intro.\n' > "$f"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "absent: exit 0" $?
[ "$out" = "created section" ]; assert "absent: says created" $?
contains "$f" "$SECTION"; assert "absent: heading present" $?
contains "$f" "$BULLET"; assert "absent: bullet present" $?

# case 2: section present -> appended under it (before the next heading)
f="$TMP/b.md"
printf '# P\n\n%s\n- existing: use B, NOT A (training prior is wrong here).\n\n## After\ntail\n' "$SECTION" > "$f"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "present: exit 0" $?
[ "$out" = "appended" ]; assert "present: says appended" $?
awk -v b="$BULLET" -v a="## After" 'index($0,b){bi=NR} index($0,a){ai=NR} END{exit !(bi>0 && ai>0 && bi<ai)}' "$f"
assert "present: bullet sits under section (before ## After)" $?

# case 3: exact duplicate -> skipped, file unchanged
f="$TMP/c.md"; printf '# P\n\n%s\n%s\n' "$SECTION" "$BULLET" > "$f"; before="$(cat "$f")"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "dup: exit 0" $?
case "$out" in skipped*) true;; *) false;; esac; assert "dup: says skipped" $?
[ "$before" = "$(cat "$f")" ]; assert "dup: file unchanged" $?

# case 4: trailing @import -> section inserted before it, import still last non-blank
f="$TMP/d.md"; printf '# P\n\nintro\n\n@docs/memory/MEMORY.md\n' > "$f"
out="$(bash "$SCRIPT" "$f" "$SECTION" "$BULLET")"; ec=$?
[ "$ec" = 0 ]; assert "import: exit 0" $?
awk -v h="$SECTION" '$0==h{hi=NR} /^@/{imp=NR} END{exit !(hi>0 && imp>0 && hi<imp)}' "$f"
assert "import: heading before @import line" $?
last="$(awk 'NF{l=$0} END{print l}' "$f")"; case "$last" in @*) true;; *) false;; esac
assert "import: @import still last non-blank" $?

# case 5: missing file -> nonzero, nothing created
out="$(bash "$SCRIPT" "$TMP/nope.md" "$SECTION" "$BULLET" 2>/dev/null)"; ec=$?
[ "$ec" != 0 ]; assert "missing: nonzero exit" $?
[ ! -f "$TMP/nope.md" ]; assert "missing: file not created" $?

# case 6: bad args -> exit 2
bash "$SCRIPT" "$TMP/a.md" "$SECTION" >/dev/null 2>&1; [ "$?" = 2 ]; assert "badargs: exit 2" $?

# case 7: unrelated content preserved
f="$TMP/g.md"; printf '# P\n\nSENTINEL-XYZ\n\n@a.md\n' > "$f"
bash "$SCRIPT" "$f" "$SECTION" "$BULLET" >/dev/null
contains "$f" "SENTINEL-XYZ"; assert "preserve: sentinel intact" $?

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-claude-md-upsert.sh`
Expected: FAIL / nonzero (the script does not exist yet, so every `bash "$SCRIPT" ...` errors).

- [ ] **Step 3: Implement the helper**

Create `scripts/claude-md-upsert.sh`:

```bash
#!/usr/bin/env bash
# Idempotently insert one bullet into a named managed section of a CLAUDE.md file.
#
# Usage: claude-md-upsert.sh <claude_md_path> <section_heading> <bullet_text>
#   <section_heading>  exact managed heading, e.g. "## Stale priors (training vs reality)"
#   <bullet_text>      the full bullet line, including the leading "- "
#
# Prints one status word: "created section" | "appended" | "skipped: already present".
# Exit 0 on success (including the idempotent skip); 1 on missing/unwritable file; 2 on bad args.
# Add-only: never removes, reorders, or reformats existing lines. The confirm gate is the caller's.
set -uo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: claude-md-upsert.sh <claude_md_path> <section_heading> <bullet_text>" >&2
  exit 2
fi
file="$1"; heading="$2"; bullet="$3"

if [ ! -f "$file" ] || [ ! -r "$file" ] || [ ! -w "$file" ]; then
  echo "error: not a writable file: $file" >&2
  exit 1
fi

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

mapfile -t lines < "$file"
n=${#lines[@]}
bt="$(trim "$bullet")"
ht="$(trim "$heading")"

# 1) idempotency: exact (trimmed) bullet already present anywhere -> no-op
for ((i=0; i<n; i++)); do
  if [ "$(trim "${lines[i]}")" = "$bt" ]; then
    echo "skipped: already present"; exit 0
  fi
done

# 2) locate the managed section heading (exact, trimmed)
sec=-1
for ((i=0; i<n; i++)); do
  if [ "$(trim "${lines[i]}")" = "$ht" ]; then sec=$i; break; fi
done

out=()
if [ "$sec" -ge 0 ]; then
  # section present: insert the bullet just before the next heading line (or at EOF)
  end=$n
  for ((j=sec+1; j<n; j++)); do
    case "${lines[j]}" in \#*) end=$j; break;; esac
  done
  for ((i=0; i<end; i++)); do out+=("${lines[i]}"); done
  out+=("$bullet")
  for ((i=end; i<n; i++)); do out+=("${lines[i]}"); done
  printf '%s\n' "${out[@]}" > "$file"
  echo "appended"; exit 0
fi

# 3) section absent: insert before a trailing @-import block if present, else append at EOF
last=-1
for ((i=n-1; i>=0; i--)); do
  if [ -n "$(trim "${lines[i]}")" ]; then last=$i; break; fi
done
insert=$n
if [ "$last" -ge 0 ]; then
  case "$(trim "${lines[last]}")" in
    @*)
      insert=$last
      for ((i=last-1; i>=0; i--)); do
        t="$(trim "${lines[i]}")"
        if [ -z "$t" ] || [ "${t#@}" != "$t" ]; then insert=$i; else break; fi
      done
      ;;
  esac
fi
for ((i=0; i<insert; i++)); do out+=("${lines[i]}"); done
out+=("" "$heading" "" "$bullet" "")
for ((i=insert; i<n; i++)); do out+=("${lines[i]}"); done
printf '%s\n' "${out[@]}" > "$file"
echo "created section"; exit 0
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-claude-md-upsert.sh`
Expected: final line `N passed, 0 failed` (17 checks).

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add scripts/claude-md-upsert.sh tests/test-claude-md-upsert.sh
git commit -m "feat(memory): add claude-md-upsert.sh (idempotent managed-section bullet insert)"
```

---

### Task 2: The `conventions/memory.md` "Recurring flavors" subsection

Document the stale-prior flavor and both body shapes once, so the skill and a human author follow one source. Doc-only.

**Files:**
- Modify: `conventions/memory.md`

**Interfaces:**
- Produces: a "Recurring flavors" subsection the skill (Task 3) references by name for the body shapes, routing, and in-repo-only note.

- [ ] **Step 1: Add the subsection**

In `conventions/memory.md`, add the following immediately after the `### Typed wikilinks (optional)` subsection (before `## Index format (MEMORY.md)`):

```markdown
### Recurring flavors

Some facts recur in a shape worth capturing consistently. Each flavor names a body shape and the
home it routes to (the boundary test above still decides the home).

**stale-prior / gotcha** - "your training prior says X; in this repo it is actually Y."
- Captured with `/ingest gotcha: <prior-vs-reality>` (or `stale-prior:`).
- Routing is the boundary test: a pure stale-prior (the model will confidently do the wrong thing)
  is usually costly-first; a "we chose differently, and why" prior is usually consult-when-relevant.
- **Costly-first -> CLAUDE.md** as an imperative bullet under the managed section
  `## Stale priors (training vs reality)`:
  `- <topic>: use <Y>, NOT <X> (training prior is wrong here). <one-clause why or [[link]]>`
  The bullet is written by `/ingest` via `scripts/claude-md-upsert.sh` (idempotent, add-only) after
  an explicit confirm. **In-repo mode only:** in a sidecar workspace the repo CLAUDE.md is never
  touched, so `/ingest` tells you and stops for this case.
- **Consult-when-relevant -> `docs/memory/`** as a fact (`type: convention` unless clearly `domain`),
  body shape:
  `Training prior says <X>. In this repo it is actually <Y>. Why: <reason>. See [[<related>]].`
  with `description: training prior wrong for <topic>`.
```

- [ ] **Step 2: Verify the plugin still validates**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py`
Expected: passes (exit 0).

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add conventions/memory.md
git commit -m "docs(memory): document the stale-prior/gotcha recurring flavor"
```

---

### Task 3: The `gotcha:` branch in `/ingest`

Wire the trigger, routing, confirm, and helper call into the skill. The skill is prose (model-executed); verification is the live dogfood in Task-3 Step 3 plus the whole-branch review.

**Files:**
- Modify: `skills/ingest/SKILL.md`

**Interfaces:**
- Consumes: `scripts/claude-md-upsert.sh` (Task 1), the "Recurring flavors" subsection (Task 2), and `/ingest`'s existing Steps 2-9.
- Produces: `/ingest` recognizing `gotcha:` / `stale-prior:` and routing per the boundary test; non-gotcha behavior unchanged.

- [ ] **Step 1: Add the gotcha trigger step**

In `skills/ingest/SKILL.md`, insert a new step immediately after `## Steps` and before the current `1. **Apply the boundary test**` line:

```markdown
0. **Gotcha trigger (stale-prior flavor).** If the argument begins with `gotcha:` or `stale-prior:`
   (case-insensitive), strip the keyword and set a `gotcha` flag; the remainder is a stale-prior
   fact ("training prior says X; here it is actually Y"). See `conventions/memory.md` § Recurring
   flavors for the two body shapes. If the trigger is absent, ignore this step and proceed normally
   (no behavior change).
```

- [ ] **Step 2: Replace Step 1 with the routing version**

In `skills/ingest/SKILL.md`, replace this exact block:

```markdown
1. **Apply the boundary test** (conventions/memory.md): "If the model didn't see this until it
   went looking, would it make a costly mistake first?" If **YES**, this belongs in CLAUDE.md,
   not memory — tell the user and stop. If it's a **decision** (a choice + why), it belongs in
   `decisions-log.md` — offer `/project-log decision` instead and stop.
```

with:

```markdown
1. **Apply the boundary test** (conventions/memory.md): "If the model didn't see this until it
   went looking, would it make a costly mistake first?"
   - If it's a **decision** (a choice + why), it belongs in `decisions-log.md` - offer
     `/project-log decision` instead and stop.
   - **YES (costly-first), not a gotcha:** belongs in CLAUDE.md, not memory - tell the user and stop.
   - **YES (costly-first), gotcha, in-repo mode:** build the imperative bullet (conventions §
     Recurring flavors): `- <topic>: use <Y>, NOT <X> (training prior is wrong here). <why/[[link]]>`.
     Resolve the repo CLAUDE.md path (`git rev-parse --show-toplevel`/CLAUDE.md, else
     `$CLAUDE_PROJECT_DIR`/`$PWD`). Grep the managed section for a same-topic bullet; if one exists
     with different content, surface it and ask (add-anyway vs edit-by-hand) rather than auto-editing.
     Show the exact bullet + the CLAUDE.md path and get explicit confirmation, then run
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/claude-md-upsert.sh" "<claude_md>" "## Stale priors (training vs reality)" "<bullet>"`.
     Report the script's status word (`created section` / `appended` / `skipped: already present`)
     and stop.
   - **YES (costly-first), gotcha, sidecar mode:** the repo CLAUDE.md must not be touched in a
     sidecar workspace - tell the user the bullet belongs in the repo's CLAUDE.md and to add it by
     hand, and stop.
   - **NO (consult-when-relevant):** continue to the steps below and write a `docs/memory/` fact. If
     this is a gotcha, use the gotcha body shape (conventions § Recurring flavors): `type: convention`
     unless clearly `domain`; `description: training prior wrong for <topic>`; body `Training prior
     says <X>. In this repo it is actually <Y>. Why: <reason>. See [[<related>]].`
```

- [ ] **Step 3: Live dogfood (skill is prose - verify end to end)**

In this session or a scratch in-repo repo, exercise all three paths and confirm:
- `/ingest gotcha: <a costly-first prior, e.g. Prisma import path>` in-repo -> proposes the bullet, on confirm the managed section + bullet appear in CLAUDE.md; a second identical run reports `skipped: already present` and does not duplicate.
- `/ingest gotcha: <a consult-when-relevant prior>` -> writes a `docs/memory/` fact with the gotcha shape + an index line, no CLAUDE.md write.
- In a sidecar-marked tree, the costly-first gotcha path writes nothing in the repo tree and reports the tell-and-stop fallback.
- A plain `/ingest <normal fact>` still behaves exactly as before.

Record the dogfood outcome in the task report (the harness cannot cover a prose skill).

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add skills/ingest/SKILL.md
git commit -m "feat(memory): /ingest gotcha: routes stale-priors to CLAUDE.md or docs/memory"
```

---

### Task 4: Docs, tracking close-out, and version bump

Bump the version, mark the shipped half, and append the action + decision records. Last, so records reference the real commits.

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `docs/project-tracking/ideas.md`
- Modify: `docs/project-tracking/resolved.md`
- Modify: `docs/project-tracking/decisions-log.md`
- Modify (optional): `README.md`, `ARCHITECTURE.md`

**Interfaces:**
- Consumes: the commits from Tasks 1-3 (for the action record's `Commit:` line).
- Produces: version `0.15.0`; the note-templates half marked shipped; `A-20260727-ingest-gotcha` + `D-20260727-ingest-gotcha-claudemd`.

- [ ] **Step 1: Bump version and mention the flavor in plugin.json**

In `.claude-plugin/plugin.json`, change the version line to:

```json
  "version": "0.15.0",
```

Optionally add `gotcha capture` to the memory phrasing in the `description` string only if it fits without noise; otherwise leave the description unchanged.

- [ ] **Step 2: Mark the shipped half in ideas.md**

In `docs/project-tracking/ideas.md`, under the `### memory-backlinks-search` entry, append a new line immediately after the existing `**Shipped (2026-07-23, the search/backlink view):**` line:

```markdown
- **Shipped (2026-07-27, the note-templates half - gotcha flavor):** `/ingest gotcha:` captures a stale-prior and routes it via the boundary test - a confirmed imperative bullet in a managed CLAUDE.md section (in-repo only, via the idempotent `scripts/claude-md-upsert.sh`) or a `docs/memory/` fact with the gotcha body shape; the flavor is documented in `conventions/memory.md` § Recurring flavors. See `resolved.md` A-20260727-ingest-gotcha and `decisions-log.md` D-20260727-ingest-gotcha-claudemd. Remaining: the optional property-views by type/tag.
```

- [ ] **Step 3: Append the action record to resolved.md**

Append to `docs/project-tracking/resolved.md` (newest at the end, matching the file's convention):

```markdown
### A-20260727-ingest-gotcha - /ingest gotcha: stale-prior capture routing to both homes (v0.15.0)
- Workstream: memory
- Status: done
- Created: 2026-07-27
- Completed: 2026-07-27
- Commit: <fill from git log after Task 3; branch feature/ingest-gotcha>

Added a `gotcha:`/`stale-prior:` branch to `/ingest`: it reuses the existing boundary test and routes a stale-prior to a confirmed imperative bullet in a managed `## Stale priors (training vs reality)` CLAUDE.md section (in-repo only) or a `docs/memory/` fact with the gotcha body shape. The CLAUDE.md write is a deterministic, idempotent, add-only helper `scripts/claude-md-upsert.sh` (plain-bash tests in `tests/test-claude-md-upsert.sh`), confirm-before-write in the skill. Sidecar mode falls back to tell-and-stop. Non-gotcha `/ingest` unchanged. Flavor documented in `conventions/memory.md` § Recurring flavors. Spec: `docs/specs/2026-07-27-ingest-gotcha-design.md`. Plan: `docs/plans/2026-07-27-ingest-gotcha.md`. Decision: D-20260727-ingest-gotcha-claudemd. Ships the note-templates half of `memory-backlinks-search` (property-views remain).
```

- [ ] **Step 4: Append the decision record to decisions-log.md**

Append to `docs/project-tracking/decisions-log.md` (append-only, newest at the end):

```markdown
### D-20260727-ingest-gotcha-claudemd - /ingest may write a confirmed CLAUDE.md bullet for the explicit gotcha trigger (in-repo only)
- Workstream: memory
- Created: 2026-07-27
- Rationale: completing `/ingest`'s costly-first branch for stale-priors means writing an imperative bullet into CLAUDE.md, the home the boundary rule already assigns to costly-first facts (D-20260626-repo-canonical-memory). This is consistent with D-20260627-memory-adopt-claudemd-scope (the "never migrate CLAUDE.md" ban is scoped to the passive default; explicit confirmed flows may write CLAUDE.md, as `/memory-adopt` already does), so it is an extension, not a reversal. Kept narrow to avoid overreach: the write fires only on the explicit `gotcha:`/`stale-prior:` trigger (a normal costly-first fact still tells-and-stops); it is confirm-before-write; the mechanical insert is a tested idempotent, add-only helper (`scripts/claude-md-upsert.sh`) rather than model-driven editing of an always-loaded file; and it is in-repo only (sidecar workspaces never touch the repo tree, so the day-job/sidecar case gets the `docs/memory/` half only). Property-views by type/tag remain deferred.
- Spawns: none

Full design: `docs/specs/2026-07-27-ingest-gotcha-design.md`. Plan: `docs/plans/2026-07-27-ingest-gotcha.md`.
```

- [ ] **Step 5: (Optional) README / ARCHITECTURE line**

If the memory section of `README.md` or `ARCHITECTURE.md` lists the memory skills, add a short parallel line for `/ingest gotcha:` (capture a stale-prior; routes to a confirmed CLAUDE.md bullet or a docs/memory fact). Match the existing phrasing and depth; use plain ASCII (no em dashes). Skip if it would add noise.

- [ ] **Step 6: Verify**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py && bash tests/test-claude-md-upsert.sh`
Expected: validate passes; harness ends `N passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add .claude-plugin/plugin.json docs/project-tracking/ideas.md docs/project-tracking/resolved.md docs/project-tracking/decisions-log.md README.md ARCHITECTURE.md
git commit -m "docs(memory): v0.15.0 ingest-gotcha close-out (idea, action, decision records)"
```

(Drop `README.md`/`ARCHITECTURE.md` from the `git add` if Step 5 made no change.)

---

## Verification (whole feature)

- `bash tests/test-claude-md-upsert.sh` ends `N passed, 0 failed`; the pre-existing `tests/test-memory-graph.sh` stays green (untouched).
- `scripts/validate-plugin.py` passes.
- **Live dogfood (not just the harness):** `/ingest gotcha:` YES-in-repo writes the confirmed bullet and is idempotent on re-run; NO writes a `docs/memory/` fact; sidecar YES falls back to tell-and-stop writing nothing in the repo tree; plain `/ingest` unchanged.
- The CLAUDE.md write is confirm-gated, add-only, and never fires without the explicit `gotcha:`/`stale-prior:` trigger.
- No em dashes in any added line; version `0.15.0` consistent across `plugin.json` and the records; `A-20260727-ingest-gotcha` and `D-20260727-ingest-gotcha-claudemd` cross-reference the spec, plan, and each other.
