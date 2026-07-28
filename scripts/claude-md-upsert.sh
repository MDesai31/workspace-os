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
