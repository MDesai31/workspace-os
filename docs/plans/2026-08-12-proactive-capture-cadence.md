# Proactive Capture Cadence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the capture and read-only skills model-invocable and add a scoped SessionStart hook that drives proactive, batch-at-boundaries capture of decisions, facts, and actions.

**Architecture:** Three changes over existing skills, no new capture skill. (1) A new SessionStart hook `hooks/capture-cadence.sh` emits an always-loaded capture-cadence instruction, but only in repos that actually have workspace-os data (probed via `scripts/resolve-data-root.sh`), so unrelated repos are unaffected. (2) Four skills drop `disable-model-invocation`; `project-log`/`ingest` also get proactive-worded descriptions. (3) Records + version bump close it out.

**Tech Stack:** Bash (POSIX sh; Git Bash on Windows), Claude Code plugin hooks (`hooks.json`), Python `scripts/validate-plugin.py`, plain-bash test harnesses.

## Global Constraints

- No em dashes (U+2014) on any added line; plain ASCII, ASCII hyphen `-`.
- The cadence hook FAILS OPEN: any missing data, non-workspace-os repo, or non-git dir yields no output and exit 0; it never blocks a session.
- Reuse `scripts/resolve-data-root.sh` as the single source of mode/data-root truth; never re-derive paths.
- Spec: `docs/specs/2026-08-12-proactive-capture-cadence-design.md`.
- Version bump target: `0.17.0` -> `0.18.0`.
- Record IDs (keep spec's date): `D-20260812-proactive-capture-cadence`, `A-20260812-proactive-capture-cadence`.
- Skills that MUST stay `disable-model-invocation`: `project-init`, `workspace-init`, `make-portable`, `memory-adopt`, `tracking-adopt`, `memory-sync`, `continuity`. Do not touch these.

---

### Task 1: The capture-cadence SessionStart hook

**Files:**
- Create: `hooks/capture-cadence.sh`
- Create: `tests/test-capture-cadence.sh`
- Modify: `hooks/hooks.json` (register the hook in the existing `SessionStart` array)

**Interfaces:**
- Consumes: `scripts/resolve-data-root.sh` (prints `mode=`, `data_root=`, and in sidecar `workspace_root=`; exits 1 outside a git repo).
- Produces: `hooks/capture-cadence.sh`, a SessionStart command hook that prints the cadence block to stdout when workspace-os data exists, else nothing.

- [ ] **Step 1: Write the failing test harness**

Create `tests/test-capture-cadence.sh`:

```bash
#!/usr/bin/env bash
# Test harness for hooks/capture-cadence.sh (deps: bash + git).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/capture-cadence.sh"
pass=0; fail=0
contains() { case "$2" in *"$3"*) echo "PASS: $1"; pass=$((pass+1));; *) echo "FAIL: $1 (out=[$2])"; fail=$((fail+1));; esac; }
empty() { if [ -z "$2" ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (want empty, got [$2])"; fail=$((fail+1)); fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# in-repo WITH tracking data -> emits the cadence
R1="$TMP/with-data"; mkdir -p "$R1/docs/project-tracking"; git -C "$R1" init -q
out="$(cd "$R1" && bash "$HOOK" 2>/dev/null)"
contains "in-repo with tracking data emits cadence" "$out" "capture cadence"
contains "cadence names /project-log" "$out" "/project-log"
contains "cadence names /ingest" "$out" "/ingest"

# in-repo with memory/ only -> still emits
R4="$TMP/memory-only"; mkdir -p "$R4/docs/memory"; git -C "$R4" init -q
out="$(cd "$R4" && bash "$HOOK" 2>/dev/null)"
contains "memory/ alone emits cadence" "$out" "capture cadence"

# in-repo WITHOUT workspace-os data -> silent
R2="$TMP/no-data"; mkdir -p "$R2"; git -C "$R2" init -q
out="$(cd "$R2" && bash "$HOOK" 2>/dev/null)"
empty "in-repo without workspace-os data is silent" "$out"

# outside a git repo -> silent, exit 0 (fail open)
R3="$TMP/not-git"; mkdir -p "$R3/docs/memory"
out="$(cd "$R3" && bash "$HOOK" 2>/dev/null)"; ec=$?
empty "outside a git repo is silent" "$out"
[ "$ec" = 0 ] && { echo "PASS: fail-open exit 0 outside git"; pass=$((pass+1)); } || { echo "FAIL: nonzero exit outside git"; fail=$((fail+1)); }

# sidecar mode: workspace-tier memory present -> emits
WS="$TMP/ws"; mkdir -p "$WS/_meta/memory" "$WS/repo-a"
printf '{"workspace-os":"sidecar","workspace":"test"}\n' > "$WS/_meta/workspace.json"
git -C "$WS/repo-a" init -q
out="$(cd "$WS/repo-a" && bash "$HOOK" 2>/dev/null)"
contains "sidecar with workspace-tier memory emits cadence" "$out" "capture cadence"

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-capture-cadence.sh`
Expected: FAIL - the hook file does not exist yet, so every `contains` assertion fails (empty output) and the tally shows failures.

- [ ] **Step 3: Write the hook**

Create `hooks/capture-cadence.sh`:

```bash
#!/usr/bin/env bash
# workspace-os capture cadence - SessionStart hook.
# Emits a short always-loaded instruction telling the model to capture decisions/facts/actions
# proactively and PROPOSE them as a batch at task boundaries. Emitted ONLY when this repo has
# workspace-os data (a project-tracking/ or memory/ dir under the resolved data root, or the
# sidecar workspace tier), so unrelated repos are unaffected. Fires in BOTH data-root modes.
# Fail open always: any error, missing data, or non-git dir -> no output, exit 0.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out="$(bash "$HERE/../scripts/resolve-data-root.sh" 2>/dev/null)" || exit 0
data_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
ws_root="$(printf '%s\n' "$out" | sed -n 's/^workspace_root=//p')"

has_data=0
check_dir() { [ -n "$1" ] && [ -d "$1" ] && has_data=1; }
if [ -n "$data_root" ]; then
  check_dir "$data_root/project-tracking"
  check_dir "$data_root/memory"
fi
if [ -n "$ws_root" ]; then
  check_dir "$ws_root/memory"
  check_dir "$ws_root/project-tracking"
fi
[ "$has_data" = 1 ] || exit 0

cat <<'EOF'
## workspace-os capture cadence

As you work in this repo, watch for durable items worth recording and capture them proactively:
- a decision (a choice + why) -> /project-log decision (or model-decision)
- a started or finished action -> /project-log action | done
- a durable fact about this codebase -> /ingest
- a future intent -> /project-plan

Do not interrupt mid-task. Accumulate candidates and PROPOSE them as a batch at a natural stopping
point (task done, before a commit). On the user's confirmation, invoke the relevant skill so the
record follows its full ritual (format, the AGENTS.md/CLAUDE.md boundary test, secret-scan,
idempotency). Skip trivia; capture only what future-you could not re-derive.
EOF
exit 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-capture-cadence.sh`
Expected: `8 passed, 0 failed`.

- [ ] **Step 5: Register the hook in hooks.json**

In `hooks/hooks.json`, add the hook to the existing `SessionStart` array's `hooks` list (after the `sidecar-memory-context.sh` entry). Replace:

```json
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/sidecar-memory-context.sh\"" }
        ]
```

with:

```json
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/sidecar-memory-context.sh\"" },
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/capture-cadence.sh\"" }
        ]
```

- [ ] **Step 6: Validate the plugin and re-run the harness**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py && bash tests/test-capture-cadence.sh`
Expected: validate passes (exit 0); harness ends `8 passed, 0 failed`.

- [ ] **Step 7: Confirm no em dashes on added lines**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && git diff -- hooks/ tests/test-capture-cadence.sh | grep -P '^\+' | grep -P '\x{2014}' && echo FOUND || echo clean`
Expected: `clean`.

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add hooks/capture-cadence.sh hooks/hooks.json tests/test-capture-cadence.sh
git commit -m "feat(hooks): add scoped SessionStart capture-cadence hook"
```

---

### Task 2: Make capture + read-only skills model-invocable

**Files:**
- Modify: `skills/project-log/SKILL.md` (remove `disable-model-invocation`; reword description)
- Modify: `skills/ingest/SKILL.md` (remove `disable-model-invocation`; reword description)
- Modify: `skills/memory-lint/SKILL.md` (remove `disable-model-invocation`)
- Modify: `skills/memory-search/SKILL.md` (remove `disable-model-invocation`)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: four skills the model can invoke; two with proactive/batched descriptions that align with the Task 1 cadence.

- [ ] **Step 1: Remove the flag from all four skills**

In each of `skills/project-log/SKILL.md`, `skills/ingest/SKILL.md`, `skills/memory-lint/SKILL.md`, `skills/memory-search/SKILL.md`, delete the frontmatter line (exact, identical in all four):

```
disable-model-invocation: true
```

Do NOT touch the `user-invocable: true` line. Do NOT touch any other skill.

- [ ] **Step 2: Reword the project-log description**

In `skills/project-log/SKILL.md`, replace the `description:` line with:

```
description: Log a project action item, decision, or mark one done, in the repo's project tracking. Use whenever a decision (a choice + why), an action to do, or a completed item arises - proactively, not only when asked. Accumulate candidates and propose them as a batch at a natural stopping point rather than interrupting mid-task. The general-purpose tracking entry point.
```

- [ ] **Step 3: Reword the ingest description**

In `skills/ingest/SKILL.md`, replace the `description:` line with:

```
description: Capture a durable project fact into this repo's shared memory. Use whenever a non-obvious, durable fact about THIS codebase arises (architecture rationale, a domain rule, a gotcha to look up later, a reference pointer) - proactively, not only when asked. Accumulate candidates and propose them as a batch at a stopping point; on confirmation, write a fact file under docs/memory/ and update the index.
```

- [ ] **Step 4: Verify the exact flag set changed**

Run:
```bash
cd "C:/Users/206936855/Documents/workspace-os"
echo "files still carrying the flag should be 7 (11 -> 7 after flipping 4):"
grep -rl 'disable-model-invocation: true' skills/ | wc -l
echo "these four must NOT have the flag:"
for s in project-log ingest memory-lint memory-search; do grep -q 'disable-model-invocation' "skills/$s/SKILL.md" && echo "  STILL SET: $s" || echo "  ok: $s"; done
echo "these seven MUST still have it:"
for s in project-init workspace-init make-portable memory-adopt tracking-adopt memory-sync continuity; do grep -q 'disable-model-invocation: true' "skills/$s/SKILL.md" && echo "  ok: $s" || echo "  MISSING: $s"; done
```
Expected: count is `7`; all four print `ok`; all seven print `ok`.

- [ ] **Step 5: Validate the plugin and check em dashes**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py && (git diff -- skills/ | grep -P '^\+' | grep -P '\x{2014}' && echo FOUND || echo clean)`
Expected: validate passes; `clean`.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add skills/project-log/SKILL.md skills/ingest/SKILL.md skills/memory-lint/SKILL.md skills/memory-search/SKILL.md
git commit -m "feat(skills): make capture + read-only skills model-invocable"
```

---

### Task 3: Records, version bump, and close-out

**Files:**
- Modify: `.claude-plugin/plugin.json` (version `0.17.0` -> `0.18.0`)
- Modify: `docs/project-tracking/decisions-log.md` (append `D-20260812-proactive-capture-cadence`)
- Modify: `docs/project-tracking/resolved.md` (append `A-20260812-proactive-capture-cadence`)
- Modify: `docs/project-tracking/ideas.md` (annotate `### engine-hooks` with the shipped SessionStart nudge)

**Interfaces:**
- Consumes: the commits from Tasks 1-2.
- Produces: version `0.18.0`; the two records; a shipped annotation.

- [ ] **Step 1: Bump the version**

In `.claude-plugin/plugin.json`, change `"version": "0.17.0",` to `"version": "0.18.0",`.

- [ ] **Step 2: Append the decision record**

Append to `docs/project-tracking/decisions-log.md` (keep the body short - the boundary lint from v0.17.0 flags records over ~40 lines):

```markdown

### D-20260812-proactive-capture-cadence - capture + read-only skills go model-invocable; a SessionStart hook drives proactive, batched capture
- Workstream: meta
- Created: 2026-08-12
- Rationale: 11 of 12 skills carried `disable-model-invocation`, so Claude captured records inline
  ("roundabout"), bypassing each skill's ritual (template, boundary test, secret-scan, idempotency).
  The capture skills (`project-log`, `ingest`) and read-only skills (`memory-lint`, `memory-search`)
  become model-invocable so Claude runs the real ritual; a scoped SessionStart hook
  (`hooks/capture-cadence.sh`) injects a capture cadence (note proactively, propose as a batch at a
  stopping point, write on confirmation) only in repos that have workspace-os data. Heavy/one-time
  skills (`project-init`, `workspace-init`, `make-portable`, `memory-adopt`, `tracking-adopt`,
  `memory-sync`, `continuity`) stay manual. Supersedes the blanket `disable-model-invocation` default
  for the four flipped skills.
- Spawns: none

Design: `docs/specs/2026-08-12-proactive-capture-cadence-design.md`. Plan: `docs/plans/2026-08-12-proactive-capture-cadence.md`.
```

- [ ] **Step 3: Append the action record**

Append to `docs/project-tracking/resolved.md`:

```markdown

### A-20260812-proactive-capture-cadence - proactive, batched capture via model-invocable skills + a cadence hook (v0.18.0)
- Workstream: meta
- Status: done
- Created: 2026-08-12
- Completed: 2026-08-13
- Commit: pending (branch feature/proactive-capture-cadence; SHA filled at merge)

Made `project-log`, `ingest`, `memory-lint`, `memory-search` model-invocable and added a scoped
SessionStart hook `hooks/capture-cadence.sh` that injects a proactive, batch-at-boundaries capture
cadence only in workspace-os repos. `project-log`/`ingest` descriptions reworded to invite proactive
use. Heavy/one-time skills stay manual. Decision: D-20260812-proactive-capture-cadence. Spec:
`docs/specs/2026-08-12-proactive-capture-cadence-design.md`.
```

- [ ] **Step 4: Annotate the engine-hooks idea**

In `docs/project-tracking/ideas.md`, under `### engine-hooks`, add one bullet immediately after the existing `**Shipped (2026-07-05, partial):**` line:

```markdown
- **Shipped (2026-08-13, the capture nudge):** a scoped SessionStart hook (`hooks/capture-cadence.sh`) injects a proactive, batch-at-boundaries capture cadence in workspace-os repos, paired with making the capture skills model-invocable. See `resolved.md` A-20260812-proactive-capture-cadence. Remaining: the `Stop`-hook variant and target-repo CI wiring of the `--check` gate.
```

- [ ] **Step 5: Verify - harnesses, validate, boundary self-dogfood, version, em dashes**

Run:
```bash
cd "C:/Users/206936855/Documents/workspace-os"
python3 scripts/validate-plugin.py
for t in test-capture-cadence test-memory-graph test-portable-templates test-stamp-portable-layer test-claude-md-upsert; do printf "%-28s " "$t:"; bash "tests/$t.sh" 2>&1 | tail -1; done
python3 scripts/memory_graph.py --check-tracking --tracking-root docs/project-tracking
grep '"version"' .claude-plugin/plugin.json
git diff | grep -P '^\+' | grep -P '\x{2014}' && echo "EM DASH FOUND" || echo "no em dash on added lines"
```
Expected: validate passes; every harness ends `N passed, 0 failed`; `--check-tracking` reports `violations: 0` (the new records stay within the boundary); version is `0.18.0`; `no em dash on added lines`.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add .claude-plugin/plugin.json docs/project-tracking/decisions-log.md docs/project-tracking/resolved.md docs/project-tracking/ideas.md
git commit -m "docs(meta): v0.18.0 proactive-capture-cadence close-out (records, version)"
```

---

## Verification (whole feature)

- `tests/test-capture-cadence.sh` ends `8 passed, 0 failed`; the pre-existing harnesses (`test-memory-graph.sh` 39, `test-portable-templates.sh` 21, `test-stamp-portable-layer.sh` 20, `test-claude-md-upsert.sh` 27) stay green.
- `scripts/validate-plugin.py` passes with `capture-cadence.sh` registered in `SessionStart`.
- Exactly four skills lost `disable-model-invocation` (`project-log`, `ingest`, `memory-lint`, `memory-search`); the seven heavy/one-time skills kept it; `project-plan` unchanged.
- `memory_graph.py --check-tracking` reports zero violations for the new records.
- No em dashes on any added line; version `0.18.0` across `plugin.json` and the records; `D-`/`A-` records cross-reference the spec and plan.
- Live dogfood (recommended, not a harness): in a scratch repo with `docs/project-tracking/`, confirm a fresh session surfaces the cadence text; in a bare repo, confirm it does not. The `/project-init` guard from v0.17.0 remains prose-only and is out of scope here.
