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
  bad="$(jq -r '[(.guardrails.bash // [])[].match, (.guardrails.write // [])[].match, (.guardrails.dispatch // [])[].match, (.lint.linters // [])[].match] | .[]' "$pack_file" \
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
    | .dispatch = ((.dispatch // []) | map(select(.pack != $n))) + [($pack.guardrails.dispatch // [])[] | . + {pack: $n}]
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
    | .dispatch = ((.dispatch // []) | map(select(.pack != $n)))
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
    jq -r '"  " + ([.name, ((.params // []) | length | tostring) + " params", .description] | join("  |  "))' "$f" 2>/dev/null \
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
