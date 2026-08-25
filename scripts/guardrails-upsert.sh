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
