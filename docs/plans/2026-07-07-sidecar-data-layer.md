# Sidecar Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second data-location mode ("sidecar") so repos under a marked workspace store their workspace-os data in a local-only `_meta/` git repo instead of in-tree — per `docs/specs/2026-07-07-sidecar-data-layer-design.md`.

**Architecture:** One new resolver script (`scripts/resolve-data-root.sh`) becomes the single source of mode truth; hooks and skills consume its `key=value` output and never compute data paths themselves. A SessionStart hook replaces the CLAUDE.md memory import in sidecar mode; `guardrail.sh` gains a sidecar config fallback plus a warn backstop; `memory_graph.py` gains cross-tier wikilink resolution. Skills get a uniform "Step 0: resolve the data root" preamble.

**Tech Stack:** bash + jq (hooks/resolver/tests), python3 stdlib (memory_graph), model-interpreted SKILL.md files.

## Global Constraints

- **Repo:** `/home/manthan01/Documents/Codebase/workspace-os`, branch `feat/sidecar-data-layer` (already exists — work on it directly; do NOT create a worktree or new branch).
- **Safety invariant (spec §5):** in sidecar mode, no workspace-os skill or hook may create, modify, or stage any file inside the repo's working tree.
- **Sidecar always wins in a marked workspace** — no per-repo override (spec §3).
- **Marker file:** `_meta/workspace.json` containing `{"workspace-os": "sidecar", "workspace": "<name>"}`. A bare `_meta/` without the marker marks nothing.
- **Path shapes** (identical consumption in both modes): tracking = `<data_root>/project-tracking/`, memory = `<data_root>/memory/`. In-repo `data_root=<repo>/docs`; sidecar `data_root=<workspace>/_meta/<repo-folder-name>`.
- **Fail open:** hooks never block on resolver errors (`guardrail.sh` existing convention).
- **Deps:** bash + jq for hooks/tests, python3 stdlib only for scripts. No new dependencies.
- **Tests must pass:** `bash tests/test-guardrail.sh`, `bash tests/test-memory-graph.sh`, `python3 scripts/validate-plugin.py`, plus the two new test files added by this plan.
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` (shown as `<trailer>` in commit steps below — always include it).

---

### Task 1: Resolver script `scripts/resolve-data-root.sh`

**Files:**
- Create: `scripts/resolve-data-root.sh`
- Test: `tests/test-resolve-data-root.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces (consumed by every later task): executable bash script printing `key=value` lines on stdout:
  - always: `mode=in-repo|sidecar|workspace-meta` and `data_root=<absolute path>`
  - sidecar only: `workspace=<name>` (when the marker has one) and `workspace_root=<abs path to _meta>`
  - not inside a git repo → message on stderr, exit 1. Any other outcome exits 0.

- [ ] **Step 1: Write the failing test**

Create `tests/test-resolve-data-root.sh` (mode `755`):

```bash
#!/usr/bin/env bash
# Plain-bash test harness for scripts/resolve-data-root.sh (deps: bash + git; jq optional).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$HERE/../scripts/resolve-data-root.sh"
pass=0; fail=0

# Fixture workspaces are built at runtime (committed fixtures can't hold nested .git dirs).
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mk_repo() { mkdir -p "$1" && git -C "$1" init -q; }

# Marked workspace with two repos, one nested a level deeper
WS="$TMP/ws"
mkdir -p "$WS/_meta"
printf '{ "workspace-os": "sidecar", "workspace": "test-ws" }\n' > "$WS/_meta/workspace.json"
mk_repo "$WS/repo-a"
mkdir -p "$WS/repo-a/src" "$WS/repo-a/docs/project-tracking"   # sidecar must win over in-repo dirs
mkdir -p "$WS/nested"
mk_repo "$WS/nested/repo-b"                                     # marker is in a grandparent
git -C "$WS/_meta" init -q                                      # _meta is itself a git repo

# Unmarked plain repo
mk_repo "$TMP/plain"
# _meta dir WITHOUT workspace.json
mkdir -p "$TMP/ws2/_meta"; mk_repo "$TMP/ws2/repo-c"
# marker present but mode value is not "sidecar"
mkdir -p "$TMP/ws3/_meta"
printf '{ "workspace-os": "off" }\n' > "$TMP/ws3/_meta/workspace.json"
mk_repo "$TMP/ws3/repo-d"
# not a git repo at all
mkdir -p "$TMP/norepo"

# run <dir> -> sets globals ec, out
run() { out="$(cd "$1" && bash "$RESOLVER" 2>&1)"; ec=$?; }

# check <name> <got_ec> <want_ec> <got_out> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec out=[$got_out])"; fail=$((fail+1)); fi
}

run "$WS/repo-a"
check "marked ws: sidecar mode" "$ec" "0" "$out" "mode=sidecar"
check "marked ws: data_root under _meta" "$ec" "0" "$out" "data_root=$WS/_meta/repo-a"
check "marked ws: workspace name" "$ec" "0" "$out" "workspace=test-ws"
check "marked ws: workspace_root" "$ec" "0" "$out" "workspace_root=$WS/_meta"

run "$WS/repo-a/src"
check "resolves from a subdir" "$ec" "0" "$out" "data_root=$WS/_meta/repo-a"

run "$WS/repo-a"
check "sidecar wins over in-repo docs/" "$ec" "0" "$out" "mode=sidecar"

run "$WS/nested/repo-b"
check "grandparent marker found" "$ec" "0" "$out" "data_root=$WS/_meta/repo-b"

run "$WS/_meta"
check "inside _meta itself: workspace-meta mode" "$ec" "0" "$out" "mode=workspace-meta"
check "workspace-meta data_root is _meta" "$ec" "0" "$out" "data_root=$WS/_meta"

run "$TMP/plain"
check "unmarked repo: in-repo mode" "$ec" "0" "$out" "mode=in-repo"
check "in-repo data_root is <repo>/docs" "$ec" "0" "$out" "data_root=$TMP/plain/docs"

run "$TMP/ws2/repo-c"
check "_meta without marker = in-repo" "$ec" "0" "$out" "mode=in-repo"

run "$TMP/ws3/repo-d"
check "marker without sidecar value = in-repo" "$ec" "0" "$out" "mode=in-repo"

run "$TMP/norepo"
check "not a git repo errors" "$ec" "1" "$out" "not inside a git repository"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/test-resolve-data-root.sh`
Expected: FAILs (resolver script does not exist yet; every `run` gets a "No such file" in `out`).

- [ ] **Step 3: Write the resolver**

Create `scripts/resolve-data-root.sh` (mode `755`):

```bash
#!/usr/bin/env bash
# workspace-os data-root resolver — the SINGLE source of mode truth (conventions/data-root.md).
# Where a repo's workspace-os data lives is resolved, never assumed. Prints key=value lines:
#   mode=in-repo|sidecar|workspace-meta
#   data_root=<abs path>            in-repo: <repo>/docs   sidecar: <ws>/_meta/<repo-folder-name>
#   workspace=<name>                sidecar only, when the marker names one
#   workspace_root=<abs path>      sidecar + workspace-meta: the _meta dir
# Not inside a git repo -> message on stderr, exit 1. jq optional (grep fallback).
set -uo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  echo "resolve-data-root: not inside a git repository" >&2
  exit 1
fi

marker_mode() {  # marker_mode <marker-file> -> prints the "workspace-os" value
  if command -v jq >/dev/null 2>&1; then
    jq -r '."workspace-os" // empty' "$1" 2>/dev/null || true
  else
    grep -o '"workspace-os"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null \
      | head -1 | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/'
  fi
}
marker_name() {  # marker_name <marker-file> -> prints the "workspace" value
  if command -v jq >/dev/null 2>&1; then
    jq -r '.workspace // empty' "$1" 2>/dev/null || true
  else
    grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null \
      | head -1 | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/'
  fi
}

# The _meta repo itself: its data root is itself (never _meta/_meta).
if [ "$(basename "$repo_root")" = "_meta" ] && [ -f "$repo_root/workspace.json" ] \
   && [ "$(marker_mode "$repo_root/workspace.json")" = "sidecar" ]; then
  echo "mode=workspace-meta"
  echo "data_root=$repo_root"
  echo "workspace_root=$repo_root"
  exit 0
fi

# Walk up from the repo root's PARENT; nearest marker wins (spec §3).
dir="$(dirname "$repo_root")"
while :; do
  marker="$dir/_meta/workspace.json"
  if [ -f "$marker" ] && [ "$(marker_mode "$marker")" = "sidecar" ]; then
    echo "mode=sidecar"
    echo "data_root=$dir/_meta/$(basename "$repo_root")"
    name="$(marker_name "$marker")"
    [ -n "$name" ] && echo "workspace=$name"
    echo "workspace_root=$dir/_meta"
    exit 0
  fi
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done

echo "mode=in-repo"
echo "data_root=$repo_root/docs"
exit 0
```

Then: `chmod +x scripts/resolve-data-root.sh tests/test-resolve-data-root.sh`

- [ ] **Step 4: Run the tests, verify all pass**

Run: `bash tests/test-resolve-data-root.sh`
Expected: `14 passed, 0 failed`, exit 0.

- [ ] **Step 5: Wire into CI**

In `.github/workflows/ci.yml`, after the line `      - run: bash tests/test-guardrail.sh`, add:

```yaml
      - run: bash tests/test-resolve-data-root.sh
```

- [ ] **Step 6: Commit**

```bash
git add scripts/resolve-data-root.sh tests/test-resolve-data-root.sh .github/workflows/ci.yml
git commit -m "feat(sidecar): data-root resolver — single source of mode truth

<trailer>"
```

---

### Task 2: `guardrail.sh` sidecar config fallback + repo-tree warn backstop

**Files:**
- Modify: `hooks/guardrail.sh:40-45` (config resolution) and `hooks/guardrail.sh:28-37` (Edit/Write case)
- Test: `tests/test-guardrail.sh` (append)

**Interfaces:**
- Consumes: `scripts/resolve-data-root.sh` from Task 1 (`mode=`/`data_root=` lines).
- Produces: unchanged hook contract (deny = exit 2 + stderr; warn = `{"systemMessage": …}` on stdout, exit 0). New behavior: (a) when `<repo>/.claude/guardrails.json` is absent and mode is sidecar, rules load from `<data_root>/guardrails.json`; (b) in sidecar mode, an Edit/Write whose `file_path` matches `docs/project-tracking/`, `docs/memory/`, or `.claude/guardrails.json` inside the repo tree **warns** (safety-invariant backstop).

- [ ] **Step 1: Append failing tests to `tests/test-guardrail.sh`**

Insert before the final `echo "----"` block:

```bash
# --- Task: sidecar mode (config fallback + repo-tree backstop) ---
# Runtime fixture: a marked workspace (committed fixtures can't hold nested .git dirs).
SWTMP="$(mktemp -d)"; trap 'rm -rf "$SWTMP"' EXIT
mkdir -p "$SWTMP/ws/_meta/repo-a" "$SWTMP/ws/repo-a"
printf '{ "workspace-os": "sidecar", "workspace": "gw" }\n' > "$SWTMP/ws/_meta/workspace.json"
git -C "$SWTMP/ws/repo-a" init -q
cat > "$SWTMP/ws/_meta/repo-a/guardrails.json" <<'JSON'
{ "bash": [ { "name": "no-prod", "match": "deploy --prod", "action": "deny", "reason": "sidecar-rule: no prod deploys" } ] }
JSON

# run_hook_in <dir> <json> -> prints "<exit_code>\t<combined output>"  (GUARDRAIL_CONFIG unset)
run_hook_in() {
  local dir="$1" json="$2" out ec
  out="$(cd "$dir" && bash "$HOOK" <<<"$json" 2>&1)"; ec=$?
  printf '%s\t%s' "$ec" "$out"
}

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Bash","tool_input":{"command":"deploy --prod now"}}')
check "sidecar guardrails.json fallback denies" "$ec" "2" "$err" "sidecar-rule"

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"docs/project-tracking/action-items.md","content":"x"}}')
check "sidecar write into repo tracking warns" "$ec" "0" "$err" "sidecar mode"

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"src/app.py","content":"print(1)"}}')
check "sidecar write to normal code passes" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook_in "$SWTMP/ws/repo-a" '{"tool_name":"Write","tool_input":{"file_path":"'"$SWTMP"'/ws/_meta/repo-a/memory/fact.md","content":"x"}}')
check "sidecar write into _meta passes" "$ec" "0" "$err" ""
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `bash tests/test-guardrail.sh`
Expected: all pre-existing checks PASS; the two new "sidecar…denies"/"…warns" checks FAIL (exit 0, no message).

- [ ] **Step 3: Implement in `hooks/guardrail.sh`**

(a) After line 10 (`tool="$(printf …)"`), add the one-time resolution:

```bash
# Sidecar resolution (conventions/data-root.md). Fail open: resolver errors = in-repo behavior.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sc_out="$(bash "$HOOK_DIR/../scripts/resolve-data-root.sh" 2>/dev/null || true)"
sc_mode="$(printf '%s\n' "$sc_out" | sed -n 's/^mode=//p')"
sc_root="$(printf '%s\n' "$sc_out" | sed -n 's/^data_root=//p')"
```

(b) In the `Edit|Write)` case, after the existing `path="$(…)"` line (line 33), add the backstop:

```bash
    if [ "$sc_mode" = "sidecar" ] \
       && printf '%s' "$path" | grep -qE '(^|/)(docs/project-tracking|docs/memory)(/|$)|(^|/)\.claude/guardrails\.json$' \
       && ! printf '%s' "$path" | grep -qF '/_meta/'; then
      warns+=("guardrail: sidecar mode — the workspace-os data layer for this repo lives in _meta/, not in the repo tree ('$path'). See conventions/data-root.md.")
    fi
```

(c) Replace the config-resolution block (lines 40–45) with:

```bash
config="${GUARDRAIL_CONFIG:-}"
if [ -z "$config" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
  config="$root/.claude/guardrails.json"
  # Sidecar fallback: in-repo config wins where present (spec §6).
  if [ ! -f "$config" ] && [ "$sc_mode" = "sidecar" ] && [ -f "$sc_root/guardrails.json" ]; then
    config="$sc_root/guardrails.json"
  fi
fi
```

- [ ] **Step 4: Run the tests, verify all pass**

Run: `bash tests/test-guardrail.sh`
Expected: all checks PASS (existing count + 4 new), exit 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/guardrail.sh tests/test-guardrail.sh
git commit -m "feat(sidecar): guardrail sidecar config fallback + repo-tree warn backstop

<trailer>"
```

---

### Task 3: SessionStart memory-surfacing hook

**Files:**
- Create: `hooks/sidecar-memory-context.sh`
- Modify: `hooks/hooks.json`
- Test: `tests/test-sidecar-memory-context.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: resolver output (`mode=`, `data_root=`, `workspace_root=`).
- Produces: SessionStart hook — stdout is added to the session context. Sidecar mode: emits workspace-tier index (`<workspace_root>/memory/MEMORY.md`) first, then repo-tier index (`<data_root>/memory/MEMORY.md`); either may be absent. In-repo / workspace-meta / resolver-error: prints nothing, exit 0 (the CLAUDE.md import covers in-repo).

- [ ] **Step 1: Write the failing test**

Create `tests/test-sidecar-memory-context.sh` (mode `755`):

```bash
#!/usr/bin/env bash
# Plain-bash test harness for hooks/sidecar-memory-context.sh (deps: bash + git).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/sidecar-memory-context.sh"
pass=0; fail=0

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WS="$TMP/ws"
mkdir -p "$WS/_meta/memory" "$WS/_meta/repo-a/memory"
printf '{ "workspace-os": "sidecar", "workspace": "hooktest" }\n' > "$WS/_meta/workspace.json"
printf '# Memory Index\n- shared fact WS-TIER-CANARY\n' > "$WS/_meta/memory/MEMORY.md"
printf '# Memory Index\n- repo fact REPO-TIER-CANARY\n' > "$WS/_meta/repo-a/memory/MEMORY.md"
git -C "$WS" init -q --initial-branch=main "$WS/repo-a" 2>/dev/null || git -C "$WS/repo-a" init -q
mkdir -p "$WS/repo-b" && git -C "$WS/repo-b" init -q   # sidecar repo with NO memory yet

mk_plain() { mkdir -p "$1" && git -C "$1" init -q; }
mk_plain "$TMP/plain"

check() {
  local name="$1" got_ec="$2" want_ec="$3" got_out="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_out" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec out=[$got_out])"; fail=$((fail+1)); fi
}

out="$(cd "$WS/repo-a" && bash "$HOOK" 2>&1)"; ec=$?
check "sidecar: emits workspace tier" "$ec" "0" "$out" "WS-TIER-CANARY"
check "sidecar: emits repo tier" "$ec" "0" "$out" "REPO-TIER-CANARY"
case "$out" in *WS-TIER-CANARY*REPO-TIER-CANARY*) echo "PASS: workspace tier first"; pass=$((pass+1));;
  *) echo "FAIL: tier order wrong"; fail=$((fail+1));; esac

out="$(cd "$WS/repo-b" && bash "$HOOK" 2>&1)"; ec=$?
check "sidecar repo w/o memory: workspace tier only" "$ec" "0" "$out" "WS-TIER-CANARY"
case "$out" in *REPO-TIER-CANARY*) echo "FAIL: repo-b leaked repo-a memory"; fail=$((fail+1));;
  *) echo "PASS: no cross-repo leak"; pass=$((pass+1));; esac

out="$(cd "$TMP/plain" && bash "$HOOK" 2>&1)"; ec=$?
check "in-repo mode: silent" "$ec" "0" "$out" ""
[ -z "$out" ] && { echo "PASS: in-repo emits nothing"; pass=$((pass+1)); } \
  || { echo "FAIL: in-repo emitted output"; fail=$((fail+1)); }

out="$(cd "$TMP" && bash "$HOOK" 2>&1)"; ec=$?
check "non-repo dir: silent, exit 0" "$ec" "0" "$out" ""

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/test-sidecar-memory-context.sh`
Expected: FAILs (hook file does not exist).

- [ ] **Step 3: Write the hook**

Create `hooks/sidecar-memory-context.sh` (mode `755`):

```bash
#!/usr/bin/env bash
# workspace-os sidecar memory surfacing — SessionStart hook.
# Sidecar mode: emit the workspace-tier MEMORY.md then the repo-tier MEMORY.md on stdout
# (SessionStart stdout is added to session context) — general before specific, spec §6.
# In-repo mode the CLAUDE.md @import covers retrieval: print nothing. Fail open always.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out="$(bash "$HERE/../scripts/resolve-data-root.sh" 2>/dev/null)" || exit 0
mode="$(printf '%s\n' "$out" | sed -n 's/^mode=//p')"
[ "$mode" = "sidecar" ] || exit 0
data_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
ws_root="$(printf '%s\n' "$out" | sed -n 's/^workspace_root=//p')"

if [ -n "$ws_root" ] && [ -f "$ws_root/memory/MEMORY.md" ]; then
  printf '## workspace-os memory — workspace tier (%s)\n' "$ws_root/memory/MEMORY.md"
  cat "$ws_root/memory/MEMORY.md"
  printf '\n'
fi
if [ -n "$data_root" ] && [ -f "$data_root/memory/MEMORY.md" ]; then
  printf '## workspace-os memory — repo tier (%s)\n' "$data_root/memory/MEMORY.md"
  cat "$data_root/memory/MEMORY.md"
fi
exit 0
```

Then: `chmod +x hooks/sidecar-memory-context.sh tests/test-sidecar-memory-context.sh`

- [ ] **Step 4: Run the tests, verify all pass**

Run: `bash tests/test-sidecar-memory-context.sh`
Expected: `8 passed, 0 failed`, exit 0.

- [ ] **Step 5: Register the hook**

Replace the full contents of `hooks/hooks.json` with:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guardrail.sh\"" }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/sidecar-memory-context.sh\"" }
        ]
      }
    ]
  }
}
```

Verify: `jq . hooks/hooks.json` prints without error, and `python3 scripts/validate-plugin.py` exits 0.

- [ ] **Step 6: Wire into CI**

In `.github/workflows/ci.yml`, after the `bash tests/test-resolve-data-root.sh` line added in Task 1, add:

```yaml
      - run: bash tests/test-sidecar-memory-context.sh
```

- [ ] **Step 7: Commit**

```bash
git add hooks/sidecar-memory-context.sh hooks/hooks.json tests/test-sidecar-memory-context.sh .github/workflows/ci.yml
git commit -m "feat(sidecar): SessionStart hook surfaces two-tier sidecar memory

<trailer>"
```

---

### Task 4: `memory_graph.py --link-root` (cross-tier wikilink resolution)

**Files:**
- Modify: `scripts/memory_graph.py:329-350` (main/argparse)
- Test: `tests/test-memory-graph.sh` (append) + create fixture `tests/fixtures/memory-two-tier/`

**Interfaces:**
- Consumes: nothing new.
- Produces: `--link-root DIR` (repeatable). Every `*.md` file stem under each DIR becomes a valid `[[wikilink]]` target (and satisfies dangling-index checks), exactly like `A-`/`D-` records. Link-root dirs are NOT themselves linted.

- [ ] **Step 1: Create the fixture**

```bash
mkdir -p tests/fixtures/memory-two-tier/repo/docs/memory tests/fixtures/memory-two-tier/workspace/memory
```

Create `tests/fixtures/memory-two-tier/repo/docs/memory/forecast-horizon.md`:

```markdown
---
name: forecast-horizon
description: repo-tier fact linking a workspace-tier fact
type: domain
---

The forecast horizon is 14 days, constrained by [[shared-data-contract]].
```

Create `tests/fixtures/memory-two-tier/repo/docs/memory/MEMORY.md`:

```markdown
# Memory Index

- [forecast-horizon](forecast-horizon.md) — 14-day horizon, per the shared contract
```

Create `tests/fixtures/memory-two-tier/workspace/memory/shared-data-contract.md`:

```markdown
---
name: shared-data-contract
description: workspace-tier fact shared by both repos
type: domain
---

Forecasting emits daily demand curves; scheduling consumes them at 06:00.
```

Create `tests/fixtures/memory-two-tier/workspace/memory/MEMORY.md`:

```markdown
# Memory Index

- [shared-data-contract](shared-data-contract.md) — the forecasting→scheduling data contract
```

- [ ] **Step 2: Append failing tests to `tests/test-memory-graph.sh`**

Insert before the final `echo "----"` block:

```bash
# --- two-tier (sidecar): --link-root resolves cross-tier wikilinks ---
TWO="$HERE/fixtures/memory-two-tier"
out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" 2>&1)"; ec=$?
check "cross-tier link WITHOUT --link-root is broken" "$ec" "1" "$out" "shared_data_contract"

out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" \
      --link-root "$TWO/workspace/memory" 2>&1)"; ec=$?
check "cross-tier link WITH --link-root resolves" "$ec" "0" "$out" "clean"

out="$(python3 "$SCRIPT" --check --root "$TWO/repo/docs/memory" \
      --link-root "$TWO/nonexistent" 2>&1)"; ec=$?
check "missing --link-root dir fails open (link broken, no crash)" "$ec" "1" "$out" "shared_data_contract"
```

- [ ] **Step 3: Run to verify the new tests fail**

Run: `bash tests/test-memory-graph.sh`
Expected: existing checks PASS; "WITH --link-root resolves" FAILs (`unrecognized arguments: --link-root`); the two "broken" checks may already pass — that's fine.

- [ ] **Step 4: Implement**

In `scripts/memory_graph.py` `main()`, after the `--tracking-root` `add_argument` call, add:

```python
    ap.add_argument("--link-root", action="append", default=[],
                    help="additional memory dir(s) whose file stems resolve [[wikilinks]] "
                         "(e.g. the sidecar workspace tier); scanned for names only, "
                         "not linted (missing dir = fail open)")
```

After `records = harvest_records(Path(args.tracking_root))`, add:

```python
    for lr in args.link_root:
        lrp = Path(lr)
        if lrp.is_dir():
            for f in sorted(lrp.rglob("*.md")):
                records.add(norm(f.stem))
```

- [ ] **Step 5: Run the tests, verify all pass**

Run: `bash tests/test-memory-graph.sh`
Expected: all checks PASS (existing + 3 new), exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/memory_graph.py tests/test-memory-graph.sh tests/fixtures/memory-two-tier
git commit -m "feat(sidecar): memory_graph --link-root for cross-tier wikilink resolution

<trailer>"
```

---

### Task 5: Conventions — `data-root.md` + the memory tier test

**Files:**
- Create: `conventions/data-root.md`
- Modify: `conventions/memory.md` (insert new section after `## The boundary rule — where a fact belongs`, i.e. after line 33)

**Interfaces:**
- Produces: the canonical prose that Tasks 6–9 reference (never restate rules in skills — this repo's established pattern).

- [ ] **Step 1: Create `conventions/data-root.md`**

```markdown
# Data-Root Resolution

Where a repo's workspace-os data lives is **resolved, never assumed**. The single source of
truth is `scripts/resolve-data-root.sh`; skills and hooks consume its `key=value` output and
never compute data paths themselves. Skills announce the resolved mode in their report
(e.g. "logging to sidecar: `_meta/repo-a/project-tracking/action-items.md`").

## Modes

| mode | when | data_root | tracking | memory |
|---|---|---|---|---|
| `in-repo` | default (no marked workspace) | `<repo>/docs` | `<data_root>/project-tracking/` | `<data_root>/memory/` |
| `sidecar` | repo sits under a marked workspace | `<workspace>/_meta/<repo-folder-name>` | same shape | same shape |
| `workspace-meta` | CWD is inside `_meta/` itself | the `_meta` dir | — | `<data_root>/memory/` (workspace tier) |

## The marker

A **workspace** is any directory that directly contains `_meta/workspace.json`:

    { "workspace-os": "sidecar", "workspace": "<name>" }

- **Sidecar always wins in a marked workspace.** In-repo `docs/project-tracking|memory` under a
  marked workspace are ignored even if present. There is no per-repo override — the workspace
  declares the mode.
- The resolver walks up from the repo root's parent; the **nearest** marker wins. A bare
  `_meta/` without `workspace.json` (or with `"workspace-os"` ≠ `"sidecar"`) marks nothing.
- Repos are keyed by **folder name**. Renaming a repo folder means renaming its `_meta/` entry.

## The sidecar `_meta/` repo

`_meta/` is its own git repo with **no remote** (local-only by design: full history and
recovery via `git log`/`diff`/`checkout` without pushing anywhere). Skills that write records
in sidecar mode **auto-commit to `_meta/` after each write** — per-record history with no user
discipline required. In-repo mode keeps today's behavior (data commits ride with the project
repo; skills do not auto-commit).

## Safety invariant (sidecar mode)

**No workspace-os skill or hook may create, modify, or stage any file inside the repo's
working tree.** This includes the CLAUDE.md memory-import line and `.claude/guardrails.json`
(replaced by the SessionStart memory hook and the guardrail sidecar fallback respectively).
`hooks/guardrail.sh` warns as a backstop if a write targets the repo's data-layer paths in
sidecar mode. Tests assert the resolver, hooks, and fixtures keep the repo tree byte-identical.

## Two-tier memory (sidecar workspaces)

See `conventions/memory.md` § "Two-tier memory in sidecar workspaces" for the tier test,
`/ingest` routing, and cross-tier wikilinks.
```

- [ ] **Step 2: Insert the tier section into `conventions/memory.md`**

Immediately after the `## The boundary rule — where a fact belongs` section (before `## Files (per target repo)`), insert:

```markdown
## Two-tier memory in sidecar workspaces

In a marked workspace (`conventions/data-root.md`), memory has two tiers:

- **Repo tier** — `_meta/<repo>/memory/`: facts specific to one repo.
- **Workspace tier** — `_meta/memory/`: facts true across the whole project — shared domain
  vocabulary, the data contract between the repos, environment/infra facts, team conventions.

Each tier keeps its own `MEMORY.md` index. Retrieval surfaces the workspace tier first, then
the repo tier (general before specific), via the plugin's SessionStart hook.

**The tier test** (applied by `/ingest` after the boundary rule): *would this fact be just as
true and useful in every repo of this workspace?* → workspace tier. Otherwise → repo tier.
`/ingest` defaults to the repo tier and proposes the workspace tier when the test clearly
passes; an explicit user scope request always wins.

**Cross-tier wikilinks are allowed** (a repo fact may link `[[shared-data-contract]]` in the
workspace tier). `/memory-lint` passes the workspace tier as `--link-root` to
`scripts/memory_graph.py` so these resolve. In-repo mode has exactly one tier; nothing changes.
```

- [ ] **Step 3: Verify**

Run: `python3 scripts/validate-plugin.py`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add conventions/data-root.md conventions/memory.md
git commit -m "docs(sidecar): data-root resolution conventions + memory tier test

<trailer>"
```

---

### Task 6: `templates/workspace.json` + `/workspace-init` skill

**Files:**
- Create: `templates/workspace.json`
- Create: `skills/workspace-init/SKILL.md`

**Interfaces:**
- Consumes: `conventions/data-root.md` (Task 5), `templates/memory/MEMORY.md` (exists).
- Produces: a marked, git-initialized `_meta/` — the precondition for every sidecar-mode flow.

- [ ] **Step 1: Create `templates/workspace.json`**

```json
{
  "workspace-os": "sidecar",
  "workspace": "<!-- workspace name, set by /workspace-init -->"
}
```

- [ ] **Step 2: Create `skills/workspace-init/SKILL.md`**

```markdown
---
name: workspace-init
description: Mark a workspace directory for sidecar mode. Use when repos live under one folder (e.g. an employer's codebase dir) and workspace-os data must stay OUT of the repos — creates the local-only _meta/ sidecar repo and its workspace.json marker. After this, every repo under the workspace resolves to sidecar mode.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
---

# Workspace Init

Create and mark a sidecar workspace: a `_meta/` git repo (NO remote — local-only by design)
holding the workspace-os data layer for every repo under this directory. Mode semantics,
marker schema, and the safety invariant live in this plugin's `conventions/data-root.md` —
follow it exactly; do not restate the rules here.

## Steps

1. **Confirm the workspace root.** The target is the directory that CONTAINS the repos (not a
   repo itself). Confirm the absolute path with the user. If the target directory is inside a
   git repository (`git -C <target> rev-parse --show-toplevel` succeeds), stop — a workspace
   root must not be inside a repo.

2. **Refuse if already marked.** If `<target>/_meta/workspace.json` exists, report that the
   workspace is already initialized and stop. If a bare `<target>/_meta/` exists without the
   marker, ask before adopting it.

3. **Ask the workspace name** (short kebab-case, e.g. `acme-work`).

4. **Scaffold.** Create `<target>/_meta/`, then:
   - copy this plugin's `templates/workspace.json` to `_meta/workspace.json`, replacing the
     name placeholder with the chosen name;
   - create `_meta/memory/` and copy `templates/memory/MEMORY.md` into it (the workspace
     tier — see `conventions/memory.md` § two-tier memory).

5. **Init the sidecar repo.** `git -C <target>/_meta init`, then commit everything with
   message `workspace-init: mark <name> as a sidecar workspace`. Do NOT add any remote and do
   not suggest one — local-only is the point.

6. **Verify.** From inside one of the workspace's repos run
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and show the user it prints
   `mode=sidecar`. If the workspace has no repos yet, skip and say so.

7. **Report.** Print the `_meta/` tree and remind the user: `/project-init` inside any repo
   here now stamps `_meta/<repo>/` instead of the repo tree; per-record history accrues in
   `_meta/` automatically; there is NO off-machine backup unless the machine itself is backed
   up.
```

- [ ] **Step 3: Verify the plugin manifest passes**

Run: `python3 scripts/validate-plugin.py`
Expected: exit 0 (it validates SKILL.md frontmatter; a failure here means frontmatter drift — fix to match the other skills').

- [ ] **Step 4: Commit**

```bash
git add templates/workspace.json skills/workspace-init/SKILL.md
git commit -m "feat(sidecar): /workspace-init skill + workspace.json template

<trailer>"
```

---

### Task 7: `/project-init` sidecar branch

**Files:**
- Modify: `skills/project-init/SKILL.md` (full-file replacement below)

**Interfaces:**
- Consumes: resolver, `conventions/data-root.md`.
- Produces: sidecar-mode scaffolding under `_meta/<repo>/` with ZERO in-repo edits.

- [ ] **Step 1: Replace the body of `skills/project-init/SKILL.md`**

Keep the existing frontmatter (lines 1–7) exactly as-is, and replace everything after it with:

```markdown
# Project Init

Bootstrap this repository's workspace-os tracking + memory. Idempotent-safe: refuses if
tracking already exists. Where the data lives is RESOLVED, never assumed — see this plugin's
`conventions/data-root.md`.

The template files live in this plugin's `templates/` directory — i.e. `../../templates/`
relative to this skill's base directory (the plugin root is two levels up from
`skills/project-init/`). Reference them from there.

## Steps

0. **Resolve the data root.** Run and parse (key=value lines):

   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`

   Not in a git repo → stop and say so. Note `mode`, `data_root`, and (sidecar) `workspace_root`.
   Announce the mode to the user before proceeding. In **sidecar** mode, never create, modify,
   or stage any file inside the repo's working tree (`conventions/data-root.md` safety
   invariant) — steps below marked *(in-repo only)* are SKIPPED, and every path is under
   `data_root` (i.e. `_meta/<repo>/`).

1. **Confirm the target.** Confirm with the user that this repo is where they want tracking.

2. **Refuse if already initialized.** If `<data_root>/project-tracking/` already exists, do
   **not** overwrite. Report that it's already set up and stop (offer `/project-log` instead).

3. **Stamp the templates.** Create `<data_root>/project-tracking/` and copy the five `.md`
   templates into it:
   - `templates/README.md` → `<data_root>/project-tracking/README.md`
   - `templates/action-items.md` → `<data_root>/project-tracking/action-items.md`
   - `templates/ideas.md` → `<data_root>/project-tracking/ideas.md`
   - `templates/decisions-log.md` → `<data_root>/project-tracking/decisions-log.md`
   - `templates/resolved.md` → `<data_root>/project-tracking/resolved.md`

3a. **Scaffold memory.** Create `<data_root>/memory/` and copy `templates/memory/MEMORY.md` →
    `<data_root>/memory/MEMORY.md`.

3b. **Wire retrieval** *(in-repo only)*. Add the line `@docs/memory/MEMORY.md` to the repo's
    `CLAUDE.md` — Claude Code's `@`-path import syntax (a bare `@path`, **not** an `@import`
    keyword). If `CLAUDE.md` exists, append the line only if not already present; if it does
    not exist, create it containing that single line plus a one-line comment. Never duplicate
    the line. In sidecar mode this step is replaced by the plugin's SessionStart hook — do
    nothing.

4. **Add the union-merge attributes.** *(in-repo only:)* append the lines from
   `templates/gitattributes` to the repo's `.gitattributes` (create if absent; never duplicate
   lines). *(sidecar:)* append those lines to `<workspace_root>/.gitattributes` instead, with
   each path prefixed by `<repo-folder-name>/` and the `docs/` prefix dropped (e.g.
   `docs/project-tracking/action-items.md merge=union` becomes
   `repo-a/project-tracking/action-items.md merge=union`).

5. **Seed workstreams.** Ask the user: *"What workstreams (areas of work) does this repo
   have?"* (e.g. `data/pipeline, strategy, ML, risk, ops`). Write them as a bullet list into
   the `## Workstreams` section of `<data_root>/project-tracking/README.md`, replacing the
   `<!-- workstream list, seeded by /project-init -->` placeholder.

6. **Commit (sidecar only).** `git -C <workspace_root> add -A` then commit with message
   `project-init: scaffold <repo-folder-name>`. In in-repo mode do **not** commit unless the
   user asks — leave the new files staged-ready for them.

7. **Report.** Print the created trees and the resolved mode, and remind the user they can now
   use `/project-log`, `/project-plan`, `/ingest`, and `/memory-lint`.

## Notes

- All record/schema rules live in this plugin's `conventions/project-tracking.md`; the stamped
  files reference it. Do not restate them here.
- Memory schema/rules live in `conventions/memory.md`; mode rules in `conventions/data-root.md`;
  do not restate them.
```

- [ ] **Step 2: Verify**

Run: `python3 scripts/validate-plugin.py && grep -c "resolve-data-root.sh" skills/project-init/SKILL.md`
Expected: validator exits 0; grep prints `1`.

- [ ] **Step 3: Commit**

```bash
git add skills/project-init/SKILL.md
git commit -m "feat(sidecar): project-init resolves data root, sidecar scaffold + zero in-repo edits

<trailer>"
```

---

### Task 8: `/ingest` tier routing + `/memory-lint` two-tier

**Files:**
- Modify: `skills/ingest/SKILL.md`
- Modify: `skills/memory-lint/SKILL.md`

**Interfaces:**
- Consumes: resolver; `conventions/memory.md` tier test (Task 5); `memory_graph.py --link-root` (Task 4).

- [ ] **Step 1: Edit `skills/ingest/SKILL.md`**

(a) Replace the **Prerequisite** paragraph:

```markdown
**Prerequisite — resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and parse `mode`/`data_root`
(+ `workspace_root` in sidecar mode) — see `conventions/data-root.md`. Memory lives at
`<data_root>/memory/`; if that directory is missing, stop and say so (run `/project-init`
first). Announce the resolved mode in your report. In sidecar mode never write inside the
repo's working tree.
```

(b) In the Steps list, insert a new step between step 1 (boundary test) and the current step 2 (pick the type), renumbering the rest:

```markdown
2. **Apply the tier test (sidecar mode only)** — conventions/memory.md § two-tier memory:
   "would this fact be just as true and useful in every repo of this workspace?" Default is
   the **repo tier** (`<data_root>/memory/`). If the test clearly passes, PROPOSE the
   workspace tier (`<workspace_root>/memory/`) and let the user confirm. An explicit user
   scope request ("workspace level", "just this repo") always wins. In in-repo mode skip
   this step. All later steps use the chosen tier's `memory/` dir and its `MEMORY.md`.
```

(c) Replace the final step ("**Report** the file written…") with:

```markdown
8. **Commit (sidecar mode only)** — `git -C <workspace_root> add -A` then commit with message
   `ingest(<repo-folder-name or workspace>): <slug>`. In in-repo mode do not commit unless asked.
9. **Report** the file written, the tier chosen (sidecar), and the index line added.
```

(d) In the remaining steps, replace every literal `docs/memory/` with `<data_root or chosen tier>/memory/` — the slug-collision check (step 3) and fact-file write (step 5) must check the **chosen tier's** directory.

- [ ] **Step 2: Edit `skills/memory-lint/SKILL.md`**

(a) Replace the **Prerequisite** line with:

```markdown
**Prerequisite — resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` (see `conventions/data-root.md`).
Memory lives at `<data_root>/memory/`; if missing, say so and stop. Announce the resolved mode.
```

(b) Replace the Step 1 command block with:

```markdown
In-repo mode (from the repo root):

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py"

Sidecar mode — pass the resolved paths, plus the workspace tier as a link root so cross-tier
wikilinks resolve (conventions/memory.md § two-tier memory):

    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" \
      --root "<data_root>/memory" \
      --tracking-root "<data_root>/project-tracking" \
      --link-root "<workspace_root>/memory"

To lint the workspace tier itself, run again with `--root "<workspace_root>/memory"` and
`--link-root` pointing at each repo's `_meta/<repo>/memory`.
```

- [ ] **Step 3: Verify**

Run: `python3 scripts/validate-plugin.py && grep -l "resolve-data-root.sh" skills/ingest/SKILL.md skills/memory-lint/SKILL.md`
Expected: validator exits 0; both file paths printed.

- [ ] **Step 4: Commit**

```bash
git add skills/ingest/SKILL.md skills/memory-lint/SKILL.md
git commit -m "feat(sidecar): ingest tier routing + memory-lint two-tier link resolution

<trailer>"
```

---

### Task 9: Uniform "Step 0" across the six remaining skills

**Files:**
- Modify: `skills/project-log/SKILL.md`, `skills/project-plan/SKILL.md`, `skills/memory-sync/SKILL.md`, `skills/memory-adopt/SKILL.md`, `skills/tracking-adopt/SKILL.md`, `skills/continuity/SKILL.md`

**Interfaces:**
- Consumes: resolver, `conventions/data-root.md`.

- [ ] **Step 1: Insert the shared Step 0 block into all six skills**

Insert the following block into each SKILL.md, immediately before its first numbered step (or before its `## Steps`-equivalent section), verbatim in each file:

```markdown
0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in BOTH modes; never
   hardcode `docs/…`. Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).
```

Then, in each file, replace every literal `docs/project-tracking` with `<data_root>/project-tracking` and every literal `docs/memory` with `<data_root>/memory` in the step prose (leave mentions inside quoted conventions references and frontmatter `description:` fields unchanged — descriptions may keep `docs/…` phrasing since they describe the common case).

Per-file additions:

- `skills/project-log/SKILL.md` — where the model-decision `Run:` ledger fallback path is stated
  (`docs/models/<name>.md`), replace it with `<data_root>/models/<name>.md` (in-repo mode this
  is `docs/models/…`, unchanged; sidecar puts the ledger under `_meta/<repo>/models/`).
- `skills/memory-adopt/SKILL.md` — at the step that proposes a CLAUDE.md trim, append:
  `In sidecar mode this proposal is ADVISORY-ONLY: present the suggested trim but never edit the repo's CLAUDE.md (conventions/data-root.md safety invariant).`
- `skills/tracking-adopt/SKILL.md` — at the step that routes/rewrites source docs, append:
  `In sidecar mode, write routed records to <data_root>/project-tracking/ only; source docs in the repo tree are read, summarized, and left byte-identical — any "archive/trim the source doc" step becomes advisory-only.`
- `skills/continuity/SKILL.md` — where the CONTINUITY.md home is stated (repo root per D-20260705-continuity-home-root), append:
  `In sidecar mode, CONTINUITY.md lives at <data_root>/CONTINUITY.md instead of the repo root, and the CLAUDE.md pointer line is skipped.`

- [ ] **Step 2: Verify every skill resolves before acting**

Run:

```bash
python3 scripts/validate-plugin.py && \
for f in project-log project-plan memory-sync memory-adopt tracking-adopt continuity; do
  grep -q "resolve-data-root.sh" "skills/$f/SKILL.md" || echo "MISSING: $f"
done
```

Expected: validator exits 0; no `MISSING:` lines.

- [ ] **Step 3: Commit**

```bash
git add skills/project-log/SKILL.md skills/project-plan/SKILL.md skills/memory-sync/SKILL.md \
        skills/memory-adopt/SKILL.md skills/tracking-adopt/SKILL.md skills/continuity/SKILL.md
git commit -m "feat(sidecar): uniform data-root resolution step across all data-touching skills

<trailer>"
```

---

### Task 10: Docs, version bump, full verification, tracking close-out

**Files:**
- Modify: `ARCHITECTURE.md`, `README.md`, `.claude-plugin/plugin.json`, `docs/project-tracking/action-items.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Update `ARCHITECTURE.md`**

(a) Replace layer 2's opening sentence:

Old:
```
2. **Data (per-repo, version-controlled).** `<repo>/docs/project-tracking/*.md` (tracking records)
```
New:
```
2. **Data (per-repo, version-controlled — location RESOLVED, never assumed).** Default (in-repo
   mode): `<repo>/docs/project-tracking/*.md` (tracking records)
```

(b) At the end of layer 2's paragraph, append:

```
   In a **marked workspace** (`_meta/workspace.json` — see `conventions/data-root.md`), the same
   data layer lives OUT of tree in a local-only `_meta/<repo>/` sidecar git repo instead
   (enterprise repos stay byte-identical to origin); memory gains a workspace tier
   (`_meta/memory/`) shared across the workspace's repos.
```

(c) In the "How the pieces relate" code block, add these lines after the `/project-init` line:

```
/workspace-init ──marks──▶ <workspace>/_meta/ (sidecar git repo, no remote) + workspace.json
resolve-data-root.sh ──answers──▶ mode + data_root   (run FIRST by every skill/hook)
sidecar-memory-context.sh ──SessionStart──▶ injects _meta memory (workspace tier, then repo tier)
```

- [ ] **Step 2: Update `README.md`**

Add `/workspace-init` wherever the skill list is enumerated, with the one-liner: `mark a workspace for sidecar mode — data layer in a local-only _meta/ repo, enterprise repos untouched`. Follow the file's existing list format.

- [ ] **Step 3: Bump the plugin version**

In `.claude-plugin/plugin.json`: `"version": "0.10.0"` → `"version": "0.11.0"`, and in `"description"`, after `(ingest/memory-lint/memory-sync/memory-adopt/tracking-adopt)`, insert ` + sidecar workspace mode (workspace-init)`.

- [ ] **Step 4: Full verification**

```bash
python3 scripts/validate-plugin.py && \
bash tests/test-guardrail.sh && \
bash tests/test-memory-graph.sh && \
bash tests/test-resolve-data-root.sh && \
bash tests/test-sidecar-memory-context.sh
```

Expected: every suite prints `… 0 failed` / validator silent, overall exit 0.

- [ ] **Step 5: Tracking close-out (dogfood)**

In `docs/project-tracking/action-items.md`, in record `A-20260707-sidecar-data-layer`, append a body line:

```markdown
Implemented on feat/sidecar-data-layer (v0.11.0): resolver + /workspace-init + sidecar branches
in all 9 skills + SessionStart memory hook + guardrail fallback/backstop + memory_graph
--link-root + conventions/data-root.md. Move to resolved.md via /project-log done after the PR
merges.
```

(The record moves to `resolved.md` only after merge — do not move it now.)

- [ ] **Step 6: Commit**

```bash
git add ARCHITECTURE.md README.md .claude-plugin/plugin.json docs/project-tracking/action-items.md
git commit -m "docs(sidecar): architecture/readme + v0.11.0 + tracking progress note

<trailer>"
```

- [ ] **Step 7: Push and open the PR**

```bash
git push -u origin feat/sidecar-data-layer
gh pr create --title "Sidecar data layer: workspace _meta/ mode for enterprise repos (v0.11.0)" \
  --body "Implements docs/specs/2026-07-07-sidecar-data-layer-design.md — resolver, /workspace-init, sidecar branches in all skills, SessionStart two-tier memory hook, guardrail fallback + backstop, memory_graph --link-root, conventions/data-root.md. Closes A-20260707-sidecar-data-layer on merge.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

Then wait for the `validate` workflow to go green **before any merge** (CI is advisory on this repo — green CI is a hard gate by project convention). Do not merge without explicit user approval.
