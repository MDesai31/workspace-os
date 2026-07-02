# Guardrail Engine + Provenance Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one portable PreToolUse guardrail engine that applies declarative per-repo rules (plus warn-only built-in defaults) to Bash and Edit/Write, denying or warning as configured.

**Architecture:** A single bash+jq hook script (`hooks/guardrail.sh`) is the engine, registered once in the plugin's `hooks/hooks.json` on `Bash|Edit|Write`. It reads per-repo `.claude/guardrails.json` (the data) and applies built-in defaults baked into the engine. Deny → exit 2 with reason on stderr; warn → reason on stderr, exit 0. Fail-open on every error path. Replaces `hooks/memory-secret-guard.sh`.

**Tech Stack:** Bash, `jq` (present on GitHub `ubuntu-latest` and the user's machine), plain-bash test harness, GitHub Actions.

## Global Constraints

- **Fail open, always.** No config / no match / malformed JSON / missing `jq` / any error → exit 0. The engine *only* blocks via an explicit `deny` match (exit 2). Never abort a tool call on engine failure.
- **Deny = exit 2 + reason on stderr. Warn = reason on stderr, exit 0.** (PreToolUse contract; same warn mechanism as the current `memory-secret-guard.sh`.)
- **Built-in defaults are warn-only**, except three high-confidence secret patterns which deny: `-----BEGIN [A-Z ]*PRIVATE KEY-----`, `AKIA[0-9A-Z]{16}`, `sk-[A-Za-z0-9]{20,}`. Warn-only ensures no conflict with the user's global `~/.claude/hooks/guard.sh`.
- **Engine reads only `.bash` and `.write` from the config.** `ip_class` and any `_`-prefixed key are informational and ignored by matching.
- **Config path:** `$GUARDRAIL_CONFIG` if set (test override), else `<repo-root>/.claude/guardrails.json` where repo-root = `git rev-parse --show-toplevel`, falling back to `$CLAUDE_PROJECT_DIR`, then `$PWD`.
- **No new runtime dependencies** beyond bash + jq. Tests are plain bash. Do not add bats.
- **Hook script must be `chmod +x`.**

---

### Task 1: Test harness + engine skeleton (high-confidence secret deny)

**Files:**
- Create: `hooks/guardrail.sh`
- Create: `tests/test-guardrail.sh`

**Interfaces:**
- Produces: `hooks/guardrail.sh` — a PreToolUse hook reading tool-call JSON on stdin, exiting 2 (deny) / 0 (warn or pass). `tests/test-guardrail.sh` — a runnable harness with a `run_hook <json> [config]` helper printing `"<exit>\t<stderr>"` and a `check <name> <got_ec> <want_ec> <got_err> <want_substr>` assertion, tracking `pass`/`fail` counts and exiting non-zero if any fail.

- [ ] **Step 1: Write the failing test harness + first cases**

Create `tests/test-guardrail.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash test harness for hooks/guardrail.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/guardrail.sh"
FIX="$HERE/fixtures"
pass=0; fail=0

# run_hook <json> [config_path] -> prints "<exit_code>\t<stderr>"
run_hook() {
  local json="$1" cfg="${2:-}" err ec
  err="$(GUARDRAIL_CONFIG="$cfg" bash "$HOOK" <<<"$json" 2>&1 1>/dev/null)"; ec=$?
  printf '%s\t%s' "$ec" "$err"
}

# check <name> <got_ec> <want_ec> <got_err> <want_substr>
check() {
  local name="$1" got_ec="$2" want_ec="$3" got_err="$4" want="$5" ok=1
  [ "$got_ec" = "$want_ec" ] || ok=0
  if [ -n "$want" ]; then case "$got_err" in *"$want"*) ;; *) ok=0;; esac; fi
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (exit=$got_ec want=$want_ec stderr=[$got_err])"; fail=$((fail+1)); fi
}

# --- Task 1: high-confidence secret deny + benign pass ---
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"a.txt","content":"key AKIA1234567890ABCDEF here"}}')
check "AKIA secret denies" "$ec" "2" "$err" "secret"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"a.txt","content":"hello world"}}')
check "benign write passes" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}')
check "benign bash passes" "$ec" "0" "$err" ""

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/test-guardrail.sh`
Expected: FAIL — `hooks/guardrail.sh` does not exist yet (harness errors / all checks fail).

- [ ] **Step 3: Write the minimal engine**

Create `hooks/guardrail.sh`:

```bash
#!/usr/bin/env bash
# workspace-os guardrail engine — PreToolUse hook (Bash|Edit|Write).
# Reads tool-call JSON on stdin. Deny -> exit 2 + reason on stderr; warn -> reason on stderr, exit 0.
# Fail open: any error / no jq / no match -> exit 0 (never block a tool call).
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0   # can't parse -> fail open

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
denies=(); warns=()

case "$tool" in
  Edit|Write)
    content="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null || true)"
    if printf '%s' "$content" | grep -qE '(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,})'; then
      denies+=("guardrail: high-confidence secret detected in write content. Remove it before writing.")
    fi
    ;;
esac

if [ "${#denies[@]}" -gt 0 ]; then printf '%s\n' "${denies[@]}" >&2; exit 2; fi
if [ "${#warns[@]}" -gt 0 ]; then printf '%s\n' "${warns[@]}" >&2; fi
exit 0
```

- [ ] **Step 4: Make executable and run**

Run: `chmod +x hooks/guardrail.sh && bash tests/test-guardrail.sh`
Expected: PASS on all three checks; `3 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add hooks/guardrail.sh tests/test-guardrail.sh
git commit -m "feat(guardrail): engine skeleton + high-confidence secret deny

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Generic secret-content warn (Edit/Write)

**Files:**
- Modify: `hooks/guardrail.sh` (Edit|Write branch)
- Modify: `tests/test-guardrail.sh`

**Interfaces:**
- Consumes: `hooks/guardrail.sh` Edit|Write branch from Task 1.
- Produces: warn-only secret-content check (folds in `memory-secret-guard.sh`'s regex), broadened to all Edit/Write.

- [ ] **Step 1: Add the failing tests**

Append to `tests/test-guardrail.sh` before the `echo "----"` summary block:

```bash
# --- Task 2: generic secret-content warn ---
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"c.py","content":"api_key = \"foo\""}}')
check "api_key warns not denies" "$ec" "0" "$err" "possible secret"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"c.py","new_string":"PASSWORD=hunter2"}}')
check "password in new_string warns" "$ec" "0" "$err" "possible secret"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/test-guardrail.sh`
Expected: the two new checks FAIL (exit 0 but stderr lacks "possible secret").

- [ ] **Step 3: Extend the engine**

In `hooks/guardrail.sh`, in the `Edit|Write)` branch, after the high-confidence deny block and before the `;;`, add:

```bash
    path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    if printf '%s' "$content" | grep -qEi '(api[_-]?key|secret|token|password)'; then
      warns+=("guardrail: possible secret in write content ('$path'). Files are version-controlled — do not commit secrets.")
    fi
```

- [ ] **Step 4: Run to verify pass**

Run: `bash tests/test-guardrail.sh`
Expected: all checks PASS. (Note: the AKIA case still denies — deny takes precedence over any warn.)

- [ ] **Step 5: Commit**

```bash
git add hooks/guardrail.sh tests/test-guardrail.sh
git commit -m "feat(guardrail): warn-only secret-content default (from memory-secret-guard)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Bash built-in defaults (force-push + rm -rf)

**Files:**
- Modify: `hooks/guardrail.sh` (add a `Bash)` branch)
- Modify: `tests/test-guardrail.sh`

**Interfaces:**
- Consumes: engine `case "$tool"` dispatch from Task 1.
- Produces: two warn-only Bash defaults. Sets `cmd` (the Bash command string) for Task 4 to reuse.

- [ ] **Step 1: Add the failing tests**

Append to `tests/test-guardrail.sh` before the summary block:

```bash
# --- Task 3: bash built-in defaults ---
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}')
check "force-push to main warns" "$ec" "0" "$err" "force-push"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}')
check "rm -rf root warns" "$ec" "0" "$err" "rm"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"git push origin feature"}}')
check "normal push passes" "$ec" "0" "$err" ""
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/test-guardrail.sh`
Expected: the force-push and rm -rf checks FAIL (no matching stderr).

- [ ] **Step 3: Add the `Bash)` branch**

In `hooks/guardrail.sh`, add a new case arm before `Edit|Write)`:

```bash
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push' \
       && printf '%s' "$cmd" | grep -qE -- '(--force|-f)([[:space:]]|$)' \
       && printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(main|master)([[:space:]]|$)'; then
      warns+=("guardrail: force-push to a protected branch (main/master).")
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])rm([[:space:]]|$)' \
       && printf '%s' "$cmd" | grep -qE '\-[a-zA-Z]*r' \
       && printf '%s' "$cmd" | grep -qE '\-[a-zA-Z]*f' \
       && printf '%s' "$cmd" | grep -qE '[[:space:]](/|~|\.|\*)([[:space:]/]|$)'; then
      warns+=("guardrail: 'rm' with -r and -f targeting a root-like path.")
    fi
    ;;
```

- [ ] **Step 4: Run to verify pass**

Run: `bash tests/test-guardrail.sh`
Expected: all checks PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/guardrail.sh tests/test-guardrail.sh
git commit -m "feat(guardrail): warn-only bash defaults (force-push, rm -rf)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Per-repo declarative rules + fail-open

**Files:**
- Modify: `hooks/guardrail.sh` (per-repo rule evaluation)
- Modify: `tests/test-guardrail.sh`
- Create: `tests/fixtures/guardrails.json`
- Create: `tests/fixtures/malformed.json`

**Interfaces:**
- Consumes: `cmd` (Task 3), `path`/`content` (Tasks 1–2), the `denies`/`warns` arrays, and the emit block.
- Produces: config-driven `bash` and `write` rules. `bash` rules match `.command`; `write` rules match `.file_path` (`field:"path"`) or content (`field:"content"`, default). `deny` → `denies`, `warn` → `warns`.

- [ ] **Step 1: Create fixtures**

Create `tests/fixtures/guardrails.json`:

```json
{
  "ip_class": "clean-room",
  "bash": [
    { "name": "no-raw-duckdb", "match": "duckdb\\.connect\\(", "action": "deny", "reason": "Use mcp__duckdb__query, not a raw DuckDB connection." }
  ],
  "write": [
    { "name": "employer-tripwire", "match": "AcmeCorpInternal", "field": "content", "action": "warn", "reason": "clean-room repo: write matches an employer tripwire." },
    { "name": "no-env-path", "match": "\\.env$", "field": "path", "action": "deny", "reason": "This repo forbids writing .env files." }
  ]
}
```

Create `tests/fixtures/malformed.json`:

```json
{ "bash": [ this is not valid json
```

- [ ] **Step 2: Add the failing tests**

Append to `tests/test-guardrail.sh` before the summary block:

```bash
# --- Task 4: per-repo rules + fail-open ---
CFG="$FIX/guardrails.json"
IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"python -c \"import duckdb; duckdb.connect(1)\""}}' "$CFG")
check "per-repo bash deny" "$ec" "2" "$err" "mcp__duckdb__query"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"x.py","content":"see AcmeCorpInternal notes"}}' "$CFG")
check "per-repo write content warn" "$ec" "0" "$err" "tripwire"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Write","tool_input":{"file_path":"config/.env","content":"X=1"}}' "$CFG")
check "per-repo write path deny" "$ec" "2" "$err" "forbids writing .env"

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}' "$CFG")
check "per-repo no-match passes" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"duckdb.connect("}}' "$FIX/malformed.json")
check "malformed config fails open" "$ec" "0" "$err" ""

IFS=$'\t' read -r ec err < <(run_hook '{"tool_name":"Bash","tool_input":{"command":"duckdb.connect("}}' "$FIX/nonexistent.json")
check "missing config fails open" "$ec" "0" "$err" ""
```

- [ ] **Step 3: Run to verify it fails**

Run: `bash tests/test-guardrail.sh`
Expected: the per-repo deny/warn checks FAIL (config not read yet). The fail-open checks may pass incidentally.

- [ ] **Step 4: Add config resolution + rule evaluation**

In `hooks/guardrail.sh`, after the `esac` that closes the tool `case` and **before** the emit block, add:

```bash
config="${GUARDRAIL_CONFIG:-}"
if [ -z "$config" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
  config="$root/.claude/guardrails.json"
fi

if [ -n "$config" ] && [ -f "$config" ] && jq -e . "$config" >/dev/null 2>&1; then
  case "$tool" in
    Bash)
      while IFS=$'\t' read -r action reason; do
        [ -z "$action" ] && continue
        if [ "$action" = "deny" ]; then denies+=("$reason"); else warns+=("$reason"); fi
      done < <(jq -r --arg s "${cmd:-}" \
        '(.bash // [])[] | select(.match and ($s | test(.match))) | "\(.action)\t\(.reason)"' \
        "$config" 2>/dev/null)
      ;;
    Edit|Write)
      while IFS=$'\t' read -r action reason; do
        [ -z "$action" ] && continue
        if [ "$action" = "deny" ]; then denies+=("$reason"); else warns+=("$reason"); fi
      done < <(jq -r --arg path "${path:-}" --arg content "${content:-}" \
        '(.write // [])[] | select(.match and ((if (.field // "content") == "path" then $path else $content end) | test(.match))) | "\(.action)\t\(.reason)"' \
        "$config" 2>/dev/null)
      ;;
  esac
fi
```

(Note: `path` is set in the Edit|Write branch in Task 2; `cmd` in the Bash branch in Task 3. The `${cmd:-}`/`${path:-}` guards keep `set -u` happy when the other branch ran.)

- [ ] **Step 5: Run to verify pass**

Run: `bash tests/test-guardrail.sh`
Expected: all checks PASS; summary `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add hooks/guardrail.sh tests/test-guardrail.sh tests/fixtures/guardrails.json tests/fixtures/malformed.json
git commit -m "feat(guardrail): per-repo declarative rules + fail-open config handling

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire the engine in, retire memory-secret-guard, ship the template

**Files:**
- Modify: `hooks/hooks.json`
- Delete: `hooks/memory-secret-guard.sh`
- Create: `templates/guardrails.json`

**Interfaces:**
- Consumes: `hooks/guardrail.sh` (Tasks 1–4).
- Produces: the engine registered on `Bash|Edit|Write`; the old hook removed; a copy-ready per-repo template.

- [ ] **Step 1: Rewrite `hooks/hooks.json`**

Replace the entire file contents with:

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
    ]
  }
}
```

- [ ] **Step 2: Delete the retired hook**

Run: `git rm hooks/memory-secret-guard.sh`
Expected: file staged for deletion.

- [ ] **Step 3: Create the per-repo template**

Create `templates/guardrails.json`:

```json
{
  "_comment": "workspace-os guardrail rules for THIS repo. Copy to .claude/guardrails.json and edit. The engine reads only `bash` and `write`; `ip_class` and any `_`-prefixed key are informational. deny -> blocks the tool call; warn -> advisory message. Built-in warn-only defaults (secrets, force-push, rm -rf) always run regardless of this file.",
  "ip_class": "personal",
  "bash": [],
  "write": [],
  "_examples": {
    "bash": [
      { "name": "no-raw-duckdb", "match": "duckdb\\.connect\\(", "action": "deny", "reason": "Use mcp__duckdb__query, not a raw DuckDB connection." }
    ],
    "write": [
      { "name": "employer-tripwire", "match": "AcmeCorpInternal|acme\\.internal", "field": "content", "action": "warn", "reason": "clean-room repo: this write matches an employer tripwire string." }
    ]
  }
}
```

- [ ] **Step 4: Verify JSON validity and that tests still pass**

Run: `jq -e . hooks/hooks.json templates/guardrails.json >/dev/null && echo OK && bash tests/test-guardrail.sh`
Expected: `OK` then `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json templates/guardrails.json
git commit -m "feat(guardrail): register engine on Bash|Edit|Write; retire memory-secret-guard; add template

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: CI, docs, and tracking close-out

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/project-tracking/decisions-log.md`
- Modify: `docs/project-tracking/action-items.md`
- Modify: `docs/project-tracking/resolved.md`
- Modify: `docs/project-tracking/ideas.md`

**Interfaces:**
- Consumes: the full engine + tests.
- Produces: CI runs the harness; docs describe the guardrail layer; tracking reflects the shipped slice.

- [ ] **Step 1: Add the test step to CI**

In `.github/workflows/ci.yml`, add a step after the `validate-plugin.py` run:

```yaml
      - run: bash tests/test-guardrail.sh
```

- [ ] **Step 2: Document in ARCHITECTURE.md**

In `ARCHITECTURE.md`, in the "How the pieces relate" diagram block, add this line after the `/tracking-adopt` line:

```
guardrail.sh  ──reads──▶ <repo>/.claude/guardrails.json   (PreToolUse deny/warn on Bash|Edit|Write)
```

And after that code block, add a short paragraph:

```markdown
- **The guardrail engine** (`hooks/guardrail.sh`) is a PreToolUse hook: warn-only built-in defaults
  (secrets, force-push, `rm -rf`) plus declarative per-repo rules in `.claude/guardrails.json`
  (`bash`/`write` rules, `deny` blocks / `warn` advises). Opt in by copying `templates/guardrails.json`;
  the engine fails open when the file is absent. Same engine/data split as the rest of the plugin.
```

- [ ] **Step 3: Document in README.md**

In `README.md`, add a `## Guardrails` section (place it after the memory/tracking sections; match the file's existing heading style):

```markdown
## Guardrails

A PreToolUse hook (`hooks/guardrail.sh`) guards Bash and Edit/Write calls. It ships **warn-only
built-in defaults** — possible secrets in writes, force-push to `main`/`master`, `rm -rf` on
root-like paths — plus **high-confidence secret denies** (private-key blocks, `AKIA…`, `sk-…`).

Per-repo rules are declarative: copy `templates/guardrails.json` to `.claude/guardrails.json` and add
`bash` / `write` rules (`{name, match, action: "deny"|"warn", reason}`; `write` rules match `content`
or `path` via `field`). `deny` blocks the call; `warn` prints an advisory. The engine fails open when
no config is present, so it's opt-in per repo. Tag the repo with `ip_class`
(`personal`/`employer`/`clean-room`) and add tripwire `write` rules for cross-boundary IP leakage.
```

- [ ] **Step 4: Run full local verification**

Run: `python3 scripts/validate-plugin.py && bash tests/test-guardrail.sh`
Expected: `Plugin validation passed (8 skills checked).` then `0 failed`.

- [ ] **Step 5: Tracking close-out**

Append to `docs/project-tracking/decisions-log.md`:

```markdown
### D-20260701-guardrail-engine — one guardrail engine, two rule packs (warn-only defaults; deny=exit 2)
- Workstream: workflow
- Created: 2026-07-01
- Rationale: folded hook-starter-library + provenance-guard into ONE portable PreToolUse engine + per-repo `.claude/guardrails.json` (engine/data split, no external-plugin dependency — the "carry the engine job-to-job" premise rejects that coupling). Built-in defaults are warn-only so they never conflict with the user's global `~/.claude/hooks/guard.sh` (which already hard-denies secrets + asks on destructive); workspace-os's value-add is the declarative per-repo rules + provenance `ip_class`, not re-shipping generic denies. Only high-confidence secret patterns deny. `.env`/generic secrets warn (a hard deny bites `.env.example`, local `.env`, fake-key fixtures). deny=exit 2 + stderr, warn=stderr+exit 0 (version-stable PreToolUse contract; `additionalContext` is not a PreToolUse field). Retired `memory-secret-guard.sh` into the engine (broadened docs/memory→all writes). Deferred: PostToolUse lint template, `/guardrails` skill, `project-init` wiring.
- Spawns: A-20260701-guardrail-engine

Full design: `docs/specs/2026-07-01-guardrail-engine-design.md`. Plan: `docs/plans/2026-07-01-guardrail-engine.md`.
```

Move `A-20260701-guardrail-engine` out of `action-items.md` (delete the record there, restoring `_No open items yet._` if it becomes empty) and append it to `docs/project-tracking/resolved.md` with two lines added to its body:

```markdown
- Completed: 2026-07-01
- Commit: <PR # or merge sha — fill at merge>
```

In `docs/project-tracking/ideas.md`, update the two ideas: under `hook-starter-library`, add a `- **Shipped (2026-07-01):**` line noting the generic command/content guardrail engine + per-repo `guardrails.json` landed (A-20260701-guardrail-engine; D-20260701-guardrail-engine), with the PostToolUse lint template as the remaining sub-slice. Under `provenance-guard`, add a `- **Shipped (2026-07-01):**` line noting the `ip_class` tag + tripwire rules pack shipped via the same engine.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml README.md ARCHITECTURE.md docs/project-tracking/
git commit -m "guardrail engine: CI wiring, docs, tracking close-out

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the executor

- After Task 6, open a PR from `guardrail-engine` into `main`; fill the `Commit:` line in `resolved.md` with the PR number, then push the amend (or add a follow-up line). Wait for green CI before merge (per project convention).
- The spec is the source of truth for intent: `docs/specs/2026-07-01-guardrail-engine-design.md`.
