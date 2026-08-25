# Guardrail Conversational Authoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `/guardrails` skill that authors, lists, and removes guardrail rules by conversation — propose → dry-run through the real engine → confirm → apply — backed by a deterministic `guardrails-upsert.sh` write path.

**Architecture:** A new bash+jq CLI (`scripts/guardrails-upsert.sh`) owns every write to the resolved `guardrails.json` (fail-loud, atomic, regex validated in the engine's jq `test()` dialect, sidecar-aware). A new skill (`skills/guardrails/SKILL.md`) drives the conversation and proves each draft rule by running `hooks/guardrail.sh` against synthetic tool calls before anything lands. One nudge line joins the capture cadence. The engine itself is untouched.

**Tech Stack:** bash + jq only (the engine's own deps). Plain-bash test harness, same style as `tests/test-guardrail.sh`.

**Spec:** `docs/specs/2026-08-24-guardrail-conversational-authoring-design.md`

## Global Constraints

- Script deps are bash + jq ONLY — no python, no new dependencies.
- The script FAILS LOUD (error + nonzero exit, config untouched); the engine's fail-open behavior is not changed in any way. `hooks/guardrail.sh` is not edited in this plan.
- Config regexes are evaluated by jq `test()` (Oniguruma) in the engine — validation must use that dialect, never `grep -E`.
- Write target: `GUARDRAIL_CONFIG` env override wins; else sidecar mode → `<data_root>/guardrails.json`; else `<git root>/.claude/guardrails.json`. Never write into a repo tree in sidecar mode.
- Tests are plain bash, `GUARDRAIL_CONFIG` is the seam, deps bash + jq only.
- All commits on branch `feature/guardrail-conversational-authoring`, message style `type(scope): summary`, each ending with the repo's standard Co-Authored-By + Claude-Session trailer used by prior commits on this branch.
- Version lands at 0.22.0 (Task 6). Tracking records are append-only (Task 7).

---

### Task 1: `guardrails-upsert.sh` — `add` mode with safety contract

**Files:**
- Create: `scripts/guardrails-upsert.sh`
- Test: `tests/test-guardrails-upsert.sh`

**Interfaces:**
- Consumes: `scripts/resolve-data-root.sh` (existing; prints `mode=` / `data_root=` lines), `templates/guardrails.json` (existing seed).
- Produces: `guardrails-upsert.sh add --type bash|write --name NAME --match REGEX --action deny|warn --reason TEXT [--field content|path]` → exit 0 and a line `added <type> rule '<name>' (<action>) -> <config> [mode: <mode>]`; any failure → message on stderr prefixed `guardrails-upsert:`, exit 1, config byte-identical. Tasks 2–4 rely on this CLI shape and on the `resolve_config` function setting `$config` and `$mode`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test-guardrails-upsert.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash test harness for scripts/guardrails-upsert.sh (deps: bash + jq only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSERT="$HERE/../scripts/guardrails-upsert.sh"
pass=0; fail=0

# run <args...> -> sets $out (stdout+stderr) and $ec, with GUARDRAIL_CONFIG="$CFG"
run() { out="$(GUARDRAIL_CONFIG="$CFG" bash "$UPSERT" "$@" 2>&1)"; ec=$?; }

# expect <name> <want_ec> <want_substr>
expect() {
  local name="$1" want_ec="$2" want="$3" ok=1
  [ "$ec" = "$want_ec" ] || ok=0
  case "$out" in *"$want"*) ;; *) ok=0 ;; esac
  if [ "$ok" = 1 ]; then echo "PASS: $name"; pass=$((pass+1))
  else echo "FAIL: $name (ec=$ec out=[$out])"; fail=$((fail+1)); fi
}

# jqcheck <name> <jq -e filter over $CFG>
jqcheck() {
  if jq -e "$2" "$CFG" >/dev/null 2>&1; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1 (config=[$(cat "$CFG" 2>/dev/null)])"; fail=$((fail+1)); fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- add: creates config from template (nested dir) ---
CFG="$TMP/a/.claude/guardrails.json"
run add --type bash --name no-enterprise-push --match 'git +push +enterprise' \
    --action deny --reason "never push to the enterprise remote"
expect "add creates config from template" 0 "added bash rule 'no-enterprise-push' (deny)"
jqcheck "seeded config keeps template ip_class" '.ip_class'
jqcheck "rule landed with all fields" \
  '.bash | length == 1 and .[0].name == "no-enterprise-push" and .[0].action == "deny" and .[0].match == "git +push +enterprise" and (.[0].reason | length > 0)'

# --- add: idempotent replace by name ---
run add --type bash --name no-enterprise-push --match 'git +push +enterprise' \
    --action warn --reason "downgraded to advisory"
expect "replace same name exits 0" 0 "added bash rule"
jqcheck "replace does not duplicate" '.bash | length == 1'
jqcheck "replace updates fields" '.bash[0].action == "warn" and .bash[0].reason == "downgraded to advisory"'

# --- add: second rule appends ---
run add --type bash --name no-sudo --match '^sudo ' --action warn --reason "no sudo here"
expect "second rule appends" 0 "added bash rule 'no-sudo'"
jqcheck "both rules present" '.bash | length == 2'

# --- add: write rule with --field path ---
run add --type write --name no-env-writes --match '\.env$' --field path \
    --action deny --reason "never write .env files"
expect "write rule with field=path" 0 "added write rule"
jqcheck "field recorded" '.write[0].field == "path"'

# --- add: validation failures leave config untouched ---
before="$(cat "$CFG")"
run add --type bash --name x --match 'ok' --field path --action warn --reason r
expect "--field with --type bash rejected" 1 "--field is only valid with --type write"
run add --type nope --name x --match 'ok' --action warn --reason r
expect "bad type rejected" 1 "--type must be bash|write"
run add --type bash --name x --match 'ok' --action block --reason r
expect "bad action rejected" 1 "--action must be deny|warn"
run add --type bash --name x --match '(' --action warn --reason r
expect "invalid regex rejected (jq dialect)" 1 "invalid regex"
run add --type bash --match 'ok' --action warn --reason r
expect "missing --name rejected" 1 "--name is required"
[ "$(cat "$CFG")" = "$before" ] && { echo "PASS: failed adds leave config untouched"; pass=$((pass+1)); } \
  || { echo "FAIL: config changed by failing adds"; fail=$((fail+1)); }

# --- add: refuses to touch a malformed existing config ---
CFG="$TMP/broken.json"; printf '{oops' > "$CFG"
run add --type bash --name x --match 'ok' --action warn --reason r
expect "malformed existing config refused" 1 "does not parse"
[ "$(cat "$CFG")" = '{oops' ] && { echo "PASS: malformed config not clobbered"; pass=$((pass+1)); } \
  || { echo "FAIL: malformed config was modified"; fail=$((fail+1)); }

# --- add: no temp debris after success or failure ---
if ls "$TMP"/a/.claude/guardrails.json.tmp.* >/dev/null 2>&1 || ls "$TMP"/broken.json.tmp.* >/dev/null 2>&1; then
  echo "FAIL: temp debris left behind"; fail=$((fail+1))
else echo "PASS: no temp debris"; pass=$((pass+1)); fi

echo "----"; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-guardrails-upsert.sh`
Expected: every case FAILs (the script does not exist yet; `run` gets exit 127).

- [ ] **Step 3: Implement the script**

Create `scripts/guardrails-upsert.sh` (mode `chmod +x`, like the other scripts):

```bash
#!/usr/bin/env bash
# workspace-os guardrails authoring CLI — the deterministic write path for /guardrails.
# add | remove | list over the RESOLVED guardrails.json (spec: docs/specs/2026-08-24-…-design.md).
# Unlike the engine (hooks/guardrail.sh, fail open), this FAILS LOUD: any error -> message on
# stderr, nonzero exit, config untouched. Deps: bash + jq only.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../templates/guardrails.json"

die() { echo "guardrails-upsert: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq is required"

usage() {
  cat >&2 <<'EOF'
usage:
  guardrails-upsert.sh add --type bash|write --name NAME --match REGEX --action deny|warn --reason TEXT [--field content|path]
  guardrails-upsert.sh remove --type bash|write --name NAME
  guardrails-upsert.sh list
EOF
  exit 1
}

# Resolve config path + mode. Mirrors the engine's read logic (hooks/guardrail.sh):
# GUARDRAIL_CONFIG override (the test seam) -> sidecar data root -> <git root>/.claude/.
# workspace-meta needs NO special case: there the git root IS _meta, so the git-root branch
# lands on _meta/.claude/guardrails.json — exactly where the engine reads it.
resolve_config() {
  if [ -n "${GUARDRAIL_CONFIG:-}" ]; then config="$GUARDRAIL_CONFIG"; mode="env"; return; fi
  local out sc_mode sc_root root
  out="$(bash "$HERE/resolve-data-root.sh" 2>/dev/null || true)"
  sc_mode="$(printf '%s\n' "$out" | sed -n 's/^mode=//p')"
  sc_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
  if [ "$sc_mode" = "sidecar" ]; then
    config="$sc_root/guardrails.json"; mode="sidecar"; return
  fi
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
  config="$root/.claude/guardrails.json"; mode="${sc_mode:-in-repo}"
}

# atomic_edit <jq-args...>: apply a jq program to $config -> temp file -> parse-check -> move.
atomic_edit() {
  local tmp="${config}.tmp.$$"
  if ! jq "$@" "$config" > "$tmp" 2>/dev/null; then rm -f "$tmp"; die "jq edit failed"; fi
  if ! jq -e . "$tmp" >/dev/null 2>&1; then rm -f "$tmp"; die "result did not parse; config untouched"; fi
  mv "$tmp" "$config"
}

add_rule() {
  case "$type" in bash|write) ;; *) die "--type must be bash|write" ;; esac
  case "$action" in deny|warn) ;; *) die "--action must be deny|warn" ;; esac
  [ -n "$name" ]   || die "--name is required"
  [ -n "$match" ]  || die "--match is required"
  [ -n "$reason" ] || die "--reason is required"
  if [ -n "$field" ]; then
    [ "$type" = "write" ] || die "--field is only valid with --type write"
    case "$field" in content|path) ;; *) die "--field must be content|path" ;; esac
  fi
  # The engine evaluates config rules with jq test() (Oniguruma) — validate in that dialect.
  jq -ne --arg m "$match" '"x" | test($m) | true' >/dev/null 2>&1 \
    || die "invalid regex for the engine's jq test() dialect: $match"
  if [ ! -f "$config" ]; then
    [ -f "$TEMPLATE" ] || die "template missing: $TEMPLATE"
    mkdir -p "$(dirname "$config")" || die "cannot create $(dirname "$config")"
    cp "$TEMPLATE" "$config" || die "cannot seed config from template"
  fi
  jq -e . "$config" >/dev/null 2>&1 || die "existing config does not parse, refusing to touch it: $config"
  atomic_edit --arg t "$type" --arg n "$name" --arg m "$match" \
              --arg a "$action" --arg r "$reason" --arg f "${field:-}" '
    .[$t] = ((.[$t] // []) | map(select(.name != $n)))
          + [ {name:$n, match:$m}
              + (if $f != "" then {field:$f} else {} end)
              + {action:$a, reason:$r} ]'
  echo "added $type rule '$name' ($action) -> $config [mode: $mode]"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
type=""; name=""; match=""; action=""; reason=""; field=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type|--name|--match|--action|--reason|--field)
      [ $# -ge 2 ] || die "missing value for $1"
      case "$1" in
        --type) type="$2" ;; --name) name="$2" ;; --match) match="$2" ;;
        --action) action="$2" ;; --reason) reason="$2" ;; --field) field="$2" ;;
      esac; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

resolve_config
case "$cmd" in
  add) add_rule ;;
  *) usage ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-guardrails-upsert.sh`
Expected: all PASS, `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/guardrails-upsert.sh tests/test-guardrails-upsert.sh
git commit -m "feat(guardrails): deterministic authoring CLI — add mode"
```

---

### Task 2: `guardrails-upsert.sh` — `remove` and `list` modes

**Files:**
- Modify: `scripts/guardrails-upsert.sh` (extend the `case "$cmd"` dispatch and add two functions)
- Test: `tests/test-guardrails-upsert.sh` (append cases before the final summary lines)

**Interfaces:**
- Consumes: Task 1's script — `die`, `resolve_config`, `atomic_edit`, the arg parser, `$config`/`$mode`.
- Produces: `remove --type bash|write --name NAME` → exit 0 + `removed <type> rule '<name>' from <config>`; missing rule/config → exit 1. `list` → exit 0; no config → `no guardrails config [mode: <mode>] (would live at: <config>)`; else a `config: <path> [mode: <mode>]` header + one TSV row per rule: `type<TAB>name<TAB>action<TAB>field-or-dash<TAB>match<TAB>reason`. The skill (Task 4) parses nothing — it shows this output verbatim.

- [ ] **Step 1: Append failing tests**

Insert into `tests/test-guardrails-upsert.sh`, immediately before the `echo "----"` summary line:

```bash
# --- remove / list ---
CFG="$TMP/rl/guardrails.json"
run add --type bash --name rule-a --match 'aaa' --action deny --reason "A"
run add --type write --name rule-b --match 'bbb' --action warn --reason "B"

run list
expect "list shows config header" 0 "config: $CFG"
expect "list shows a bash row" 0 "rule-a"
case "$out" in *"rule-b"*) echo "PASS: list shows write row"; pass=$((pass+1));; \
  *) echo "FAIL: list missing write row (out=[$out])"; fail=$((fail+1));; esac

run remove --type bash --name rule-a
expect "remove deletes the rule" 0 "removed bash rule 'rule-a'"
jqcheck "removed from bash array" '.bash | length == 0'
jqcheck "write array untouched by remove" '.write | length == 1'

run remove --type bash --name rule-a
expect "remove missing rule errors" 1 "no bash rule named 'rule-a'"

CFG="$TMP/rl/none.json"
run remove --type bash --name x
expect "remove with no config errors" 1 "no config at"
run list
expect "list with no config is a note, exit 0" 0 "no guardrails config"

CFG="$TMP/rl/bad.json"; printf 'not json' > "$CFG"
run list
expect "list on malformed config errors" 1 "does not parse"
```

- [ ] **Step 2: Run tests to verify the new cases fail**

Run: `bash tests/test-guardrails-upsert.sh`
Expected: Task 1 cases PASS; every new case FAILs via the `usage` exit (`remove`/`list` unhandled).

- [ ] **Step 3: Implement**

In `scripts/guardrails-upsert.sh`, add after `add_rule`'s closing brace:

```bash
remove_rule() {
  case "$type" in bash|write) ;; *) die "--type must be bash|write" ;; esac
  [ -n "$name" ] || die "--name is required"
  [ -f "$config" ] || die "no config at $config"
  jq -e . "$config" >/dev/null 2>&1 || die "config does not parse: $config"
  jq -e --arg t "$type" --arg n "$name" '(.[$t] // []) | any(.name == $n)' "$config" >/dev/null 2>&1 \
    || die "no $type rule named '$name' in $config"
  atomic_edit --arg t "$type" --arg n "$name" \
    '.[$t] = ((.[$t] // []) | map(select(.name != $n)))'
  echo "removed $type rule '$name' from $config"
}

list_rules() {
  if [ ! -f "$config" ]; then
    echo "no guardrails config [mode: $mode] (would live at: $config)"; return
  fi
  jq -e . "$config" >/dev/null 2>&1 || die "config does not parse: $config"
  echo "config: $config [mode: $mode]"
  jq -r '["bash","write"][] as $t
         | (.[$t] // [])[]
         | [$t, .name, .action, (.field // "-"), .match, .reason] | @tsv' "$config"
}
```

And extend the dispatch:

```bash
case "$cmd" in
  add) add_rule ;;
  remove) remove_rule ;;
  list) list_rules ;;
  *) usage ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-guardrails-upsert.sh`
Expected: all PASS, `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/guardrails-upsert.sh tests/test-guardrails-upsert.sh
git commit -m "feat(guardrails): remove and list modes"
```

---

### Task 3: Data-root routing — in-repo, sidecar, and an engine round-trip

**Files:**
- Test: `tests/test-guardrails-upsert.sh` (append cases before the summary lines)
- (No script changes expected — `resolve_config` from Task 1 should already pass; this task proves it.)

**Interfaces:**
- Consumes: Task 1's `resolve_config`; `hooks/guardrail.sh` (existing, unmodified); the sidecar marker convention (`<ws>/_meta/workspace.json` containing `{"workspace-os":"sidecar"}` — see `tests/test-capture-cadence.sh` for the same fixture pattern).
- Produces: proof that a rule written in sidecar mode lands OUT of the repo tree and is read back by the real engine.

- [ ] **Step 1: Append failing (or passing) routing tests**

Insert before the summary lines. Note these cases unset `GUARDRAIL_CONFIG` and `cd` into fixture repos — they call the script directly rather than through `run`:

```bash
# --- data-root routing (no GUARDRAIL_CONFIG) ---
HOOK="$HERE/../hooks/guardrail.sh"

# in-repo mode -> <git root>/.claude/guardrails.json
R="$TMP/plain-repo"; mkdir -p "$R"; git -C "$R" init -q
out="$(cd "$R" && bash "$UPSERT" add --type bash --name t --match 'zzz' --action warn --reason r 2>&1)"; ec=$?
expect "in-repo add resolves to .claude/" 0 "$R/.claude/guardrails.json"
[ -f "$R/.claude/guardrails.json" ] && { echo "PASS: in-repo file created"; pass=$((pass+1)); } \
  || { echo "FAIL: in-repo file missing"; fail=$((fail+1)); }

# sidecar mode -> <ws>/_meta/<repo>/guardrails.json, repo tree untouched
WS="$TMP/ws"; mkdir -p "$WS/_meta" "$WS/repo-a"
printf '{"workspace-os":"sidecar","workspace":"test"}\n' > "$WS/_meta/workspace.json"
git -C "$WS/repo-a" init -q
out="$(cd "$WS/repo-a" && bash "$UPSERT" add --type bash --name no-enterprise-push \
      --match 'git +push +enterprise' --action deny --reason "never push enterprise" 2>&1)"; ec=$?
expect "sidecar add reports sidecar mode" 0 "[mode: sidecar]"
[ -f "$WS/_meta/repo-a/guardrails.json" ] && { echo "PASS: sidecar file at _meta/repo-a/"; pass=$((pass+1)); } \
  || { echo "FAIL: sidecar file missing (out=[$out])"; fail=$((fail+1)); }
[ ! -e "$WS/repo-a/.claude/guardrails.json" ] && { echo "PASS: repo tree untouched in sidecar mode"; pass=$((pass+1)); } \
  || { echo "FAIL: sidecar add wrote into the repo tree"; fail=$((fail+1)); }

# engine round-trip: the real hook denies based on the rule we just wrote
json='{"tool_name":"Bash","tool_input":{"command":"git  push enterprise main"}}'
hout="$(cd "$WS/repo-a" && printf '%s' "$json" | GUARDRAIL_CONFIG="" bash "$HOOK" 2>&1)"; hec=$?
[ "$hec" = 2 ] && { echo "PASS: engine round-trip denies"; pass=$((pass+1)); } \
  || { echo "FAIL: engine round-trip (ec=$hec out=[$hout])"; fail=$((fail+1)); }
case "$hout" in *"never push enterprise"*) echo "PASS: engine surfaces our reason"; pass=$((pass+1));; \
  *) echo "FAIL: reason not surfaced (out=[$hout])"; fail=$((fail+1));; esac

# sidecar list resolves the same path
out="$(cd "$WS/repo-a" && bash "$UPSERT" list 2>&1)"; ec=$?
expect "sidecar list finds the config" 0 "_meta/repo-a/guardrails.json"
```

- [ ] **Step 2: Run the suite**

Run: `bash tests/test-guardrails-upsert.sh`
Expected: all PASS. If a routing case fails, the bug is in `resolve_config` — fix it there (the read path in `hooks/guardrail.sh` is the contract; do not edit the hook).

- [ ] **Step 3: Run the engine's own suite to prove it is untouched**

Run: `bash tests/test-guardrail.sh`
Expected: `21 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add tests/test-guardrails-upsert.sh
git commit -m "test(guardrails): data-root routing + engine round-trip"
```

---

### Task 4: The `/guardrails` skill

**Files:**
- Create: `skills/guardrails/SKILL.md`

**Interfaces:**
- Consumes: the Task 1–2 CLI verbatim; `hooks/guardrail.sh` via `GUARDRAIL_CONFIG` for dry-runs (the `run_hook` pattern from `tests/test-guardrail.sh`); `scripts/resolve-data-root.sh` for the mode announcement.
- Produces: the user/model-facing `/guardrails` skill. No `disable-model-invocation` flag — it is a propose-confirm capture skill per the capture-cadence matrix (spec §2).

- [ ] **Step 1: Write the skill**

Create `skills/guardrails/SKILL.md`:

```markdown
---
name: guardrails
description: Author a guardrail rule by describing the hazard - propose, dry-run through the real engine, confirm, apply; also list or remove rules. Use when the user describes something that must never happen in this repo (a never-push remote, an IP boundary, a dangerous command), asks to add/list/remove a guardrail, or when a hazard or near-miss worth a permanent rule surfaces mid-task - propose it at a natural boundary, never write without confirmation.
user-invocable: true
allowed-tools: Bash, Read
---

# Guardrails

Conversational authoring over the guardrail engine (`hooks/guardrail.sh` +
`guardrails.json`). Rules are version-controlled with the repo - they protect every
collaborator and machine, unlike personal hookify rules. Every write goes through
`scripts/guardrails-upsert.sh` (fail-loud, atomic, regex validated in the engine's
jq `test()` dialect); this skill NEVER edits the config by hand. Propose -> dry-run ->
confirm -> apply; nothing lands without a yes.

**Prerequisite - resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` (see `conventions/data-root.md`)
and announce the mode and where a rule would land (in-repo: `.claude/guardrails.json`;
sidecar: `<data_root>/guardrails.json` - the repo tree is never touched).

## Dispatch

- `list` -> run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/guardrails-upsert.sh" list`, show the
  output verbatim.
- `remove <name>` -> run `list`, find the rule (search both types; if the name is ambiguous
  or missing, say so and stop). Show the matching rule, confirm, then
  `... guardrails-upsert.sh remove --type <t> --name <name>`.
- Anything else (including no args) -> author mode below. The argument text, if any, is the
  hazard description; otherwise ask for it. Multiple hazards accumulate into ONE batch -
  propose together at a natural boundary, like /ingest.

## Author mode

**1. Route each hazard** before drafting:

- **Engine-fit** (proceed): a text match over a Bash command, or over a write's content or
  path, worth sharing with the repo. `deny` for hard boundaries (IP leakage, never-push
  remotes, secrets); `warn` for advisories.
- **Hookify-fit** (hand off): needs `stop`/`prompt` events, or the user says it is personal /
  this-machine-only. Say why in one line and suggest `/hookify` (if hookify is not installed,
  print the rule you would have written as a hookify `.local.md` body instead). Do not
  reimplement hookify.
- **State-dependent** ("wrong branch", "disk nearly full"): the engine cannot express it -
  say so and point at the `stateful-guardrail-predicates` idea. Never silently drop it.

**2. Draft the rule:** kebab-case `name`; the narrowest regex that still catches the hazard
(jq `test()` dialect - Oniguruma, not grep -E); a `reason` that tells a blocked session what
to do instead. For write rules pick `--field content` (default) or `--field path`.

**3. Dry-run through the real engine** - both directions, before proposing:

    cfg="$(mktemp)"
    printf '{"bash":[],"write":[]}' > "$cfg"
    GUARDRAIL_CONFIG="$cfg" bash "${CLAUDE_PLUGIN_ROOT}/scripts/guardrails-upsert.sh" add \
      --type <t> --name <name> --match <regex> --action <a> --reason <r>
    # must fire (deny -> exit 2; warn -> systemMessage on stdout):
    printf '{"tool_name":"Bash","tool_input":{"command":"<hazard example>"}}' \
      | GUARDRAIL_CONFIG="$cfg" bash "${CLAUDE_PLUGIN_ROOT}/hooks/guardrail.sh"
    # must NOT fire (a nearby legitimate call -> exit 0, no output):
    printf '{"tool_name":"Bash","tool_input":{"command":"<legit example>"}}' \
      | GUARDRAIL_CONFIG="$cfg" bash "${CLAUDE_PLUGIN_ROOT}/hooks/guardrail.sh"
    rm -f "$cfg"

For write rules the synthetic call is
`{"tool_name":"Write","tool_input":{"file_path":"<p>","content":"<c>"}}`. A rule that fails
either direction is revised, not proposed - the dry-run gate is what makes a confirmed rule
trustworthy.

**4. Propose the batch:** per rule - the drafted JSON, both dry-run results as evidence, and
where it will land. Wait for confirmation; the user may accept a subset.

**5. Apply** each confirmed rule with `guardrails-upsert.sh add` (real config - no
`GUARDRAIL_CONFIG`), and surface any script error verbatim (it fails loud; never retry by
editing JSON directly).

**6. Report:** resolved path and mode, the landed rules, a reminder that the config is
version-controlled (commit it with the repo; in sidecar mode the sidecar repo holds it), and
the removal one-liner: `/guardrails remove <name>`.
```

- [ ] **Step 2: Validate the plugin picks the skill up**

Run: `python3 scripts/validate-plugin.py`
Expected: `Plugin validation passed (14 skills checked).`

- [ ] **Step 3: Dry-run the skill's own recipe once by hand**

Run exactly the block from the skill (author-mode step 3) with `--type bash --name smoke --match 'git +push +enterprise' --action deny --reason no`, hazard example `git  push enterprise main`, legit example `git push origin main`.
Expected: the must-fire call exits 2 with the reason on stderr; the must-not call exits 0 silently. (This proves the recipe as written works on this machine.)

- [ ] **Step 4: Commit**

```bash
git add skills/guardrails/SKILL.md
git commit -m "feat(guardrails): /guardrails skill — author, list, remove"
```

---

### Task 5: Capture-cadence nudge

**Files:**
- Modify: `hooks/capture-cadence.sh` (one line in the heredoc)
- Test: `tests/test-capture-cadence.sh` (one assertion)

**Interfaces:**
- Consumes: the existing heredoc list of capture lines.
- Produces: the SessionStart injection names `/guardrails` alongside the other capture skills.

- [ ] **Step 1: Add the failing assertion**

In `tests/test-capture-cadence.sh`, after the line `contains "cadence names /ingest" "$out" "/ingest"`, add:

```bash
contains "cadence names /guardrails" "$out" "/guardrails"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/test-capture-cadence.sh`
Expected: `FAIL: cadence names /guardrails`, all others PASS.

- [ ] **Step 3: Add the nudge line**

In `hooks/capture-cadence.sh`, after the line `- a future intent -> /project-plan`, add:

```
- a hazard or near-miss worth a permanent rule -> /guardrails
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/test-capture-cadence.sh`
Expected: `9 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add hooks/capture-cadence.sh tests/test-capture-cadence.sh
git commit -m "feat(cadence): nudge guardrail capture"
```

---

### Task 6: Packaging — README, plugin.json, CI

**Files:**
- Modify: `README.md` (skills list + Guardrails section)
- Modify: `.claude-plugin/plugin.json` (description, version)
- Modify: `.github/workflows/ci.yml` (register the new test)

**Interfaces:**
- Consumes: everything shipped in Tasks 1–5.
- Produces: v0.22.0, CI running the new suite.

- [ ] **Step 1: README**

In the `## Skills` list, after the `/memory-search` bullet, add:

```markdown
- **`/guardrails`** — author a guardrail rule by describing the hazard: propose → dry-run through the real engine (fire + no-fire evidence) → confirm → apply via `scripts/guardrails-upsert.sh`; `list`/`remove` included. Misfit hazards (stop/prompt events, personal scope) are handed off to hookify; state-dependent ones are named as future work.
```

At the end of the `## Guardrails` section's first paragraph-block (after the sentence ending `add tripwire `write` rules for cross-boundary IP leakage.`), append:

```markdown
Rules no longer need hand-written JSON: `/guardrails` authors, lists, and removes them conversationally.
```

- [ ] **Step 2: plugin.json**

In `.claude-plugin/plugin.json`: set `"version": "0.22.0"`; in `description`, change `+ a PreToolUse guardrail engine (declarative per-repo deny/warn rules)` to `+ a PreToolUse guardrail engine (declarative per-repo deny/warn rules, authored conversationally via /guardrails)`.

- [ ] **Step 3: CI**

In `.github/workflows/ci.yml`, after the `- run: bash tests/test-stamp-portable-layer.sh` line, add:

```yaml
      - run: bash tests/test-guardrails-upsert.sh
```

- [ ] **Step 4: Run everything**

Run: `python3 scripts/validate-plugin.py && for t in tests/test-*.sh; do bash "$t" || echo "SUITE FAILED: $t"; done`
Expected: validator passes (14 skills); every suite reports `0 failed`; no `SUITE FAILED` lines.

- [ ] **Step 5: Commit**

```bash
git add README.md .claude-plugin/plugin.json .github/workflows/ci.yml
git commit -m "chore(release): v0.22.0 — /guardrails conversational authoring"
```

---

### Task 7: Tracking close-out + PR

**Files:**
- Modify: `docs/project-tracking/action-items.md` (append; replace the `_No open items yet._` placeholder if it is still the only content)
- Modify: `docs/project-tracking/decisions-log.md` (append)
- Modify: `docs/project-tracking/ideas.md` (append one idea; annotate one)

**Interfaces:**
- Consumes: record shapes from `conventions/project-tracking.md` (copied exactly below).
- Produces: the slice's tracking trail; the PR.

- [ ] **Step 1: Append the action record**

To `docs/project-tracking/action-items.md` (removing the `_No open items yet._` placeholder line if present):

```markdown
### A-20260824-guardrail-conversational-authoring — /guardrails: conversational guardrail rule authoring
- Workstream: workflow
- Status: open
- Created: 2026-08-24

Promotes the guardrail-conversational-authoring idea (EC2 audit 2026-08-24). Ships
`scripts/guardrails-upsert.sh` (deterministic add/remove/list over the resolved guardrails.json —
fail-loud, atomic, jq-dialect regex validation, sidecar-aware), the `/guardrails` skill
(elicit → route → draft → dry-run through `hooks/guardrail.sh` → propose-confirm → apply), a
capture-cadence nudge line, and `tests/test-guardrails-upsert.sh`. Spec:
`docs/specs/2026-08-24-guardrail-conversational-authoring-design.md`.
```

- [ ] **Step 2: Append the decision record**

To `docs/project-tracking/decisions-log.md`:

```markdown
### D-20260824-guardrails-canonical-hookify-misfits — guardrails.json stays canonical; hookify gets the misfits
- Workstream: workflow
- Created: 2026-08-24
- Status: accepted
- Rationale: hookify rules are gitignored and personal — they protect one machine, not the repo. The engine's differentiator is rules that travel with the repo (shared, hard deny semantics, ip_class tripwires, sidecar-aware); the 2026-08 audit showed it lost on authoring ergonomics only. So /guardrails authors guardrails.json, and routes misfit hazards (stop/prompt events, explicitly personal scope) to hookify rather than absorbing it or conceding to it.
- Consequences: state-dependent hazards stay out of scope — that is the stateful-guardrail-predicates idea, gated behind this slice by design.
- Spawns: A-20260824-guardrail-conversational-authoring

Considered and rejected: emitting hookify `.local.md` rules (loses repo-shared rules — the engine's whole point); guardrails.json-only with no routing (recreates the ergonomics gap for hazards the engine genuinely cannot express). Spec: `docs/specs/2026-08-24-guardrail-conversational-authoring-design.md` § Decision.
```

- [ ] **Step 3: Log the lint follow-up idea and annotate the promoted one**

Append to `docs/project-tracking/ideas.md`:

```markdown
### lint-conversational-authoring — decide lint.json's future (author, fold, or retire)  (EC2 audit 2026-08-24)
- Workstream: workflow
- Priority: mid
- Intended start: after /guardrails has real-use evidence
- Why/context: the advisory lint hook scored 1/10 in the EC2 audit — the same hand-authored-JSON disease as guardrails (zero `.claude/lint.json` in any real workspace). But the right fix may differ: capture the QUESTION (conversational authoring like /guardrails, fold linting into the guardrail engine, or retire the hook) rather than presuppose a build. D-20260824-guardrails-canonical-hookify-misfits settles the guardrail half only.
- To start, future-us needs: /guardrails adoption evidence (did conversational authoring actually light up the dark surface?), then a short decision spec across the three options.
```

And in the existing `### guardrail-conversational-authoring` idea entry, add one line directly after its `- Intended start:` line:

```markdown
- **In progress (2026-08-24):** promoted to A-20260824-guardrail-conversational-authoring; decision D-20260824-guardrails-canonical-hookify-misfits; spec + plan in docs/specs+plans (2026-08-24).
```

- [ ] **Step 4: Commit tracking, push, open the PR**

```bash
git add docs/project-tracking/
git commit -m "chore(tracking): open A-20260824-guardrail-conversational-authoring + decision + lint follow-up idea"
git push -u origin feature/guardrail-conversational-authoring
gh pr create --title "feat: /guardrails — conversational guardrail authoring (v0.22.0)" \
  --body "Implements docs/specs/2026-08-24-guardrail-conversational-authoring-design.md: guardrails-upsert.sh (fail-loud add/remove/list, sidecar-aware), the /guardrails skill (route → draft → dry-run through the real engine → propose-confirm → apply), capture-cadence nudge, full test suite.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 5: Verify CI is green**

Watch the PR's `validate` run (`gh pr checks`). Expected: success — including the new `test-guardrails-upsert.sh` step. Do not merge without green CI (repo rule). Merging, and the post-merge `/project-log done` (action → resolved with the merge SHA) plus the idea's `**Shipped (v0.22.0)**` annotation, happen after the user's go-ahead — not in this plan.
```
