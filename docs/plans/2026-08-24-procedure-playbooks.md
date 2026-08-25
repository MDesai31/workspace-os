# Procedure Playbooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playbook artifact class (trigger, steps, verify, traps) surfaced at trigger time — `before` via a once-per-session PreToolUse deny-and-retry, `after` via PostToolUse `additionalContext` — plus a `/playbook` author/adopt/list skill.

**Architecture:** `hooks/playbook-surface.sh` runs on both PreToolUse and PostToolUse (`Bash|Edit|Write`), scans `<data_root>/playbooks/` and `<workspace_root>/playbooks/` frontmatter, matches `trigger-bash`/`trigger-path` EREs, and gates on per-session marker files. The skill writes playbooks directly (no helper script — each playbook is its own file). SoT: `conventions/playbooks.md`.

**Tech Stack:** bash + jq (hook), plain-bash tests, markdown skill.

**Spec:** `docs/specs/2026-08-24-procedure-playbooks-design.md`

## Global Constraints

- Hook deps bash + jq only; EVERY hook failure path is silent `exit 0` (fail open).
- Frontmatter is FLAT (`key: value` lines between the first two `---` lines); triggers are EREs evaluated with `grep -E`.
- Surfacing at most once per session per playbook; marker dir `${TMPDIR:-/tmp}/workspace-os-surfaced-<session_id>/`; markers written BEFORE surfacing so the post-deny retry passes.
- One deny per call: first unmarked matching playbook (dir order: repo tier then workspace tier; glob order within) wins.
- Commits on `feature/procedure-playbooks`, `type(scope): summary`, standard Co-Authored-By + Claude-Session trailer.
- Version lands at 0.24.0 (Task 3). CI checked in the FOREGROUND (`gh pr checks`), never a background watcher.

---

### Task 1: Surfacing hook

**Files:**
- Create: `hooks/playbook-surface.sh` (chmod +x)
- Test: `tests/test-playbook-surface.sh` (chmod +x)

**Interfaces:**
- Consumes: hook JSON on stdin (`hook_event_name`, `session_id`, `tool_name`, `tool_input.command`/`.file_path`); `scripts/resolve-data-root.sh`; playbook files with flat frontmatter keys `name`, `trigger-bash`, `trigger-path`, `surface`.
- Produces: `before`+PreToolUse → exit 2, stderr `playbook '<name>' applies to this call - read <abs path> first, then retry.`; `after`+PostToolUse → stdout `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}`; everything else silent exit 0. Task 2's skill and conventions doc describe exactly this contract.

- [ ] **Step 1: Write the failing tests**

Create `tests/test-playbook-surface.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash test harness for hooks/playbook-surface.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/playbook-surface.sh"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1${2:+ ($2)}"; fail=$((fail+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmp"; mkdir -p "$TMPDIR"   # markers land here, not /tmp

# in-repo fixture: git repo with docs/playbooks/
R="$TMP/repo"; mkdir -p "$R/docs/playbooks"; git -C "$R" init -q
cat > "$R/docs/playbooks/snowflake.md" <<'EOF'
---
name: snowflake-querying
description: query snowflake safely
trigger-bash: sfq\.py
surface: before
---
# Snowflake querying
## Steps
- always use --dry-run first
EOF
cat > "$R/docs/playbooks/notebooks.md" <<'EOF'
---
name: notebook-editing
description: edit notebooks safely
trigger-path: \.ipynb$
surface: after
---
# Notebook editing
## Known traps
- never edit raw JSON by hand
EOF

# call <event> <session> <tool> <json-field> <value> -> $out (stdout), $err, $ec
call() {
  local ev="$1" sid="$2" tool="$3" field="$4" val="$5"
  local json; json="$(jq -cn --arg ev "$ev" --arg sid "$sid" --arg tool "$tool" \
    --arg f "$field" --arg v "$val" '{hook_event_name:$ev, session_id:$sid, tool_name:$tool,
    tool_input: {($f): $v}}')"
  out="$(cd "$R" && printf '%s' "$json" | bash "$HOOK" 2>"$TMP/err")"; ec=$?
  err="$(cat "$TMP/err")"
}

# --- before-mode: first matching Bash call denies with path ---
call PreToolUse s1 Bash command "python sfq.py --query 'select 1'"
[ "$ec" = 2 ] && ok "before: first match denies (exit 2)" || bad "before: first match denies" "ec=$ec"
case "$err" in *"snowflake-querying"*) ok "before: reason names playbook";; *) bad "before: reason names playbook" "err=[$err]";; esac
case "$err" in *"/docs/playbooks/snowflake.md"*) ok "before: reason carries path";; *) bad "before: reason carries path" "err=[$err]";; esac

# --- same session second call passes; different session denies again ---
call PreToolUse s1 Bash command "python sfq.py again"
[ "$ec" = 0 ] && [ -z "$out$err" ] && ok "before: same session passes silently" || bad "before: same session passes silently" "ec=$ec"
call PreToolUse s2 Bash command "python sfq.py again"
[ "$ec" = 2 ] && ok "before: new session denies again" || bad "before: new session denies again" "ec=$ec"

# --- after-mode: PostToolUse Edit on .ipynb injects additionalContext once ---
call PostToolUse s3 Edit file_path "$R/nb/analysis.ipynb"
[ "$ec" = 0 ] && ok "after: exit 0" || bad "after: exit 0" "ec=$ec"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("never edit raw JSON")' >/dev/null 2>&1; then
  ok "after: body injected via additionalContext"
else bad "after: body injected via additionalContext" "out=[$out]"; fi
call PostToolUse s3 Edit file_path "$R/nb/analysis.ipynb"
[ "$ec" = 0 ] && [ -z "$out" ] && ok "after: once per session" || bad "after: once per session" "out=[$out]"

# --- mode/event cross-silence ---
call PostToolUse s4 Bash command "python sfq.py x"
[ "$ec" = 0 ] && [ -z "$out" ] && ok "before-playbook silent on PostToolUse" || bad "before-playbook silent on PostToolUse" "ec=$ec out=[$out]"
call PreToolUse s4 Edit file_path "$R/nb/analysis.ipynb"
[ "$ec" = 0 ] && [ -z "$out$err" ] && ok "after-playbook silent on PreToolUse" || bad "after-playbook silent on PreToolUse" "ec=$ec"

# --- ordering: two before-playbooks matching one command deny one at a time ---
cat > "$R/docs/playbooks/aaa-first.md" <<'EOF'
---
name: aaa-first
trigger-bash: doubletrig
surface: before
---
body
EOF
cat > "$R/docs/playbooks/zzz-second.md" <<'EOF'
---
name: zzz-second
trigger-bash: doubletrig
surface: before
---
body
EOF
call PreToolUse s5 Bash command "doubletrig now"
case "$err" in *"aaa-first"*) ok "ordering: first slug denies first";; *) bad "ordering: first slug denies first" "err=[$err]";; esac
call PreToolUse s5 Bash command "doubletrig now"
case "$err" in *"zzz-second"*) ok "ordering: second slug denies on next call";; *) bad "ordering: second slug denies on next call" "err=[$err]";; esac
call PreToolUse s5 Bash command "doubletrig now"
[ "$ec" = 0 ] && ok "ordering: both marked -> pass" || bad "ordering: both marked -> pass" "ec=$ec"

# --- long body (>300 lines) -> pointer instead of content ---
{ printf -- '---\nname: long-one\ntrigger-bash: longtrig\nsurface: after\n---\n'
  for i in $(seq 1 320); do echo "line $i"; done; } > "$R/docs/playbooks/long-one.md"
call PostToolUse s6 Bash command "longtrig go"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | (contains("read ") and (contains("line 250") | not))' >/dev/null 2>&1; then
  ok "long body -> read-path instruction"
else bad "long body -> read-path instruction" "out=[$out]"; fi

# --- silence paths ---
call PreToolUse s7 Bash command "git status"
[ "$ec" = 0 ] && [ -z "$out$err" ] && ok "non-matching call silent" || bad "non-matching call silent" "ec=$ec"
printf 'garbage no frontmatter' > "$R/docs/playbooks/broken.md"
call PreToolUse s7 Bash command "git status"
[ "$ec" = 0 ] && ok "malformed playbook skipped" || bad "malformed playbook skipped" "ec=$ec"
printf -- '---\nname: no-trig\n---\nbody' > "$R/docs/playbooks/no-trig.md"
call PreToolUse s7 Bash command "anything at all"
[ "$ec" = 0 ] && ok "trigger-less playbook never surfaces" || bad "trigger-less playbook never surfaces" "ec=$ec"
R2="$TMP/no-pb"; mkdir -p "$R2"; git -C "$R2" init -q
out="$(cd "$R2" && printf '{"hook_event_name":"PreToolUse","session_id":"s8","tool_name":"Bash","tool_input":{"command":"sfq.py"}}' | bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && ok "no playbooks dir silent" || bad "no playbooks dir silent" "ec=$ec"
out="$(printf 'not json' | bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && ok "malformed stdin silent" || bad "malformed stdin silent" "ec=$ec"

# --- workspace tier: sidecar repo surfaces workspace playbook ---
WS="$TMP/ws"; mkdir -p "$WS/_meta/playbooks" "$WS/repo-a"
printf '{"workspace-os":"sidecar","workspace":"t"}\n' > "$WS/_meta/workspace.json"
git -C "$WS/repo-a" init -q
cat > "$WS/_meta/playbooks/ws-play.md" <<'EOF'
---
name: ws-play
trigger-bash: wstrig
surface: before
---
body
EOF
json='{"hook_event_name":"PreToolUse","session_id":"s9","tool_name":"Bash","tool_input":{"command":"wstrig go"}}'
err9="$(cd "$WS/repo-a" && printf '%s' "$json" | bash "$HOOK" 2>&1 >/dev/null)"; ec=$?
[ "$ec" = 2 ] && ok "workspace-tier playbook surfaces in sidecar repo" || bad "workspace-tier playbook surfaces in sidecar repo" "ec=$ec err=[$err9]"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-playbook-surface.sh`
Expected: FAILs everywhere (hook missing, exit 127).

- [ ] **Step 3: Implement the hook**

Create `hooks/playbook-surface.sh`:

```bash
#!/usr/bin/env bash
# workspace-os playbook surfacing — PreToolUse + PostToolUse hook (Bash|Edit|Write).
# Surfaces a matching playbook at most once per session per playbook:
#   surface: before -> PreToolUse deny-once (exit 2; stderr instructs read + retry;
#                      the marker is written FIRST so the retry passes)
#   surface: after  -> PostToolUse additionalContext injection (body, or a read-path
#                      instruction for bodies over 300 lines)
# PreToolUse cannot inject context non-blockingly (verified 2026-08-24; see
# conventions/playbooks.md) — hence the deny-once pattern for 'before'.
# Fail open EVERYWHERE: any error -> silent exit 0.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)" || exit 0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null || true)"
case "$event" in PreToolUse|PostToolUse) ;; *) exit 0 ;; esac

case "$tool" in
  Bash)
    subject="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    tkey="trigger-bash" ;;
  Edit|Write)
    subject="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    tkey="trigger-path" ;;
  *) exit 0 ;;
esac
[ -n "$subject" ] || exit 0

out="$(bash "$HERE/../scripts/resolve-data-root.sh" 2>/dev/null || true)"
data_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
ws_root="$(printf '%s\n' "$out" | sed -n 's/^workspace_root=//p')"

dirs=()
[ -n "$data_root" ] && [ -d "$data_root/playbooks" ] && dirs+=("$data_root/playbooks")
[ -n "$ws_root" ] && [ -d "$ws_root/playbooks" ] && dirs+=("$ws_root/playbooks")
[ "${#dirs[@]}" -gt 0 ] || exit 0

markdir="${TMPDIR:-/tmp}/workspace-os-surfaced-$sid"

# front <file> -> the flat frontmatter block (lines between the first two --- lines)
front() { awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---$/{exit} {print}' "$1" 2>/dev/null; }
# fval <frontmatter> <key> -> value
fval() { printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

for d in "${dirs[@]}"; do
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    fm="$(front "$f")"; [ -n "$fm" ] || continue
    trig="$(fval "$fm" "$tkey")"
    [ -n "$trig" ] || continue
    printf '%s' "$subject" | grep -qE -- "$trig" 2>/dev/null || continue
    slug="$(basename "$f" .md)"
    [ -f "$markdir/$slug" ] && continue
    name="$(fval "$fm" name)"; [ -n "$name" ] || name="$slug"
    mode="$(fval "$fm" surface)"; [ "$mode" = "after" ] || mode="before"
    if [ "$mode" = "before" ] && [ "$event" = "PreToolUse" ]; then
      mkdir -p "$markdir" 2>/dev/null || exit 0
      : > "$markdir/$slug" 2>/dev/null || exit 0
      printf "playbook '%s' applies to this call - read %s first, then retry.\n" "$name" "$f" >&2
      exit 2
    elif [ "$mode" = "after" ] && [ "$event" = "PostToolUse" ]; then
      mkdir -p "$markdir" 2>/dev/null || exit 0
      : > "$markdir/$slug" 2>/dev/null || exit 0
      body="$(awk 'c>=2{print} /^---$/{c++}' "$f" 2>/dev/null)"
      nlines="$(printf '%s\n' "$body" | wc -l)"
      if [ "$nlines" -gt 300 ]; then
        ctx="playbook '$name' applies to the call you just made - read $f before continuing."
      else
        ctx="## Playbook: $name ($f)
$body"
      fi
      jq -cn --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
      exit 0
    fi
  done
done
exit 0
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-playbook-surface.sh`
Expected: all PASS, `0 failed`. Also run `bash tests/test-guardrail.sh` — still `21 passed` (the hook shares no state with the engine, this is a sanity check).

- [ ] **Step 5: Commit**

```bash
chmod +x hooks/playbook-surface.sh tests/test-playbook-surface.sh
git add hooks/playbook-surface.sh tests/test-playbook-surface.sh
git commit -m "feat(playbooks): trigger-time surfacing hook"
```

---

### Task 2: Conventions doc, template, `/playbook` skill, cadence line

**Files:**
- Create: `conventions/playbooks.md`
- Create: `templates/playbook.md`
- Create: `skills/playbook/SKILL.md`
- Modify: `hooks/capture-cadence.sh` (one heredoc line)
- Test: `tests/test-capture-cadence.sh` (one assertion)

**Interfaces:**
- Consumes: the Task 1 hook contract (frontmatter keys, surface modes, marker semantics).
- Produces: the SoT conventions doc the skill and future slices reference; the model/user-facing `/playbook` skill.

- [ ] **Step 1: Write `conventions/playbooks.md`**

```markdown
# Playbook Conventions

Single source of truth for the playbook artifact class: `/playbook` and
`hooks/playbook-surface.sh` follow these rules and do not restate them.

## What a playbook is

A **procedure** — multi-step how-to knowledge too big for a memory fact (one fact per file,
see `conventions/memory.md`) and not work-state (see `conventions/project-tracking.md`).
Examples: how to query a warehouse tool safely, how to edit notebooks, how to triage a failed
run. A playbook guides; a guardrail rule blocks — a hazard that must be PREVENTED belongs in
`.claude/guardrails.json` (`/guardrails`), not here.

## Where playbooks live

- Repo tier: `<data_root>/playbooks/<slug>.md` (in-repo: `docs/playbooks/`; sidecar:
  `_meta/<repo>/playbooks/` — resolved via `scripts/resolve-data-root.sh`, never assumed).
- Workspace tier: `<workspace_root>/playbooks/<slug>.md` — procedures shared by every repo in
  a marked workspace.

## File shape

Flat frontmatter (plain `key: value` lines between the first two `---` lines — bash hooks
parse it with sed/grep, so no nesting), then a body in the recommended section shape:

    ---
    name: snowflake-querying
    description: how to query Snowflake with sfq.py without burning retries
    trigger-bash: sfq\.py
    trigger-path:
    surface: before
    ---
    # Snowflake querying
    ## Preconditions
    ## Steps
    ## Verify
    ## Known traps

- `trigger-bash`: ERE (`grep -E`) matched against Bash commands.
- `trigger-path`: ERE matched against Edit/Write file paths. Either or both; with neither the
  playbook is docs-only (listable, never auto-surfaced).
- `surface`: `before` (default) or `after` — see below.
- Body sections are recommended, not enforced. Keep bodies <= 300 lines: larger bodies are
  surfaced as a read-this-path instruction instead of inline content.

## Surfacing (once per session per playbook)

Claude Code's PreToolUse hooks cannot inject model context non-blockingly
(`additionalContext` is honored there only on "ask" escalations — verified against the hooks
docs 2026-08-24). Hence two modes:

- `surface: before` — the FIRST matching tool call in a session is denied once with
  "read <path> first, then retry"; the session marker is written before the deny, so the
  retry passes. Guarantees the procedure is read before the call runs. Use for procedures
  where the first call unguided is the expensive one.
- `surface: after` — the first matching call runs, then the playbook body is injected via
  PostToolUse `additionalContext`. Frictionless; the first call is unguided. Use for
  advisory-grade procedures.

One playbook surfaces per call (first unmarked match, repo tier before workspace tier, glob
order within a tier); others fire on subsequent matching calls. Markers live under
`${TMPDIR:-/tmp}/workspace-os-surfaced-<session_id>/` and reset per session.
```

- [ ] **Step 2: Write `templates/playbook.md`**

```markdown
---
name: example-procedure
description: one line on when this procedure applies
trigger-bash:
trigger-path:
surface: before
---
# Example procedure

## Preconditions
- what must be true before starting

## Steps
1. the steps, in order, copy-paste ready

## Verify
- how to check it worked

## Known traps
- the mistakes this playbook exists to prevent
```

- [ ] **Step 3: Write `skills/playbook/SKILL.md`**

```markdown
---
name: playbook
description: Author a procedure playbook (trigger, preconditions, steps, verify, known traps) that auto-surfaces at trigger time; adopt an existing how-to doc into one; or list playbooks. Use when the user describes a repeatable multi-step procedure worth codifying, asks to create/adopt/list playbooks, or when a procedure gets re-explained mid-task - propose capturing it at a natural boundary, never write without confirmation.
user-invocable: true
allowed-tools: Bash, Read, Write
---

# Playbook

Procedure capture over the playbook artifact class (`conventions/playbooks.md` is the SoT -
shape, triggers, surface modes; do not restate it, follow it). Playbooks live at
`<data_root>/playbooks/` (repo tier) or `<workspace_root>/playbooks/` (workspace tier) and are
auto-surfaced by `hooks/playbook-surface.sh` when a matching tool call happens.

**Prerequisite - resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` and announce the mode and where a
playbook would land. Create the `playbooks/` dir on first write.

## Dispatch

- `list` -> for each tier dir that exists, print each playbook's slug, `name`, `description`,
  triggers, and `surface` mode (read the frontmatter; both tiers, repo tier first).
- `adopt <path>` -> adopt mode below.
- Anything else (including no args) -> author mode; the argument text, if any, seeds the
  procedure description.

## Author mode

1. **Elicit the procedure** - from the conversation or by asking: what triggers it, the steps
   in copy-paste form, how to verify, the traps it prevents.
2. **Draft** into the template shape (`templates/playbook.md`): kebab-case slug/name; the
   narrowest `trigger-bash`/`trigger-path` ERE that still catches the moment of need;
   `surface: before` for procedures where an unguided first call is expensive, `after` for
   advisory ones (default before). Validate each trigger compiles:
   `printf '' | grep -qE -- '<regex>'; [ $? -le 1 ]` (exit 2 = bad regex - revise).
3. **Choose the tier** - repo tier by default; workspace tier when the user says it applies
   across the workspace's repos.
4. **Propose** the full file content + where it lands + which calls will trigger it. Nothing
   is written without confirmation.
5. **Write** on confirm (create the dir if needed), then **report**: path, trigger, mode, and
   that surfacing gates per session (a playbook surfaces at most once per session; markers
   reset next session).

## Adopt mode

Read the source doc fully, then propose a reshaping into one or more playbooks (a 300-line
how-to often splits by trigger). Per proposed playbook: content in the shape, trigger,
surface mode, tier. **The source doc is never modified or deleted** - suggest leaving it with
a one-line pointer note, but that edit too is propose-confirm. Apply only what the user
confirms; report as in author mode.

## Batching

Accumulate multiple procedures into ONE propose-confirm batch at a natural boundary, like
/ingest. Skip trivia: a procedure earns a playbook when getting it wrong costs real time or
tokens, not when it is two obvious steps.
```

- [ ] **Step 4: Cadence line + assertion**

In `hooks/capture-cadence.sh`, after the `- a hazard or near-miss worth a permanent rule -> /guardrails` line, add:

```
- a repeated multi-step procedure -> /playbook
```

In `tests/test-capture-cadence.sh`, after the `/guardrails` assertion line, add:

```bash
contains "cadence names /playbook" "$out" "/playbook"
```

- [ ] **Step 5: Run the cadence test + validator**

Run: `bash tests/test-capture-cadence.sh && python3 scripts/validate-plugin.py`
Expected: `10 passed, 0 failed`; `Plugin validation passed (15 skills checked).`

- [ ] **Step 6: Commit**

```bash
git add conventions/playbooks.md templates/playbook.md skills/playbook/SKILL.md \
        hooks/capture-cadence.sh tests/test-capture-cadence.sh
git commit -m "feat(playbooks): /playbook skill, conventions, template, cadence nudge"
```

---

### Task 3: Wiring + packaging

**Files:**
- Modify: `hooks/hooks.json` (PreToolUse entry + PostToolUse entry)
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: v0.24.0 with surfacing live on next session start.

- [ ] **Step 1: hooks.json**

Add a second PreToolUse entry (after the guardrail entry's closing `}`):

```json
      ,{
        "matcher": "Bash|Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/playbook-surface.sh\"" }
        ]
      }
```

And a third PostToolUse entry (after the dispatch-ledger entry's closing `}`):

```json
      ,{
        "matcher": "Bash|Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/playbook-surface.sh\"" }
        ]
      }
```

Verify: `jq -e . hooks/hooks.json`.

- [ ] **Step 2: CI**

After `- run: bash tests/test-dispatch-ledger.sh` in `.github/workflows/ci.yml`, add:

```yaml
      - run: bash tests/test-playbook-surface.sh
```

- [ ] **Step 3: README**

After the `## Dispatch ledger` section (before `## How it works`), add:

```markdown
## Playbooks

A **procedure** artifact class (`<data_root>/playbooks/`, plus a workspace tier): trigger,
preconditions, steps, verify, known traps — authored/adopted via **`/playbook`** and
**surfaced at trigger time** by `hooks/playbook-surface.sh`, once per session per playbook.
`surface: before` denies the first matching call once ("read <path> first, then retry" — a
guaranteed read before the call runs); `surface: after` injects the body as context right
after the first matching call. Conventions: `conventions/playbooks.md`.
```

Also add to the `## Skills` list, after the `/guardrails` bullet:

```markdown
- **`/playbook`** — author a procedure playbook (or adopt an existing how-to doc into one); playbooks auto-surface when a matching Bash command or file edit happens.
```

- [ ] **Step 4: plugin.json**

Set `"version": "0.24.0"`; in `description`, after `+ a local-only dispatch ledger`, insert ` + trigger-surfaced procedure playbooks (/playbook)`.

- [ ] **Step 5: Run everything**

Run: `python3 scripts/validate-plugin.py && jq -e . hooks/hooks.json >/dev/null && for t in tests/test-*.sh; do bash "$t" >/dev/null 2>&1 || echo "SUITE FAILED: $t"; done; echo done`
Expected: 15 skills; hooks.json parses; no `SUITE FAILED` lines.

- [ ] **Step 6: Commit**

```bash
git add hooks/hooks.json .github/workflows/ci.yml README.md .claude-plugin/plugin.json
git commit -m "chore(release): v0.24.0 — playbooks wiring + docs"
```

---

### Task 4: Tracking close-out + PR

**Files:**
- Modify: `docs/project-tracking/resolved.md` (append)
- Modify: `docs/project-tracking/decisions-log.md` (append)
- Modify: `docs/project-tracking/ideas.md` (annotate)

**Interfaces:**
- Consumes: record shapes from `conventions/project-tracking.md`.
- Produces: tracking trail + the PR.

- [ ] **Step 1: Append the resolved record**

```markdown
### A-20260824-procedure-playbooks — playbook artifact class + trigger-time surfacing + /playbook
- Workstream: skills
- Status: done
- Created: 2026-08-24
- Completed: 2026-08-24
- Commit: (PR pending)

Promotes the procedure-playbooks idea (EC2 audit 2026-08-24: 1,063 hand-rolled lines in
`_meta/conventions/` with hope-based routing). Ships `conventions/playbooks.md` +
`templates/playbook.md` (flat frontmatter: name/description/trigger-bash/trigger-path/surface),
`hooks/playbook-surface.sh` (PreToolUse+PostToolUse on Bash|Edit|Write; before=deny-once with
read-then-retry, after=additionalContext injection; once per session per playbook, fail-open),
and the `/playbook` skill (author/adopt/list, propose-confirm, model-invocable + cadence line).
Decision: D-20260824-playbook-surface-before-default. Spec:
`docs/specs/2026-08-24-procedure-playbooks-design.md`.
```

- [ ] **Step 2: Append the decision record**

```markdown
### D-20260824-playbook-surface-before-default — playbooks surface via deny-once by default; per-playbook opt-out to after-injection
- Workstream: skills
- Created: 2026-08-24
- Status: accepted
- Rationale: verified against the Claude Code hooks docs (2026-08-24): PreToolUse command hooks CANNOT inject model context non-blockingly — additionalContext is honored there only on "ask" escalations; PostToolUse injects unconditionally but only after the call ran. The audit's plea is literally "read before, not after they fail," and one blocked call + read + retry costs far less than the measured unguided-first-call failure (~484k tokens). So `surface: before` (deny-once, marker-then-deny so the retry passes) is the default, with `surface: after` (PostToolUse injection) as the per-playbook opt-out for advisory procedures.
- Consequences: playbook surfacing depends on hook registration order not at all (parallel hooks); a `before` playbook costs exactly one denied call per session.
- Spawns: A-20260824-procedure-playbooks

Considered and rejected: always-after (first call always unguided — the exact measured failure); UserPromptSubmit injection (prompt-scoped, not tool-scoped — fires on user turns, not at the moment of the matching call); always-before (no soft option for advisory-grade procedures).
```

- [ ] **Step 3: Annotate the idea**

In the `### procedure-playbooks` entry in `ideas.md`, add directly after its `- Intended start:` line:

```markdown
- **Shipped (v0.24.0, 2026-08-24):** shape (`conventions/playbooks.md` + template) + trigger-time surfacing hook (before=deny-once / after=inject, per-playbook, default before — D-20260824-playbook-surface-before-default) + `/playbook` author/adopt/list. See `resolved.md` A-20260824-procedure-playbooks. Remaining follow-ups: `/project-init` stamps `playbooks/`, a `/memory-lint` playbook pass; UDX's five docs adopt via `/playbook adopt` on that machine.
```

- [ ] **Step 4: Commit, push, open the PR**

```bash
git add docs/project-tracking/
git commit -m "chore(tracking): close A-20260824-procedure-playbooks + decision"
git push -u origin feature/procedure-playbooks
gh pr create --title "feat: procedure playbooks — artifact class + trigger-time surfacing (v0.24.0)" \
  --body "Implements docs/specs/2026-08-24-procedure-playbooks-design.md: playbook artifact class (conventions + template), hooks/playbook-surface.sh (before=PreToolUse deny-once with read-then-retry, after=PostToolUse additionalContext; once per session per playbook; fail-open), and the /playbook author/adopt/list skill with cadence nudge.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 5: Verify CI in the foreground**

`gh pr checks <n>` in the foreground (never a background watcher). Merge only on green + user go-ahead; post-merge, fix the resolved record's `Commit:` line with the squash SHA, push, and update the installed plugin.
```
