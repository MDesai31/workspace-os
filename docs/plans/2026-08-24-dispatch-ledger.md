# Dispatch Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A PostToolUse hook that appends one local-only JSONL entry per subagent dispatch (sizes, estimated tokens, opportunistic harness usage), plus a read-only summary script.

**Architecture:** `hooks/dispatch-ledger.sh` (matcher `Task|Agent`) captures telemetry fail-open to `~/.claude/workspace-os/dispatch-ledger.jsonl`; `scripts/dispatch-ledger-summary.sh` reads it back fail-loud (totals, per-agent, top-N). The hook/scripts split mirrors guardrail's factoring. No prompt/response text ever reaches the ledger.

**Tech Stack:** bash + jq only. Plain-bash test harness, `DISPATCH_LEDGER` env as the seam.

**Spec:** `docs/specs/2026-08-24-dispatch-ledger-design.md`

## Global Constraints

- Deps: bash + jq only. No new dependencies.
- Capture hook: EVERY failure path is silent `exit 0`, no stdout on success. Summary script: fails loud (`dispatch-ledger-summary:` prefix on stderr, exit 1), except missing ledger (note, exit 0) and torn lines (skip + count).
- Privacy invariant: prompt/response TEXT never written to the ledger — lengths and a ≤120-char `desc` only. Tested with sentinels.
- Ledger path: `${DISPATCH_LEDGER:-$HOME/.claude/workspace-os/dispatch-ledger.jsonl}`.
- Commits on branch `feature/dispatch-ledger`, `type(scope): summary` style, standard Co-Authored-By + Claude-Session trailer used by prior commits.
- Version lands at 0.23.0 (Task 3).

---

### Task 1: Capture hook

**Files:**
- Create: `hooks/dispatch-ledger.sh` (chmod +x)
- Test: `tests/test-dispatch-ledger.sh` (chmod +x)

**Interfaces:**
- Consumes: PostToolUse hook JSON on stdin (`session_id`, `cwd`, `tool_input{description,prompt,subagent_type|agentType}`, `tool_response`/`tool_result`).
- Produces: one JSONL entry per dispatch with fields `ts, session_id, cwd, repo, agent, desc, prompt_chars, response_chars, est_tokens, tokens, duration_ms, is_error` (spec §1 table). Task 2's summary reads exactly these field names.

- [ ] **Step 1: Write the failing tests**

Create `tests/test-dispatch-ledger.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash test harness for hooks/dispatch-ledger.sh + scripts/dispatch-ledger-summary.sh
# (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/dispatch-ledger.sh"
SUMMARY="$HERE/../scripts/dispatch-ledger-summary.sh"
pass=0; fail=0

ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1${2:+ ($2)}"; fail=$((fail+1)); }

# jqledger <name> <jq -e filter over the LAST ledger line>
jqledger() {
  if tail -n 1 "$LEDGER" 2>/dev/null | jq -e "$2" >/dev/null 2>&1; then ok "$1"
  else bad "$1" "last=[$(tail -n 1 "$LEDGER" 2>/dev/null)]"; fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LEDGER="$TMP/ledger.jsonl"

# a real git repo for the cwd -> repo derivation
REPO="$TMP/proj-x"; mkdir -p "$REPO"; git -C "$REPO" init -q

LONGDESC="$(printf 'd%.0s' $(seq 1 150))"   # 150 chars
payload="$(jq -cn --arg cwd "$REPO" --arg desc "$LONGDESC" '{
  session_id: "s1", cwd: $cwd, hook_event_name: "PostToolUse", tool_name: "Task",
  tool_input: {description: $desc, prompt: "SENTINEL_PROMPT_XYZZY", subagent_type: "Explore"},
  tool_response: {totalDurationMs: 1234, totalTokens: 999,
                  content: [{type: "text", text: "SENTINEL_RESPONSE_PLUGH"}]}
}')"

# --- capture: full payload ---
out="$(printf '%s' "$payload" | DISPATCH_LEDGER="$LEDGER" bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && ok "capture exits 0 silently" || bad "capture exits 0 silently" "ec=$ec out=[$out]"
[ "$(wc -l < "$LEDGER")" = 1 ] && ok "one line appended" || bad "one line appended"
jqledger "agent from subagent_type" '.agent == "Explore"'
jqledger "session + cwd recorded" '.session_id == "s1" and (.cwd | length > 0)'
jqledger "repo derived from cwd git root" '.repo == "proj-x"'
jqledger "desc truncated to 120" '(.desc | length) == 120'
jqledger "prompt_chars counted" '.prompt_chars == 21'
jqledger "response_chars counted (object stringified)" '.response_chars > 0'
jqledger "est_tokens = (p+r)/4 floored" '.est_tokens == (((.prompt_chars + .response_chars) / 4) | floor)'
jqledger "harness tokens picked up" '.tokens == 999'
jqledger "harness duration picked up" '.duration_ms == 1234'
jqledger "ts is ISO-8601 UTC" '.ts | test("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")'

# --- privacy: sentinel text never reaches the ledger ---
if grep -q "SENTINEL_PROMPT_XYZZY\|SENTINEL_RESPONSE_PLUGH" "$LEDGER"; then
  bad "privacy: no prompt/response text in ledger"
else ok "privacy: no prompt/response text in ledger"; fi

# --- capture: agentType fallback + string response + absent optionals ---
p2='{"session_id":"s2","cwd":"/nowhere","tool_name":"Agent",
     "tool_input":{"description":"d","prompt":"pp","agentType":"claude"},
     "tool_response":"just a string"}'
printf '%s' "$p2" | DISPATCH_LEDGER="$LEDGER" bash "$HOOK"
[ "$(wc -l < "$LEDGER")" = 2 ] && ok "second dispatch appends" || bad "second dispatch appends"
jqledger "agentType fallback" '.agent == "claude"'
jqledger "string response measured" '.response_chars == 13'
jqledger "absent optionals are null" '.tokens == null and .duration_ms == null and .is_error == null'
jqledger "non-repo cwd -> empty repo" '.repo == ""'

# --- fail-open paths ---
before="$(wc -l < "$LEDGER")"
out="$(printf 'not json' | DISPATCH_LEDGER="$LEDGER" bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && [ "$(wc -l < "$LEDGER")" = "$before" ] \
  && ok "malformed stdin: silent no-op" || bad "malformed stdin: silent no-op" "ec=$ec"
out="$(printf '{"tool_name":"Task"}' | DISPATCH_LEDGER="$LEDGER" bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ "$(wc -l < "$LEDGER")" = "$before" ] \
  && ok "missing tool_input: silent no-op" || bad "missing tool_input: silent no-op" "ec=$ec"
out="$(printf '%s' "$payload" | DISPATCH_LEDGER=/proc/nonexistent/dir/l.jsonl bash "$HOOK" 2>&1)"; ec=$?
[ "$ec" = 0 ] && [ -z "$out" ] && ok "unwritable ledger: silent exit 0" || bad "unwritable ledger: silent exit 0" "ec=$ec"

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-dispatch-ledger.sh`
Expected: FAILs across the board (the hook script does not exist yet, so `bash "$HOOK"` exits 127).

- [ ] **Step 3: Implement the hook**

Create `hooks/dispatch-ledger.sh`:

```bash
#!/usr/bin/env bash
# workspace-os dispatch ledger — PostToolUse hook (Task|Agent subagent dispatches).
# Appends one JSONL line per dispatch to a LOCAL-ONLY ledger (default under ~/.claude,
# outside every repo by construction). Pure telemetry: fail open on EVERYTHING — any
# error is a silent exit 0; never blocks, never prints on success.
# PRIVACY INVARIANT: prompt/response TEXT never reaches the ledger — lengths + a short
# desc label only (safe to keep in a home-dir file while working in employer repos).
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)" || exit 0

ledger="${DISPATCH_LEDGER:-$HOME/.claude/workspace-os/dispatch-ledger.jsonl}"
mkdir -p "$(dirname "$ledger")" 2>/dev/null || exit 0

ts="$(date -u +%FT%TZ)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
repo=""
if [ -n "$cwd" ]; then
  top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] && repo="$(basename "$top")"
fi

line="$(printf '%s' "$input" | jq -c --arg ts "$ts" --arg repo "$repo" '
  .tool_input as $ti | select($ti != null)
  | (.tool_response // .tool_result // null) as $r
  | (if $r == null then "" elif ($r | type) == "string" then $r else ($r | tojson) end) as $rs
  | (($ti.prompt // "") | length) as $pc
  | ($rs | length) as $rc
  | {
      ts: $ts,
      session_id: (.session_id // ""),
      cwd: (.cwd // ""),
      repo: $repo,
      agent: ($ti.subagent_type // $ti.agentType // "unknown"),
      desc: (($ti.description // "")[0:120]),
      prompt_chars: $pc,
      response_chars: $rc,
      est_tokens: ((($pc + $rc) / 4) | floor),
      tokens: (($r.totalTokens? // $r.usage?.total_tokens? // $r.usage?.totalTokens?) // null),
      duration_ms: (($r.totalDurationMs? // $r.duration_ms?) // null),
      is_error: (($r.is_error?) // null)
    }' 2>/dev/null)" || exit 0
[ -n "$line" ] || exit 0
printf '%s\n' "$line" >> "$ledger" 2>/dev/null || true
exit 0
```

- [ ] **Step 4: Run the capture + privacy + fail-open tests**

Run: `bash tests/test-dispatch-ledger.sh`
Expected: all capture/privacy/fail-open cases PASS, `0 failed`. (Summary cases arrive in Task 2.)

- [ ] **Step 5: Commit**

```bash
chmod +x hooks/dispatch-ledger.sh tests/test-dispatch-ledger.sh
git add hooks/dispatch-ledger.sh tests/test-dispatch-ledger.sh
git commit -m "feat(ledger): dispatch-capture PostToolUse hook"
```

---

### Task 2: Summary script

**Files:**
- Create: `scripts/dispatch-ledger-summary.sh` (chmod +x)
- Test: `tests/test-dispatch-ledger.sh` (append cases before the summary lines)

**Interfaces:**
- Consumes: the Task 1 entry fields, `DISPATCH_LEDGER` seam.
- Produces: `dispatch-ledger-summary.sh [--repo NAME] [--top N]` → header (entries, est_tokens total, span), per-agent table, top-N by `est_tokens`, trailing `ledger:` path line and `N unparseable line(s) skipped` when applicable. Missing ledger → note + exit 0.

- [ ] **Step 1: Append failing tests**

Insert into `tests/test-dispatch-ledger.sh`, immediately before the `echo "----"` line:

```bash
# --- summary ---
SL="$TMP/sum.jsonl"
cat > "$SL" <<'EOF'
{"ts":"2026-08-24T01:00:00Z","session_id":"s","cwd":"/a","repo":"proj-x","agent":"Explore","desc":"cheap scan","prompt_chars":40,"response_chars":40,"est_tokens":20,"tokens":null,"duration_ms":null,"is_error":null}
{"ts":"2026-08-24T02:00:00Z","session_id":"s","cwd":"/a","repo":"proj-x","agent":"claude","desc":"big rebuild","prompt_chars":400000,"response_chars":400000,"est_tokens":200000,"tokens":190000,"duration_ms":90000,"is_error":null}
this line is torn and not json
{"ts":"2026-08-24T03:00:00Z","session_id":"s","cwd":"/b","repo":"proj-y","agent":"claude","desc":"other repo","prompt_chars":80,"response_chars":80,"est_tokens":40,"tokens":null,"duration_ms":null,"is_error":null}
EOF

out="$(DISPATCH_LEDGER="$SL" bash "$SUMMARY" 2>&1)"; ec=$?
[ "$ec" = 0 ] && ok "summary exits 0" || bad "summary exits 0" "ec=$ec out=[$out]"
case "$out" in *"entries: 3"*) ok "summary counts entries";; *) bad "summary counts entries" "out=[$out]";; esac
case "$out" in *"est_tokens total: 200060"*) ok "summary totals est_tokens";; *) bad "summary totals est_tokens" "out=[$out]";; esac
case "$out" in *"1 unparseable line(s) skipped"*) ok "torn line skipped and counted";; *) bad "torn line skipped and counted" "out=[$out]";; esac
first_top="$(printf '%s\n' "$out" | sed -n '/top .* by est_tokens:/{n;p;}')"
case "$first_top" in *"big rebuild"*) ok "top list ordered by est_tokens";; *) bad "top list ordered by est_tokens" "line=[$first_top]";; esac

out="$(DISPATCH_LEDGER="$SL" bash "$SUMMARY" --repo proj-y 2>&1)"; ec=$?
case "$out" in *"entries: 1"*) ok "--repo filters entries";; *) bad "--repo filters entries" "out=[$out]";; esac
case "$out" in *"big rebuild"*) bad "--repo excludes other repos";; *) ok "--repo excludes other repos";; esac

out="$(DISPATCH_LEDGER="$TMP/absent.jsonl" bash "$SUMMARY" 2>&1)"; ec=$?
[ "$ec" = 0 ] && ok "missing ledger is a note, exit 0" || bad "missing ledger is a note, exit 0" "ec=$ec"
case "$out" in *"no dispatch ledger yet"*) ok "missing ledger note text";; *) bad "missing ledger note text" "out=[$out]";; esac

out="$(DISPATCH_LEDGER="$SL" bash "$SUMMARY" --top nope 2>&1)"; ec=$?
[ "$ec" = 1 ] && ok "bad --top fails loud" || bad "bad --top fails loud" "ec=$ec"
```

- [ ] **Step 2: Run to verify the new cases fail**

Run: `bash tests/test-dispatch-ledger.sh`
Expected: Task 1 cases PASS; summary cases FAIL (exit 127, script missing).

- [ ] **Step 3: Implement the summary script**

Create `scripts/dispatch-ledger-summary.sh`:

```bash
#!/usr/bin/env bash
# workspace-os dispatch-ledger summary — read-only view over the local dispatch ledger
# (written by hooks/dispatch-ledger.sh). Fails loud, unlike the capture hook: a read tool
# that errors should say so. Torn lines are tolerated (skipped + counted) — an append-only
# file written by a fail-open hook may legitimately contain one.
set -uo pipefail
die() { echo "dispatch-ledger-summary: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq is required"

ledger="${DISPATCH_LEDGER:-$HOME/.claude/workspace-os/dispatch-ledger.jsonl}"
repo=""; top=10
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || die "missing value for --repo"; repo="$2"; shift 2 ;;
    --top)  [ $# -ge 2 ] || die "missing value for --top"; top="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
case "$top" in ''|*[!0-9]*) die "--top must be a positive integer" ;; esac

if [ ! -f "$ledger" ]; then
  echo "no dispatch ledger yet (would live at: $ledger)"; exit 0
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
skipped=0
while IFS= read -r l; do
  [ -z "$l" ] && continue
  if printf '%s' "$l" | jq -e . >/dev/null 2>&1; then printf '%s\n' "$l" >> "$tmp"
  else skipped=$((skipped+1)); fi
done < "$ledger"

jq -s -r --arg repo "$repo" --argjson top "$top" '
  map(select($repo == "" or .repo == $repo))
  | if length == 0 then
      "no entries" + (if $repo != "" then " for repo " + $repo else "" end)
    else
      "entries: \(length)   est_tokens total: \(map(.est_tokens // 0) | add)   span: \(first.ts) -> \(last.ts)",
      "",
      "by agent:",
      (group_by(.agent) | sort_by(-(map(.est_tokens // 0) | add))[]
        | "  \(.[0].agent)  n=\(length)  est_tokens=\(map(.est_tokens // 0) | add)  tokens=\((map(.tokens // empty) | add) // "-")"),
      "",
      "top \($top) by est_tokens:",
      (sort_by(-(.est_tokens // 0))[:$top][]
        | "  \(.ts)  \(.agent)  \(if .repo == "" then "-" else .repo end)  est=\(.est_tokens)  \(.desc)")
    end
' "$tmp" || die "ledger unreadable"
echo "ledger: $ledger"
[ "$skipped" -gt 0 ] && echo "$skipped unparseable line(s) skipped"
exit 0
```

- [ ] **Step 4: Run the full test file**

Run: `bash tests/test-dispatch-ledger.sh`
Expected: all PASS, `0 failed`.

- [ ] **Step 5: Commit**

```bash
chmod +x scripts/dispatch-ledger-summary.sh
git add scripts/dispatch-ledger-summary.sh tests/test-dispatch-ledger.sh
git commit -m "feat(ledger): read-only summary script"
```

---

### Task 3: Wiring + packaging

**Files:**
- Modify: `hooks/hooks.json` (new PostToolUse entry)
- Modify: `.github/workflows/ci.yml` (register the test)
- Modify: `README.md` (Dispatch ledger section)
- Modify: `.claude-plugin/plugin.json` (version, description)

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: v0.23.0 with live capture on next session start.

- [ ] **Step 1: hooks.json**

In `hooks/hooks.json`, extend the `PostToolUse` array (after the existing lint entry's closing `}`):

```json
      ,{
        "matcher": "Task|Agent",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/dispatch-ledger.sh\"" }
        ]
      }
```

Verify with: `jq -e . hooks/hooks.json` → parses.

- [ ] **Step 2: CI**

In `.github/workflows/ci.yml`, after `- run: bash tests/test-guardrails-upsert.sh`, add:

```yaml
      - run: bash tests/test-dispatch-ledger.sh
```

- [ ] **Step 3: README**

After the `## Lint` section, add:

```markdown
## Dispatch ledger

A PostToolUse hook (`hooks/dispatch-ledger.sh`) appends one JSONL line per subagent dispatch —
agent type, prompt/response sizes, `est_tokens` (chars/4), and harness-reported tokens/duration
when present — to a **local-only** ledger at `~/.claude/workspace-os/dispatch-ledger.jsonl`
(outside every repo by construction; prompt/response text is never stored, only sizes and a
short description). Pure telemetry: fail-open, never blocks. Capture starts on the next session
after install. Read it back:

```
bash scripts/dispatch-ledger-summary.sh [--repo NAME] [--top N]
```
```

- [ ] **Step 4: plugin.json**

Set `"version": "0.23.0"`; in `description`, after `authored conversationally via /guardrails)`, insert ` + a local-only dispatch ledger`.

- [ ] **Step 5: Run everything**

Run: `python3 scripts/validate-plugin.py && jq -e . hooks/hooks.json >/dev/null && for t in tests/test-*.sh; do bash "$t" >/dev/null 2>&1 || echo "SUITE FAILED: $t"; done; echo done`
Expected: validator passes (14 skills), hooks.json parses, no `SUITE FAILED` lines.

- [ ] **Step 6: Commit**

```bash
git add hooks/hooks.json .github/workflows/ci.yml README.md .claude-plugin/plugin.json
git commit -m "chore(release): v0.23.0 — dispatch ledger wiring + docs"
```

---

### Task 4: Tracking close-out + PR

**Files:**
- Modify: `docs/project-tracking/resolved.md` (append; record enters as done-with-pending-SHA, corrected post-merge as in prior slices)
- Modify: `docs/project-tracking/ideas.md` (annotate two ideas)

**Interfaces:**
- Consumes: record shapes from `conventions/project-tracking.md`.
- Produces: tracking trail + the PR.

- [ ] **Step 1: Append the resolved record**

To `docs/project-tracking/resolved.md`:

```markdown
### A-20260824-dispatch-ledger — local-only subagent dispatch ledger + summary
- Workstream: meta
- Status: done
- Created: 2026-08-24
- Completed: 2026-08-24
- Commit: (PR pending)

Promotes the dispatch-ledger idea (EC2 audit 2026-08-24; the ~484k-token re-derivation).
Ships `hooks/dispatch-ledger.sh` (PostToolUse on `Task|Agent`: one JSONL entry per dispatch —
agent, desc≤120, prompt/response sizes, est_tokens, opportunistic harness tokens/duration —
fail-open everywhere, no prompt/response text ever stored) writing to
`~/.claude/workspace-os/dispatch-ledger.jsonl` (user-global: outside every repo by
construction, satisfying the never-ships-to-an-employer-repo constraint without per-mode
paths — the location decision, folded here rather than a D- record), plus
`scripts/dispatch-ledger-summary.sh` (fail-loud read-back: totals, per-agent, top-N,
--repo filter, torn lines skipped+counted). Spec:
`docs/specs/2026-08-24-dispatch-ledger-design.md`.
```

- [ ] **Step 2: Annotate the two ideas**

In `docs/project-tracking/ideas.md`, in the `### dispatch-ledger` entry, add directly after its `- Intended start:` line:

```markdown
- **Shipped (v0.23.0, 2026-08-24):** capture hook + summary script; ledger at `~/.claude/workspace-os/dispatch-ledger.jsonl`. See `resolved.md` A-20260824-dispatch-ledger. Token counts: opportunistic harness fields + always-recorded `est_tokens` (chars/4) — the "obtainable or estimated" question resolved as both.
```

And in the `### probe-first-dispatch-gate` entry, add directly after its `- Intended start:` line:

```markdown
- **Note (2026-08-24):** the [[dispatch-ledger]] prerequisite now exists (v0.23.0); still gated on [[stateful-guardrail-predicates]].
```

- [ ] **Step 3: Commit, push, open the PR**

```bash
git add docs/project-tracking/
git commit -m "chore(tracking): close A-20260824-dispatch-ledger + idea annotations"
git push -u origin feature/dispatch-ledger
gh pr create --title "feat: local-only dispatch ledger + summary (v0.23.0)" \
  --body "Implements docs/specs/2026-08-24-dispatch-ledger-design.md: PostToolUse capture hook (Task|Agent) appending sizes-only JSONL telemetry to ~/.claude/workspace-os/ (never in any repo; prompt/response text never stored), plus a fail-loud summary script (totals, per-agent, top-N, --repo). Fail-open capture, tested privacy invariant.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 4: Verify CI in the foreground**

Run: `gh pr checks <n>` in the foreground (NEVER a background watcher — CI here finishes in ~10s; standing rule from 2026-08-24). If pending, say so and re-check next turn. Merge only on green and only on the user's go-ahead; post-merge, correct the resolved record's `Commit:` line with the squash SHA (as done for PR #30).
```
