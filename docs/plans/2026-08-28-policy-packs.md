# Policy Packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the policy-pack format, the fail-loud `pack-import.sh` (stamped, idempotent, ledgered), the `/guardrails pack` subcommand, and two starter packs (`public-repo`, `enterprise-clean-room`).

**Architecture:** Packs are machine-read JSON files in the plugin's `packs/` dir. The skill substitutes `{{params}}` conversationally and hands final JSON to a new deterministic script that merges rules (each stamped `"pack": "<name>"`) into the resolved `.claude/guardrails.json` + `.claude/lint.json` with a `_packs` ledger — idempotent re-import, exact removal, hand-authored rules untouched. The engines already ignore unknown rule keys, so activation stays automatic.

**Tech Stack:** bash + jq (script), python3 stdlib (validator pass), markdown skill prose, plain-bash tests.

**Spec:** `docs/specs/2026-08-28-policy-packs-design.md`

## Global Constraints

- One distribution channel: packs ship in the plugin's `packs/` dir; pack version = plugin version (from `.claude-plugin/plugin.json`).
- `{{placeholder}}` substitution happens ONLY in the skill; `pack-import.sh` dies on any remaining `{{` in a pack.
- Per-rule `"pack": "<name>"` stamp in both config files; `_packs` ledger lives in `guardrails.json` only.
- `add` replaces only rules stamped with that pack's name; hand-authored rules (no `pack` field) are never touched. `remove` never changes `ip_class` (prints a note instead).
- Config resolution mirrors the existing seams: `GUARDRAIL_CONFIG` / `LINT_CONFIG` env overrides → sidecar `<data_root>/guardrails.json` / `<data_root>/lint.json` → `<git root>/.claude/*.json`. On `add` only, missing configs are seeded from `templates/guardrails.json` / `templates/lint.json`; `remove`/`list` never create files.
- Script is fail-loud (stderr + nonzero, configs untouched via atomic per-file edits); the engines stay unchanged.
- House test style (`contains`-style checks, tmpdir fixture, nonzero exit on failure); version bump `0.26.0` → `0.27.0` in the packaging task; run `validate-plugin.py` only after docs mentions land.
- Every commit ends with the repo's standard co-author + session trailer.

---

### Task 1: Kickoff — branch + tracking dogfood

**Files:**
- Modify: `docs/project-tracking/action-items.md`, `docs/project-tracking/decisions-log.md`, `docs/project-tracking/ideas.md`
- Commit also: `docs/plans/2026-08-28-policy-packs.md` (this plan — it is untracked until now)

**Interfaces:**
- Produces: branch `feat/policy-packs`; IDs `A-20260828-policy-packs`, `D-20260828-pack-stamp-ledger` (Task 6 close-out references these).

- [ ] **Step 1: Branch + commit the plan doc**

```bash
cd /home/manthan01/Documents/Codebase/workspace-os
git checkout main && git pull && git checkout -b feat/policy-packs
git add docs/plans/2026-08-28-policy-packs.md
git commit -m "docs(plan): policy-packs implementation plan"
```

- [ ] **Step 2: Add the action record**

In `docs/project-tracking/action-items.md`, replace `_No open items yet._` with:

```markdown
### A-20260828-policy-packs — pack format + import script + /guardrails pack + two starter packs
- Workstream: packaging
- Status: open
- Created: 2026-08-28

Ships the policy-packs idea (keystone v0.2.0 review 2026-08-28). Spec:
docs/specs/2026-08-28-policy-packs-design.md. Plan: docs/plans/2026-08-28-policy-packs.md.
```

- [ ] **Step 3: Append the decision record**

Append to `docs/project-tracking/decisions-log.md`:

```markdown
### D-20260828-pack-stamp-ledger — pack provenance = per-rule stamp + a _packs ledger; removal never downgrades ip_class
- Workstream: packaging
- Created: 2026-08-28
- Status: accepted
- Rationale: the keystone anti-borrows enforced by construction — one distribution channel (in-plugin packs/, version = plugin version), machine-read manifests (a pack failing validate-plugin.py fails CI), and imports that are idempotent and scoped: every imported rule carries `"pack": "<name>"` (the engines read named fields only, so the stamp is inert — proven by test), `add` deletes-then-inserts only that pack's stamped rules (hand-authored rules are never touched; no delete-and-recopy), and a `_packs` ledger in guardrails.json records {version, imported} per pack. `remove` deletes the stamped rules + ledger entry but never changes ip_class — silently dropping a provenance boundary is worse than a stale one, so it prints a review note instead. Params ({{placeholders}}) are substituted by the /guardrails skill conversationally; the deterministic script dies on any unsubstituted placeholder, keeping bash template-free.
- Consequences: /guardrails grows a pack mode (list/add/remove); validate-plugin.py gains a packs gate; the starter enterprise-clean-room pack productizes the two measured UDX hazards (employer tripwire content, enterprise remote traffic) that today live in personal hookify rules.
- Spawns: A-20260828-policy-packs

Design: docs/specs/2026-08-28-policy-packs-design.md (brainstormed + approved 2026-08-28).
```

- [ ] **Step 4: Graduate the idea**

In `docs/project-tracking/ideas.md`: delete the whole `### policy-packs — …` section (now active as `A-20260828-policy-packs`). Then `grep -n "policy-packs" docs/project-tracking/ideas.md` and repoint survivors: in `### keystone-module-guardrails`, change `Compounds with [[policy-packs]] (our engine + a starter pack beats the bare engine as a contribution).` to `Compounds with policy-packs (active as A-20260828-policy-packs; our engine + a starter pack beats the bare engine as a contribution).` (Leave `decisions-log.md` references alone — append-only.)

- [ ] **Step 5: Lint + commit**

```bash
python3 scripts/memory_graph.py --check
git add docs/project-tracking/
git commit -m "chore(tracking): kick off policy-packs slice (A-20260828, D-20260828)"
```
Expected: `memory_graph: clean`.

---

### Task 2: `scripts/pack-import.sh` (TDD)

**Files:**
- Create: `scripts/pack-import.sh`
- Test: `tests/test-pack-import.sh`
- Modify: `.github/workflows/ci.yml` (register after `- run: bash tests/test-checkout-groups.sh`)

**Interfaces:**
- Produces: `pack-import.sh [--packs-dir DIR] list | add <pack-json-path> | remove <pack-name>` — env seams `GUARDRAIL_CONFIG`, `LINT_CONFIG`; per-rule `pack` field; `_packs` ledger `{name: {version, imported}}` in the guardrails config. Tasks 3–4 rely on these exact commands and field names.

- [ ] **Step 1: Write the failing test**

Create `tests/test-pack-import.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash test harness for scripts/pack-import.sh (deps: bash + jq).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/pack-import.sh"
ENGINE="$HERE/../hooks/guardrail.sh"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }
check() { if [ "$2" = 0 ]; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
GCFG="$TMP/.claude/guardrails.json"; LCFG="$TMP/.claude/lint.json"
export GUARDRAIL_CONFIG="$GCFG" LINT_CONFIG="$LCFG"
PACKS="$TMP/packs"; mkdir -p "$PACKS"

# Fixture pack: bash + write rules, a linter, ip_class — already substituted (no {{}}).
cat > "$PACKS/testpack.json" <<'EOF'
{ "name": "testpack", "description": "fixture",
  "ip_class": "enterprise",
  "guardrails": {
    "bash":  [ { "name": "tp-bash", "match": "forbidden\\.example", "action": "deny", "reason": "tp bash" } ],
    "write": [ { "name": "tp-write", "match": "TRIPWIRE", "field": "content", "action": "deny", "reason": "tp write" } ] },
  "lint": { "linters": [ { "name": "tp-lint", "match": "\\.py$", "command": "true" } ] } }
EOF

# 1) add: rules stamped, ledger written, ip_class set, linter landed
out="$(bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" 2>&1)"; ec=$?
check "add exits 0" $([ "$ec" = 0 ] && echo 0 || echo 1)
check "bash rule stamped"   $([ "$(jq -r '.bash[]  | select(.name=="tp-bash").pack'  "$GCFG")" = "testpack" ] && echo 0 || echo 1)
check "write rule stamped"  $([ "$(jq -r '.write[] | select(.name=="tp-write").pack' "$GCFG")" = "testpack" ] && echo 0 || echo 1)
check "ledger has version"  $(jq -e '._packs.testpack.version' "$GCFG" >/dev/null && echo 0 || echo 1)
check "ledger has date"     $(jq -e '._packs.testpack.imported' "$GCFG" >/dev/null && echo 0 || echo 1)
check "ip_class set"        $([ "$(jq -r '.ip_class' "$GCFG")" = "enterprise" ] && echo 0 || echo 1)
check "linter stamped"      $([ "$(jq -r '.linters[] | select(.name=="tp-lint").pack' "$LCFG")" = "testpack" ] && echo 0 || echo 1)

# 2) idempotent re-add: counts stable
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" >/dev/null 2>&1
check "re-add no dup bash"  $([ "$(jq '.bash | length' "$GCFG")" = 1 ] && echo 0 || echo 1)
check "re-add no dup lint"  $([ "$(jq '.linters | length' "$LCFG")" = 1 ] && echo 0 || echo 1)

# 3) hand-authored rule survives add and remove
jq '.bash += [{"name":"hand-rule","match":"handmade","action":"warn","reason":"mine"}]' "$GCFG" > "$GCFG.t" && mv "$GCFG.t" "$GCFG"
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" >/dev/null 2>&1
check "hand rule survives add" $(jq -e '.bash[] | select(.name=="hand-rule")' "$GCFG" >/dev/null && echo 0 || echo 1)

# 4) engine tolerance: stamped deny rule fires (extra key inert)
printf '{"tool_name":"Bash","tool_input":{"command":"git push forbidden.example main"}}' \
  | GUARDRAIL_CONFIG="$GCFG" bash "$ENGINE" >/dev/null 2>&1; ec=$?
check "engine denies on stamped rule (exit 2)" $([ "$ec" = 2 ] && echo 0 || echo 1)

# 5) remove: pack rules + ledger gone, hand rule survives, ip_class note printed
out="$(bash "$SCRIPT" --packs-dir "$PACKS" remove testpack 2>&1)"; ec=$?
check "remove exits 0"          $([ "$ec" = 0 ] && echo 0 || echo 1)
check "pack bash rule gone"     $(jq -e '.bash[] | select(.name=="tp-bash")' "$GCFG" >/dev/null 2>&1 && echo 1 || echo 0)
check "pack linter gone"        $(jq -e '.linters[] | select(.name=="tp-lint")' "$LCFG" >/dev/null 2>&1 && echo 1 || echo 0)
check "ledger entry gone"       $(jq -e '._packs.testpack' "$GCFG" >/dev/null 2>&1 && echo 1 || echo 0)
check "hand rule survives remove" $(jq -e '.bash[] | select(.name=="hand-rule")' "$GCFG" >/dev/null && echo 0 || echo 1)
case "$out" in *ip_class*) ok "ip_class note printed";; *) bad "ip_class note printed (out=[$out])";; esac
check "ip_class untouched by remove" $([ "$(jq -r '.ip_class' "$GCFG")" = "enterprise" ] && echo 0 || echo 1)

# 6) unsubstituted placeholder -> die, config untouched
cat > "$PACKS/badsub.json" <<'EOF'
{ "name": "badsub", "description": "x",
  "guardrails": { "bash": [ { "name": "b", "match": "{{oops}}", "action": "deny", "reason": "r" } ] } }
EOF
before="$(cat "$GCFG")"
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/badsub.json" >/dev/null 2>&1; ec=$?
check "unsubstituted placeholder dies" $([ "$ec" != 0 ] && echo 0 || echo 1)
check "config untouched after die"     $([ "$(cat "$GCFG")" = "$before" ] && echo 0 || echo 1)

# 7) invalid regex -> die, config untouched
cat > "$PACKS/badre.json" <<'EOF'
{ "name": "badre", "description": "x",
  "guardrails": { "bash": [ { "name": "b", "match": "([unclosed", "action": "deny", "reason": "r" } ] } }
EOF
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/badre.json" >/dev/null 2>&1; ec=$?
check "invalid regex dies" $([ "$ec" != 0 ] && echo 0 || echo 1)
check "config untouched after regex die" $([ "$(cat "$GCFG")" = "$before" ] && echo 0 || echo 1)

# 8) remove of a pack never imported -> die
bash "$SCRIPT" --packs-dir "$PACKS" remove neverimported >/dev/null 2>&1; ec=$?
check "remove unknown pack dies" $([ "$ec" != 0 ] && echo 0 || echo 1)

# 9) list shows available + imported
bash "$SCRIPT" --packs-dir "$PACKS" add "$PACKS/testpack.json" >/dev/null 2>&1
out="$(bash "$SCRIPT" --packs-dir "$PACKS" list 2>&1)"
case "$out" in *testpack*) ok "list names the pack";; *) bad "list names the pack (out=[$out])";; esac
case "$out" in *imported*) ok "list shows imported state";; *) bad "list shows imported state (out=[$out])";; esac

echo "---"; echo "pass=$pass fail=$fail"; [ "$fail" = 0 ]
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/test-pack-import.sh`
Expected: failures/errors (script does not exist).

- [ ] **Step 3: Implement the script**

Create `scripts/pack-import.sh`:

```bash
#!/usr/bin/env bash
# workspace-os pack import — the deterministic write path for /guardrails pack.
# list | add <pack-json-path> | remove <pack-name>  (spec: docs/specs/2026-08-28-policy-packs-design.md)
# Merges a pack's guardrail rules + lint linters into the resolved configs, each rule stamped
# "pack": "<name>", with a _packs ledger {version, imported} in guardrails.json. Idempotent:
# add replaces only that pack's stamped rules; hand-authored rules are never touched; remove
# never changes ip_class (prints a note). FAILS LOUD: any error -> stderr, nonzero, configs
# untouched (atomic per-file edits). Placeholders are the skill's job: any remaining "{{"
# in a pack is an error here. Deps: bash + jq.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GTEMPLATE="$HERE/../templates/guardrails.json"
LTEMPLATE="$HERE/../templates/lint.json"
PACKS_DIR="$HERE/../packs"

die() { echo "pack-import: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq is required"

usage() {
  cat >&2 <<'EOF'
usage:
  pack-import.sh [--packs-dir DIR] list
  pack-import.sh [--packs-dir DIR] add <pack-json-path>
  pack-import.sh [--packs-dir DIR] remove <pack-name>
EOF
  exit 1
}

# Resolve both configs. Mirrors guardrails-upsert.sh / hooks/lint.sh:
# env seam -> sidecar data root -> <git root>/.claude/.
resolve_configs() {
  local out sc_mode sc_root root
  out="$(bash "$HERE/resolve-data-root.sh" 2>/dev/null || true)"
  sc_mode="$(printf '%s\n' "$out" | sed -n 's/^mode=//p')"
  sc_root="$(printf '%s\n' "$out" | sed -n 's/^data_root=//p')"
  if [ -n "${GUARDRAIL_CONFIG:-}" ]; then gconfig="$GUARDRAIL_CONFIG"
  elif [ "$sc_mode" = "sidecar" ]; then gconfig="$sc_root/guardrails.json"
  else
    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
    gconfig="$root/.claude/guardrails.json"
  fi
  if [ -n "${LINT_CONFIG:-}" ]; then lconfig="$LINT_CONFIG"
  elif [ "$sc_mode" = "sidecar" ]; then lconfig="$sc_root/lint.json"
  else
    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -z "$root" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"
    lconfig="$root/.claude/lint.json"
  fi
}

plugin_version() { jq -r '.version // "unknown"' "$HERE/../.claude-plugin/plugin.json" 2>/dev/null || echo unknown; }

atomic_edit() {  # atomic_edit <file> <jq-args...>
  local f="$1"; shift
  local tmp="$f.tmp.$$"
  if ! jq "$@" "$f" > "$tmp" 2>/dev/null; then rm -f "$tmp"; die "jq edit failed on $f"; fi
  if ! jq -e . "$tmp" >/dev/null 2>&1; then rm -f "$tmp"; die "result did not parse; $f untouched"; fi
  mv "$tmp" "$f"
}

seed() {  # seed <config> <template>
  [ -f "$1" ] && return 0
  [ -f "$2" ] || die "template missing: $2"
  mkdir -p "$(dirname "$1")" || die "cannot create $(dirname "$1")"
  cp "$2" "$1" || die "cannot seed $1"
}

cmd_add() {
  local pack_file="$1"
  [ -f "$pack_file" ] || die "no such pack file: $pack_file"
  jq -e . "$pack_file" >/dev/null 2>&1 || die "pack does not parse: $pack_file"
  grep -q '{{' "$pack_file" && die "unsubstituted {{placeholder}} in pack (params are the skill's job)"
  local name; name="$(jq -r '.name // empty' "$pack_file")"
  [ -n "$name" ] || die "pack has no name"
  # Validate every regex in the engine's jq test() dialect before touching anything.
  local bad
  bad="$(jq -r '[(.guardrails.bash // [])[].match, (.guardrails.write // [])[].match, (.lint.linters // [])[].match] | .[]' "$pack_file" \
    | while IFS= read -r m; do
        jq -ne --arg m "$m" '"x" | test($m) | true' >/dev/null 2>&1 || printf '%s\n' "$m"
      done)"
  [ -z "$bad" ] || die "invalid regex for the engine's jq test() dialect: $bad"

  seed "$gconfig" "$GTEMPLATE"
  jq -e . "$gconfig" >/dev/null 2>&1 || die "existing config does not parse, refusing to touch it: $gconfig"
  atomic_edit "$gconfig" --slurpfile p "$pack_file" --arg v "$(plugin_version)" --arg d "$(date +%F)" '
    $p[0] as $pack | $pack.name as $n
    | .bash  = ((.bash  // []) | map(select(.pack != $n))) + [($pack.guardrails.bash  // [])[] | . + {pack: $n}]
    | .write = ((.write // []) | map(select(.pack != $n))) + [($pack.guardrails.write // [])[] | . + {pack: $n}]
    | (if ($pack.ip_class // "") != "" then .ip_class = $pack.ip_class else . end)
    | ._packs = ((._packs // {}) + {($n): {version: $v, imported: $d}})'

  if [ "$(jq '(.lint.linters // []) | length' "$pack_file")" -gt 0 ]; then
    seed "$lconfig" "$LTEMPLATE"
    jq -e . "$lconfig" >/dev/null 2>&1 || die "existing config does not parse, refusing to touch it: $lconfig"
    atomic_edit "$lconfig" --slurpfile p "$pack_file" '
      $p[0] as $pack | $pack.name as $n
      | .linters = ((.linters // []) | map(select(.pack != $n))) + [($pack.lint.linters // [])[] | . + {pack: $n}]'
  fi
  echo "imported pack '$name' (v$(plugin_version)) -> $gconfig"
}

cmd_remove() {
  local name="$1"
  [ -n "$name" ] || usage
  [ -f "$gconfig" ] || die "no guardrails config at $gconfig"
  jq -e . "$gconfig" >/dev/null 2>&1 || die "config does not parse: $gconfig"
  jq -e --arg n "$name" '._packs[$n]' "$gconfig" >/dev/null 2>&1 || die "pack '$name' is not imported here"
  atomic_edit "$gconfig" --arg n "$name" '
      .bash  = ((.bash  // []) | map(select(.pack != $n)))
    | .write = ((.write // []) | map(select(.pack != $n)))
    | ._packs = ((._packs // {}) | del(.[$n]))'
  if [ -f "$lconfig" ] && jq -e . "$lconfig" >/dev/null 2>&1; then
    atomic_edit "$lconfig" --arg n "$name" '.linters = ((.linters // []) | map(select(.pack != $n)))'
  fi
  # ip_class is never downgraded by removal; note it when this pack is the likely setter.
  local pf="$PACKS_DIR/$name.json" pip cur
  cur="$(jq -r '.ip_class // ""' "$gconfig")"
  if [ -f "$pf" ]; then
    pip="$(jq -r '.ip_class // ""' "$pf" 2>/dev/null || true)"
    if [ -n "$pip" ] && [ "$pip" = "$cur" ]; then
      echo "note: ip_class left as '$cur' - this pack set it; review manually"
    fi
  fi
  echo "removed pack '$name' from $gconfig"
}

cmd_list() {
  echo "available packs ($PACKS_DIR):"
  local found=0 f
  for f in "$PACKS_DIR"/*.json; do
    [ -f "$f" ] || continue
    found=1
    jq -r '[.name, ((.params // []) | length | tostring) + " params", .description] | join("  |  ")' "$f" 2>/dev/null \
      || echo "  (unparseable: $f)"
  done
  [ "$found" = 1 ] || echo "  (none)"
  echo "imported here ($gconfig):"
  if [ -f "$gconfig" ] && jq -e . "$gconfig" >/dev/null 2>&1; then
    jq -r '(._packs // {}) | to_entries[] | "  \(.key)  imported \(.value.imported)  (plugin v\(.value.version))"' "$gconfig"
    [ "$(jq '(._packs // {}) | length' "$gconfig")" -gt 0 ] || echo "  (none imported)"
  else
    echo "  (no config yet)"
  fi
}

# --- arg parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --packs-dir) [ $# -ge 2 ] || die "missing value for --packs-dir"; PACKS_DIR="$2"; shift 2 ;;
    *) break ;;
  esac
done
cmd="${1:-}"; [ $# -gt 0 ] && shift
resolve_configs
case "$cmd" in
  add)    [ $# -ge 1 ] || usage; cmd_add "$1" ;;
  remove) [ $# -ge 1 ] || usage; cmd_remove "$1" ;;
  list)   cmd_list ;;
  *) usage ;;
esac
```

Then: `chmod +x scripts/pack-import.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-pack-import.sh`
Expected: all PASS, `fail=0`. (`list`'s "imported" substring comes from the `imported <date>` line.)

- [ ] **Step 5: Register in CI + commit**

In `.github/workflows/ci.yml`, after `- run: bash tests/test-checkout-groups.sh` add:

```yaml
      - run: bash tests/test-pack-import.sh
```

```bash
git add scripts/pack-import.sh tests/test-pack-import.sh .github/workflows/ci.yml
git commit -m "feat: pack-import.sh - stamped, idempotent, ledgered policy-pack import"
```

---

### Task 3: Starter packs + validator gate

**Files:**
- Create: `packs/public-repo.json`, `packs/enterprise-clean-room.json`
- Modify: `scripts/validate-plugin.py` (packs pass, inserted after the doc-freshness block, before `if errors:`)

**Interfaces:**
- Consumes: the pack format (Task 2's script reads these files unchanged when parameter-free, substituted otherwise).

- [ ] **Step 1: Create `packs/public-repo.json`**

```json
{
  "name": "public-repo",
  "description": "Deny-tier protections for a public repo: secrets files, private keys, force-push to the default branch.",
  "guardrails": {
    "bash": [
      { "name": "pack-no-force-push-default", "match": "git push[^|;&]*(--force|-f )[^|;&]*\\b(main|master)\\b", "action": "deny", "reason": "public-repo pack: force-push to the default branch rewrites shared history. Use a feature branch + PR." }
    ],
    "write": [
      { "name": "pack-no-env-files", "match": "(^|/)\\.env(\\..+)?$", "field": "path", "action": "deny", "reason": "public-repo pack: .env files never enter a public repo. Use environment variables or a gitignored local file." },
      { "name": "pack-no-private-keys", "match": "-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----", "field": "content", "action": "deny", "reason": "public-repo pack: private key material in write content. Remove it." }
    ]
  },
  "lint": { "linters": [] }
}
```

- [ ] **Step 2: Create `packs/enterprise-clean-room.json`**

```json
{
  "name": "enterprise-clean-room",
  "description": "IP boundary + never-push wall for working beside an employer codebase: denies tripwire content and enterprise-remote git traffic; marks the repo ip_class enterprise.",
  "params": [
    { "name": "tripwire_regex", "prompt": "Employer-identifying strings as a regex alternation (e.g. AcmeCorp|acme\\.internal)" },
    { "name": "forbidden_remote_regex", "prompt": "Enterprise git remote host pattern (e.g. github\\.acme\\.example)" }
  ],
  "ip_class": "enterprise",
  "guardrails": {
    "bash": [
      { "name": "pack-no-enterprise-remote", "match": "git[^|;&]*(push|pull|fetch|clone|remote[[:space:]]+add)[^|;&]*{{forbidden_remote_regex}}", "action": "deny", "reason": "enterprise-clean-room pack: git traffic to an enterprise remote from this workspace is a hard boundary." },
      { "name": "pack-no-tripwire-in-commands", "match": "{{tripwire_regex}}", "action": "deny", "reason": "enterprise-clean-room pack: employer tripwire string in a command. Keep employer content out of this workspace." }
    ],
    "write": [
      { "name": "pack-no-tripwire-content", "match": "{{tripwire_regex}}", "field": "content", "action": "deny", "reason": "enterprise-clean-room pack: employer tripwire string crossing into written content." }
    ]
  },
  "lint": { "linters": [] }
}
```

- [ ] **Step 3: Add the validator packs pass**

In `scripts/validate-plugin.py`, insert after the doc-freshness block (after the `for hook in …` loop) and before `if errors:`:

```python
# Packs gate: every packs/*.json is machine-valid — a pack failing here fails CI
# (spec: docs/specs/2026-08-28-policy-packs-design.md).
import re
for pack_path in sorted((REPO / "packs").glob("*.json")):
    rel = pack_path.relative_to(REPO)
    try:
        pack = json.loads(pack_path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{rel}: invalid JSON ({e})")
        continue
    if pack.get("name") != pack_path.stem:
        errors.append(f"{rel}: 'name' must equal the filename stem ('{pack.get('name')}')")
    for key in ("description", "guardrails"):
        if not pack.get(key):
            errors.append(f"{rel}: missing required key '{key}'")
    strings = [pack.get("ip_class") or ""]
    for rtype in ("bash", "write"):
        for rule in (pack.get("guardrails") or {}).get(rtype, []):
            for field in ("name", "match", "action", "reason"):
                if not rule.get(field):
                    errors.append(f"{rel}: {rtype} rule missing '{field}'")
            strings.extend(str(v) for v in rule.values())
    for linter in (pack.get("lint") or {}).get("linters", []):
        for field in ("name", "match", "command"):
            if not linter.get(field):
                errors.append(f"{rel}: linter missing '{field}'")
        strings.extend(str(v) for v in linter.values())
    declared = set()
    for param in pack.get("params", []):
        if not param.get("name") or not param.get("prompt"):
            errors.append(f"{rel}: every param needs 'name' and 'prompt'")
        declared.add(param.get("name"))
    used = set()
    for s in strings:
        used.update(re.findall(r"\{\{(\w+)\}\}", s))
    for p in sorted(declared - used - {None}):
        errors.append(f"{rel}: param '{p}' declared but never used")
    for p in sorted(used - declared):
        errors.append(f"{rel}: placeholder '{{{{{p}}}}}' not declared in params")
```

- [ ] **Step 4: Verify the validator passes on the real packs**

Run: `python3 scripts/validate-plugin.py`
Expected: `Plugin validation passed (17 skills checked).` — no pack errors. (Negative-test it once: temporarily add `"{{bogus}}"` to a reason in `public-repo.json`, re-run, expect a placeholder error, revert.)

- [ ] **Step 5: Commit**

```bash
git add packs/ scripts/validate-plugin.py
git commit -m "feat: public-repo + enterprise-clean-room starter packs + validator packs gate"
```

---

### Task 4: `/guardrails pack` mode

**Files:**
- Modify: `skills/guardrails/SKILL.md` (dispatch + new Pack mode section; description note)

**Interfaces:**
- Consumes: `pack-import.sh list|add|remove` (Task 2), the pack format + params (Task 3).

- [ ] **Step 1: Update description + dispatch**

In the frontmatter `description`, before the final sentence append: `Also imports/removes policy packs (/guardrails pack list|add NAME|remove NAME) - versioned rule bundles shipped with the plugin.`

In `## Dispatch`, add before the final "Anything else" bullet:

```markdown
- `pack list` / `pack add <name>` / `pack remove <name>` -> Pack mode below.
```

- [ ] **Step 2: Add the Pack mode section**

Append at the end of `skills/guardrails/SKILL.md`:

```markdown
## Pack mode

Policy packs are versioned rule bundles in this plugin's `packs/` dir
(`conventions/packs.md` is the format SoT). Every write goes through
`scripts/pack-import.sh` (fail-loud, atomic, idempotent - re-import replaces only that
pack's stamped rules and never touches hand-authored ones); this skill NEVER edits the
configs by hand.

- `pack list` -> run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pack-import.sh" list`, show the
  output verbatim.
- `pack add <name>`:
  1. Read `${CLAUDE_PLUGIN_ROOT}/packs/<name>.json` (missing -> run `pack list`, stop).
  2. For each entry in `params`, ask the user for a value using its `prompt` text, then
     substitute every `{{name}}` occurrence in the pack JSON. No params -> skip.
  3. Propose: the full resulting rule set and linters, where they will land (the resolved
     config paths from the prerequisite step), and - when the pack declares `ip_class` -
     the class change, called out explicitly ("this marks the repo's policy class
     '<value>'"). Wait for confirmation.
  4. On yes: write the substituted JSON to a temp file, run
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pack-import.sh" add <temp-file>`, delete the
     temp file, surface any script error verbatim. In sidecar mode commit the sidecar
     repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).
  5. Report: the script's output, plus the removal one-liner
     (`/guardrails pack remove <name>`).
- `pack remove <name>` -> show what `pack list` says is imported for that name, confirm,
  run `... pack-import.sh remove <name>`, and relay its `ip_class` note verbatim when it
  prints one. Sidecar commit as above.

Param values are org-specific (tripwire strings, remote hosts) - treat them as the repo's
policy data: they land in the version-controlled config, so never include an actual secret
VALUE (a token, a password) as a param; tripwires are identifying STRINGS, not credentials.
```

- [ ] **Step 3: Commit**

```bash
git add skills/guardrails/SKILL.md
git commit -m "feat: /guardrails pack mode - list/add/remove policy packs"
```

---

### Task 5: Conventions doc, README/GUIDE, version, full verification

**Files:**
- Create: `conventions/packs.md`
- Modify: `README.md` (`/guardrails` feature-map row), `GUIDE.md` (Occasional operations), `.claude-plugin/plugin.json` (`0.26.0` → `0.27.0`)

**Interfaces:**
- Consumes: everything above; the doc-freshness gate needs no new mention (no new skill/hook), but the pack mode is documented anyway.

- [ ] **Step 1: Create `conventions/packs.md`**

```markdown
# Policy-Pack Conventions

The single source of truth for the pack format. `/guardrails pack` and
`scripts/pack-import.sh` follow these rules - they do not restate them.
Spec: `docs/specs/2026-08-28-policy-packs-design.md`.

## What a pack is

A versioned, machine-read bundle of guardrail rules + lint linters, shipped in this
plugin's `packs/<name>.json` (one distribution channel; the pack's version IS the plugin
version). Importing a pack is activation: the engines read the target configs directly, so
a landed pack enforces immediately.

## Format (`packs/<name>.json`)

- `name` (required, = filename stem), `description` (required).
- `guardrails` (required): `bash` / `write` arrays of the engine's exact rule shape
  (`name`, `match`, `action` deny|warn, `reason`, plus `field` content|path on write rules).
- `lint` (optional): `linters` array of the lint engine's shape (`name`, `match`, `command`).
- `ip_class` (optional): set on import; announced by the skill before confirmation.
- `params` (optional): `[{name, prompt}]`. Rule strings may carry `{{name}}` placeholders;
  the `/guardrails` skill substitutes values conversationally BEFORE the import script runs
  (the script dies on any remaining `{{`). Params are policy data, never secret values.
- Validation: `scripts/validate-plugin.py` fails CI on a malformed pack (parse, required
  fields, params declared <-> placeholders used).

## Import semantics (`scripts/pack-import.sh`)

- Every imported rule/linter is stamped `"pack": "<name>"` (inert to the engines).
- `add` replaces only that pack's stamped rules - idempotent re-import; hand-authored
  rules are never touched. A `_packs` ledger in `guardrails.json` records
  `{name: {version, imported}}`.
- `remove` deletes the stamped rules + ledger entry from both configs but NEVER changes
  `ip_class` - it prints a review note instead (dropping a provenance boundary silently is
  worse than a stale one).
- Configs resolve exactly like the engines read them (sidecar data root, else
  `<git root>/.claude/`); missing configs are seeded from the templates on `add` only.
```

- [ ] **Step 2: README + GUIDE**

README: in the `/guardrails` feature-map row, change the description to `author a deny/warn rule from a described hazard (dry-run proven); pack imports versioned policy packs | [conventions](conventions/packs.md)` — keep the row's existing link cell if editing only the middle column; the final cell may point at `[GUIDE](GUIDE.md#guardrails)` as it does now, in which case append the conventions link inline in the description instead.

GUIDE: locate the guardrails part of `## Occasional operations` (`grep -n "guardrails" GUIDE.md`) and append this paragraph to that subsection:

```markdown
**Policy packs** bundle ready-made rules: `/guardrails pack list` shows what ships with the
plugin, `/guardrails pack add public-repo` imports deny-tier protections for a public repo,
and `/guardrails pack add enterprise-clean-room` sets up an employer IP boundary (it asks
for your tripwire strings and enterprise remote pattern, then denies both everywhere in the
repo). Re-importing after a plugin update refreshes a pack's rules without touching rules
you wrote yourself; `/guardrails pack remove <name>` takes one out again.
```

- [ ] **Step 3: Bump the version**

`.claude-plugin/plugin.json`: `"version": "0.26.0"` → `"version": "0.27.0"`.

- [ ] **Step 4: Full verification**

```bash
python3 scripts/validate-plugin.py
for t in tests/test-*.sh; do bash "$t" >/dev/null 2>&1 || echo "SUITE FAIL: $t"; done; echo done
```
Expected: validation passed (17 skills), no `SUITE FAIL` lines.

- [ ] **Step 5: Commit**

```bash
git add conventions/packs.md README.md GUIDE.md .claude-plugin/plugin.json
git commit -m "chore: v0.27.0 - packs conventions + docs"
```

---

### Task 6: Ship — PR, CI, merge, close-out

**Files:**
- Modify: `docs/project-tracking/action-items.md` / `resolved.md`, `decisions-log.md`, `ideas.md` (keystone-module-guardrails note)

**Interfaces:**
- Consumes: `A-20260828-policy-packs`, `D-20260828-pack-stamp-ledger` (Task 1).

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin feat/policy-packs
gh pr create --title "Policy packs: versioned importable guardrail/lint policy (v0.27.0)" --body "Ships the policy-packs idea: machine-read pack format (conventions/packs.md), fail-loud pack-import.sh (per-rule stamp, _packs ledger, idempotent, never touches hand-authored rules, no ip_class downgrade on remove), /guardrails pack list|add|remove with skill-side param substitution, two starter packs (public-repo, enterprise-clean-room), and a validator packs gate. Spec: docs/specs/2026-08-28-policy-packs-design.md. Decision: D-20260828-pack-stamp-ledger."
```
(Repo PR-body trailer conventions apply.)

- [ ] **Step 2: CI in the foreground** (`gh pr checks --watch`; ~10s runs, never a background watcher). Expected: `validate` pass.

- [ ] **Step 3: Merge, pull, update**

```bash
gh pr merge --squash --delete-branch
git checkout main && git pull
claude plugin update workspace-os@workspace-os
```

- [ ] **Step 4: Tracking close-out**

- Move `A-20260828-policy-packs` to `resolved.md` with `- Completed: 2026-08-28`, `- Commit: <squash sha> (PR #<N>, v0.27.0)`, restore the `_No open items yet._` placeholder, body line `Closes the policy-packs idea.`
- Append below `D-20260828-pack-stamp-ledger`: `Closes policy-packs (idea COMPLETE, v0.27.0). The starter-pack half of keystone-module-guardrails' "engine + pack" contribution now exists; see that idea's note.`
- In `ideas.md` `### keystone-module-guardrails`, append: `- Note (2026-08-28): policy-packs shipped v0.27.0 — the "engine + starter pack" contribution shape now exists (packs/enterprise-clean-room.json is the demonstrator); the keystone wrapper remains gated on Zach's buy-in.`

- [ ] **Step 5: Lint + commit close-out to main**

```bash
python3 scripts/memory_graph.py --check
git add docs/project-tracking/ && git commit -m "chore(tracking): close A-20260828-policy-packs (v0.27.0)" && git push origin main
```
