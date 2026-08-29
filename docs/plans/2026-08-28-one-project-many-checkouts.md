# One Project, Many Checkouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the propagation schema (`Propagation:` / `Propagated-to:` lines), the deterministic checkout-grouping script, the `/project-status matrix` view, and the `/project-log propagated` write path (spec's remaining halves of the one-project-many-checkouts idea).

**Architecture:** A new stdlib bash script (`scripts/checkout-groups.sh`) is the single deterministic source of "which folders are checkouts of one project" (grouped by normalized `origin` URL). Two existing skills gain prose modes that consume its `key=value` output; the schema itself is two append-only lines documented once in `conventions/project-tracking.md`. Sidecar workspaces only.

**Tech Stack:** bash + git (no jq needed for the new script), plain-bash test harness, markdown skill prose.

**Spec:** `docs/specs/2026-08-28-one-project-many-checkouts-design.md`

## Global Constraints

- Sidecar/workspace-meta modes only; `mode=in-repo` gets a one-line "not applicable" in both new skill modes.
- Checkouts are keyed by **folder basename** (matches `conventions/data-root.md` keying).
- All new record lines are **append-only**; never edit an existing line (the `Superseded-by:` pattern).
- Skills never re-derive grouping in prose — they consume `checkout-groups.sh` output.
- `resolve-data-root.sh`'s `workspace_root` is **the `_meta` dir itself**; tracking roots are `<workspace_root>/<folder>/project-tracking/`; the grouping script accepts either the workspace dir or the `_meta` dir and normalizes.
- House test style: plain bash, `pass`/`fail` counters, `PASS:`/`FAIL:` lines, tmpdir fixture built at runtime, non-zero exit on any failure (copy `tests/test-resolve-data-root.sh`'s harness shape).
- Every commit message ends with the standard co-author + session trailer used in this repo.
- Version bump: `.claude-plugin/plugin.json` `0.24.1` -> `0.25.0` (packaging task only).

---

### Task 1: Kickoff — branch + tracking dogfood

**Files:**
- Modify: `docs/project-tracking/action-items.md` (new open record)
- Modify: `docs/project-tracking/decisions-log.md` (append one decision)
- Modify: `docs/project-tracking/ideas.md` (graduate the idea out; repoint one wikilink)

**Interfaces:**
- Produces: branch `feat/checkout-propagation`; record IDs `A-20260828-checkout-propagation` and `D-20260828-propagation-intent-fact-lines` (later tasks and the close-out reference these exact IDs).

- [ ] **Step 1: Create the branch**

```bash
cd /home/manthan01/Documents/Codebase/workspace-os
git checkout -b feat/checkout-propagation
```

- [ ] **Step 2: Append the action record**

Replace nothing — `action-items.md` currently shows `_No open items yet._`; replace that placeholder line with:

```markdown
### A-20260828-checkout-propagation — propagation schema + checkout grouping + matrix view + write path
- Workstream: schema
- Status: open
- Created: 2026-08-28

Ships the remaining halves of the one-project-many-checkouts idea (EC2 audit 2026-08-24;
link-resolution half shipped v0.22.1). Spec:
docs/specs/2026-08-28-one-project-many-checkouts-design.md. Plan:
docs/plans/2026-08-28-one-project-many-checkouts.md.
```

- [ ] **Step 3: Append the decision record**

Append to `decisions-log.md`:

```markdown
### D-20260828-propagation-intent-fact-lines — propagation state = an intent line plus append-only fact lines, grouped by remote URL
- Workstream: schema
- Created: 2026-08-28
- Status: accepted
- Rationale: a single "landed here" line with an implicit all-checkouts target cannot express the audit's real case (a fix relevant to a subset of checkouts), so intent (`- Propagation: all | <folders>`) and fact (`- Propagated-to: <folder> <date> [sha]`) are separate lines — both appended, never edited, the `Superseded-by:` pattern, `merge=union`-safe. Grouping is automatic by normalized `origin` URL (zero config — the audit's automatic-vs-hand-authored adoption finding), keyed by folder basename like the sidecar data roots. `all` is dynamic (every grouped checkout at read time) so the matrix reflects the current workspace. Sidecar-only: in-repo checkouts share tracking files through git itself. A- records only: decisions are reasoning, not deployable diffs.
- Consequences: `/project-status` gains a `matrix` mode and `/project-log` a `propagated` mode; `scripts/checkout-groups.sh` becomes the single grouping source; the record body line-ceiling and boundary rules are untouched.
- Spawns: A-20260828-checkout-propagation

Design: docs/specs/2026-08-28-one-project-many-checkouts-design.md (brainstormed + approved 2026-08-28).
```

- [ ] **Step 4: Graduate the idea**

In `ideas.md`: delete the whole `### one-project-many-checkouts — …` section (it is now active as `A-20260828-checkout-propagation`). In the `### finding-record-class` section, change the line
`- Intended start: alongside [[one-project-many-checkouts]] (same schema touch)` to
`- Intended start: alongside A-20260828-checkout-propagation (same schema touch; that slice is now active)`.
Also grep `docs/project-tracking/ideas.md` for any other `[[one-project-many-checkouts]]` occurrences and repoint them the same way (`grep -n "one-project-many-checkouts" docs/project-tracking/ideas.md`).

- [ ] **Step 5: Lint + commit**

```bash
python3 scripts/memory_graph.py --check
git add docs/project-tracking/
git commit -m "chore(tracking): kick off checkout-propagation slice (A-20260828, D-20260828)"
```
Expected: `memory_graph: clean`.

---

### Task 2: `scripts/checkout-groups.sh` (TDD)

**Files:**
- Create: `scripts/checkout-groups.sh`
- Test: `tests/test-checkout-groups.sh`
- Modify: `.github/workflows/ci.yml` (register the test after the `test-playbook-surface.sh` line)

**Interfaces:**
- Produces: `checkout-groups.sh <workspace-dir>` — `<workspace-dir>` may be the workspace root or the `_meta` dir (normalized). Emits one line per grouped checkout:
  `project=<basename-of-key-path> key=<normalized-url> folder=<basename> branch=<current-or-empty>`
  Whole key lowercased; scheme/credentials/trailing-`.git` stripped; `git@host:path` rewritten to `host/path`. Scans depth 1 and (under non-repo dirs) depth 2, excluding `_meta`. Non-repos and no-remote repos are silent skips. Exit 1 + stderr message on missing/empty arg or missing dir; exit 0 otherwise. Tasks 3 and 4 consume these exact field names.

- [ ] **Step 1: Write the failing test**

Create `tests/test-checkout-groups.sh`:

```bash
#!/usr/bin/env bash
# Plain-bash test harness for scripts/checkout-groups.sh (deps: bash + git).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/checkout-groups.sh"
pass=0; fail=0

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
G() { git -c user.email=t@t -c user.name=t "$@"; }

WS="$TMP/ws"
mkdir -p "$WS/_meta"
printf '{ "workspace-os": "sidecar", "workspace": "test-ws" }\n' > "$WS/_meta/workspace.json"

# A + B: same project via different URL forms; A on a named branch
mkdir -p "$WS/checkout-a" && G -C "$WS/checkout-a" init -q -b work
G -C "$WS/checkout-a" remote add origin "https://Host.example/Org/Repo.git"
# B: scp-style URL, detached HEAD
mkdir -p "$WS/checkout-b" && G -C "$WS/checkout-b" init -q -b main
G -C "$WS/checkout-b" remote add origin "git@host.example:org/repo.git"
( cd "$WS/checkout-b" && touch f && G add f && G commit -qm c && G checkout -q --detach )
# C: a different project
mkdir -p "$WS/other" && G -C "$WS/other" init -q -b main
G -C "$WS/other" remote add origin "https://host.example/org/elsewhere.git"
# D: repo with no remote; E: not a repo; F: nested one level under a plain dir
mkdir -p "$WS/noremote" && G -C "$WS/noremote" init -q
mkdir -p "$WS/plaindir"
mkdir -p "$WS/nested/checkout-f" && G -C "$WS/nested/checkout-f" init -q -b main
G -C "$WS/nested/checkout-f" remote add origin "https://host.example/org/repo.git"

check() { # check <name> <cond-ok 0|1>
  if [ "$2" = 0 ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}

out="$(bash "$SCRIPT" "$WS")"; ec=$?
check "exits 0 on a valid workspace" $([ "$ec" = 0 ] && echo 0 || echo 1)

line_a="$(printf '%s\n' "$out" | grep 'folder=checkout-a' || true)"
line_b="$(printf '%s\n' "$out" | grep 'folder=checkout-b' || true)"
line_f="$(printf '%s\n' "$out" | grep 'folder=checkout-f' || true)"
key_a="$(printf '%s' "$line_a" | sed 's/.*key=\([^ ]*\).*/\1/')"
key_b="$(printf '%s' "$line_b" | sed 's/.*key=\([^ ]*\).*/\1/')"

check "A normalized (scheme/case/.git stripped)" $([ "$key_a" = "host.example/org/repo" ] && echo 0 || echo 1)
check "A and B share a key (scp form matches)" $([ -n "$key_a" ] && [ "$key_a" = "$key_b" ] && echo 0 || echo 1)
check "project name is key basename" $(printf '%s' "$line_a" | grep -q 'project=repo' && echo 0 || echo 1)
check "branch reported for A" $(printf '%s' "$line_a" | grep -q 'branch=work' && echo 0 || echo 1)
check "detached HEAD -> empty branch" $(printf '%s' "$line_b" | grep -q 'branch=$' && echo 0 || echo 1)
check "different remote gets its own key" $(printf '%s\n' "$out" | grep 'folder=other' | grep -q 'key=host.example/org/elsewhere' && echo 0 || echo 1)
check "nested depth-2 checkout found" $([ -n "$line_f" ] && echo 0 || echo 1)
check "no-remote repo skipped" $(printf '%s\n' "$out" | grep -q 'folder=noremote' && echo 1 || echo 0)
check "non-repo dir skipped" $(printf '%s\n' "$out" | grep -q 'folder=plaindir' && echo 1 || echo 0)
check "_meta never scanned" $(printf '%s\n' "$out" | grep -q 'folder=_meta' && echo 1 || echo 0)

out2="$(bash "$SCRIPT" "$WS/_meta")"
check "accepts the _meta dir and normalizes" $([ "$out2" = "$out" ] && echo 0 || echo 1)

bash "$SCRIPT" "$TMP/definitely-missing" 2>/dev/null; ec=$?
check "missing dir -> exit 1" $([ "$ec" = 1 ] && echo 0 || echo 1)
bash "$SCRIPT" 2>/dev/null; ec=$?
check "missing arg -> exit 1" $([ "$ec" = 1 ] && echo 0 || echo 1)

echo "---"; echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/test-checkout-groups.sh`
Expected: FAILs / errors (script does not exist yet).

- [ ] **Step 3: Implement the script**

Create `scripts/checkout-groups.sh`:

```bash
#!/usr/bin/env bash
# workspace-os checkout grouping — which sibling folders are checkouts of ONE project.
# Usage: checkout-groups.sh <workspace-dir>
#   <workspace-dir> is the workspace root (the dir containing _meta/) or the _meta dir itself
#   (resolve-data-root.sh's workspace_root); a trailing _meta component is normalized away.
# Scans directories at depth 1, and depth 2 under non-repo dirs (mirroring the resolver's
# support for nested repos), excluding _meta/. For each git repo with an `origin` remote,
# prints one line:
#   project=<basename-of-key-path> key=<normalized-url> folder=<basename> branch=<current-or-empty>
# The key is the origin URL lowercased with scheme, credentials, and trailing .git stripped,
# and scp-style git@host:path rewritten to host/path. Non-repos and no-remote repos are
# skipped silently. Fail-loud on a missing argument or directory (a read tool that errors
# should say so). Deps: bash + git.
set -uo pipefail

root="${1:-}"
[ -n "$root" ] || { echo "checkout-groups: usage: checkout-groups.sh <workspace-dir>" >&2; exit 1; }
[ "$(basename "$root")" = "_meta" ] && root="$(dirname "$root")"
[ -d "$root" ] || { echo "checkout-groups: no such directory: $root" >&2; exit 1; }

normalize() {  # <origin-url> -> lowercase host/path key
  local u="$1"
  u="${u%.git}"
  u="${u#ssh://}"; u="${u#git://}"; u="${u#https://}"; u="${u#http://}"
  u="${u#*@}"          # user[:pass]@ credentials
  u="${u/:/\/}"        # scp-style host:path -> host/path
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

scan_repo() {  # <dir> -> 0 if a git repo (emitting a line when it has an origin), 1 otherwise
  local d="$1" url key branch
  [ -d "$d/.git" ] || return 1
  url="$(git -C "$d" remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || return 0
  key="$(normalize "$url")"
  branch="$(git -C "$d" branch --show-current 2>/dev/null || true)"
  printf 'project=%s key=%s folder=%s branch=%s\n' "${key##*/}" "$key" "$(basename "$d")" "$branch"
  return 0
}

for d in "$root"/*/; do
  d="${d%/}"
  [ -d "$d" ] || continue
  [ "$(basename "$d")" = "_meta" ] && continue
  scan_repo "$d" && continue
  for c in "$d"/*/; do
    c="${c%/}"
    [ -d "$c" ] || continue
    scan_repo "$c" || true
  done
done
exit 0
```

Then: `chmod +x scripts/checkout-groups.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-checkout-groups.sh`
Expected: all PASS, `fail=0`, exit 0. If the detached-HEAD check fails on an old git, `branch --show-current` may not exist — the repo's other tests already assume a git recent enough for `-b` on init, so investigate rather than paper over.

- [ ] **Step 5: Register in CI**

In `.github/workflows/ci.yml`, after the line `- run: bash tests/test-playbook-surface.sh` add:

```yaml
      - run: bash tests/test-checkout-groups.sh
```

- [ ] **Step 6: Commit**

```bash
git add scripts/checkout-groups.sh tests/test-checkout-groups.sh .github/workflows/ci.yml
git commit -m "feat: checkout-groups.sh — deterministic checkout grouping by origin URL"
```

---

### Task 3: Schema section + `/project-log propagated` + cadence line

**Files:**
- Modify: `conventions/project-tracking.md` (new section before `## Concurrency`)
- Modify: `skills/project-log/SKILL.md` (new mode after `done`, before Quick-add; update `argument-hint`)
- Modify: `hooks/capture-cadence.sh` (one cadence line)
- Test: `tests/test-capture-cadence.sh` (one assertion)

**Interfaces:**
- Consumes: `checkout-groups.sh` output fields from Task 2 (`project=`, `key=`, `folder=`, `branch=`).
- Produces: the schema section other prose references as `conventions/project-tracking.md` § "Propagation across checkouts"; the `/project-log propagated` mode name Task 5's docs mention.

- [ ] **Step 1: Add the conventions section**

In `conventions/project-tracking.md`, insert before `## Concurrency`:

```markdown
## Propagation across checkouts (sidecar workspaces)

In a marked workspace, several checkout folders may be checkouts of ONE project — grouped
automatically by normalized `origin` URL (`scripts/checkout-groups.sh`; zero config), keyed
by folder basename like the sidecar data roots (`conventions/data-root.md`). Two optional,
**append-only** lines on **action** records (open or resolved) carry propagation state;
both are meaningless in in-repo mode, where checkouts share tracking files through git:

- `- Propagation: all | <folder>, <folder>` — written at most once; declares which of the
  project's checkouts need this change. `all` is dynamic: every checkout in the project's
  group **at read time**. Its presence is what makes a record matrix-relevant.
- `- Propagated-to: <folder> YYYY-MM-DD [sha-or-PR#]` — one line per landing, appended in
  landing order (the `Superseded-by:` pattern: append, never edit).

**Read rule:** covered = the record's home checkout (the folder whose data root holds the
record) once the record is done, plus every `Propagated-to:` folder; pending = target set
minus covered. A `Propagated-to:` folder outside the current group reads as unknown —
lenient, never an error (folders get renamed or removed). Written by
`/project-log propagated`; rendered by `/project-status matrix`. The body line-ceiling and
the memory/tracking boundary apply unchanged.
```

- [ ] **Step 2: Add the `/project-log` mode**

In `skills/project-log/SKILL.md`, change the frontmatter `argument-hint` to:

```
argument-hint: "[action|decision|model-decision|done|propagated] <args>   (e.g. action data/pipeline \"fix the X gap\")"
```

Insert after the `### done` mode section, before `### Quick-add`:

```markdown
### `propagated <A-id> <folder> [sha]`
Record that a change landed in another checkout of this project
(`conventions/project-tracking.md` § "Propagation across checkouts"). Sidecar workspaces
only — `mode=in-repo` → say propagation applies to marked workspaces only, and stop.

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/checkout-groups.sh" "<workspace_root>"` and
   group its lines by `key=`.
2. Locate `<A-id>` in `action-items.md`, then `resolved.md`, under
   `<workspace_root>/<f>/project-tracking/` for EVERY folder `<f>` in the grouped projects
   — the record may live in a sibling checkout's root. Not found → list the locations
   searched and stop (a write tool should not guess).
3. `<folder>` must be in the record's project group; otherwise list the valid folders and
   stop.
4. If the record has no `- Propagation:` line, propose one (default `all`) and append it on
   confirmation before anything else.
5. Append `- Propagated-to: <folder> <today YYYY-MM-DD> [sha]` to the record's body —
   unless a `Propagated-to:` line for that folder already exists (then say so and write
   nothing). Sidecar auto-commit applies (Step 0).
```

- [ ] **Step 3: Add the cadence line**

In `hooks/capture-cadence.sh`, in the heredoc list after the `- a repeated multi-step procedure -> /playbook` line, add:

```
- a fix landed in another checkout of this project -> /project-log propagated
```

- [ ] **Step 4: Extend the cadence test and run it**

In `tests/test-capture-cadence.sh`, next to the existing `contains "cadence names /playbook" …` assertion add:

```bash
contains "cadence names propagated" "$out" "/project-log propagated"
```

Run: `bash tests/test-capture-cadence.sh`
Expected: all PASS including the new line.

- [ ] **Step 5: Commit**

```bash
git add conventions/project-tracking.md skills/project-log/SKILL.md hooks/capture-cadence.sh tests/test-capture-cadence.sh
git commit -m "feat: propagation schema + /project-log propagated mode + cadence line"
```

---

### Task 4: `/project-status matrix` mode

**Files:**
- Modify: `skills/project-status/SKILL.md` (frontmatter `description` + `argument-hint`; mode parsing in Step 1; new mode section after Brief mode)

**Interfaces:**
- Consumes: `checkout-groups.sh` fields (Task 2); the schema read rule (Task 3's conventions section).

- [ ] **Step 1: Update frontmatter**

`description`: append before the final "Writes nothing." sentence:
`Also a matrix mode showing, per project in a marked workspace, which checkouts each change has landed in and which still need it.`
`argument-hint`: change to `"[workstream | high|mid|low] | brief [workstream | high|mid|low] | matrix"`.

- [ ] **Step 2: Extend Step 1 (argument parsing)**

In the skill's `## Steps` item 1, change the first sentence to:
`A leading `brief` selects brief mode; a leading `matrix` selects matrix mode (no filter tokens — matrix is always whole-workspace).`

- [ ] **Step 3: Add the mode section**

Append after the Brief mode section:

```markdown
## Matrix mode (`/project-status matrix`)

The cross-checkout propagation view (`conventions/project-tracking.md` § "Propagation
across checkouts"). Sidecar/workspace-meta modes only — in `mode=in-repo`, print one line
("matrix applies to marked workspaces only") and stop.

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/checkout-groups.sh" "<workspace_root>"` and
   group its lines by `key=`. Drop groups with fewer than two folders. None left → one-line
   empty state ("no multi-checkout projects in this workspace") and stop.
2. For every folder in each remaining group, read
   `<workspace_root>/<folder>/project-tracking/action-items.md` and `resolved.md`
   (leniently, as ever) and select records carrying a `- Propagation:` line.
3. Render one table per project:

   ```
   PROPAGATION MATRIX: <project> — <N> checkouts
   Record                       | <folder> (<branch>) | <folder> (<branch>) | …
   A-… (home: <folder>)         | landed 2026-08-21   | pending             | n/a
   ```

   Cells, per the conventions read rule: `landed <date>` — the home checkout once the
   record is done (use its `Completed:` date) or a `Propagated-to:` line's date;
   `pending` — in the target set, not landed; `n/a` — not in the target set. Elide
   resolved records older than ~60 days that have no pending cells, reporting the elided
   count (the recent-window rule).
4. Close each table with per-checkout summaries — "`<folder>` still needs: <IDs>" (omit
   fully-covered checkouts) — and, when any `Propagated-to:` line names a folder outside
   the current group, one line listing those unknown folders (render, never error).

Read-only like every other mode; records with no `Propagation:` line never appear here.
```

- [ ] **Step 4: Commit**

```bash
git add skills/project-status/SKILL.md
git commit -m "feat: /project-status matrix — cross-checkout propagation view"
```

---

### Task 5: Packaging — version, docs, spec touch-up, full verification

**Files:**
- Modify: `.claude-plugin/plugin.json` (version)
- Modify: `README.md` (feature-map rows)
- Modify: `GUIDE.md` (daily-workflow mention)
- Modify: `docs/specs/2026-08-28-one-project-many-checkouts-design.md` (two wording touch-ups)

**Interfaces:**
- Consumes: mode names from Tasks 3-4 exactly as written (`/project-log propagated`, `/project-status matrix`).

- [ ] **Step 1: Bump the version**

In `.claude-plugin/plugin.json`: `"version": "0.24.1"` → `"version": "0.25.0"`.

- [ ] **Step 2: README + GUIDE mentions**

README feature map: extend the `/project-log` row's description with `; propagated records a landing in another checkout` and the `/project-status` row's with `; matrix shows per-checkout propagation in a marked workspace`. GUIDE `## Daily workflow`: add one sentence at the end of the section:
`In a marked workspace with several checkouts of one repo, log where a fix has landed with /project-log propagated and see what each checkout still needs with /project-status matrix.`

- [ ] **Step 3: Spec touch-ups (implementation refinements)**

In `docs/specs/2026-08-28-one-project-many-checkouts-design.md` §2: change "lowercase the host" to "lowercase the key", and "For each directory directly under `<workspace_root>`" to "For each directory at depth 1 — and depth 2 under non-repo directories (the resolver supports nested repos) — under the workspace root". Add at the end of §2: "Accepts the workspace root or the `_meta` dir itself (resolve-data-root's `workspace_root`); a trailing `_meta` component is normalized away."

- [ ] **Step 4: Full verification**

```bash
python3 scripts/validate-plugin.py
for t in tests/test-*.sh; do bash "$t" || echo "SUITE FAIL: $t"; done
```
Expected: validator clean (the doc-freshness gate passes because both modes are mentioned in README/GUIDE); every test file passes; no `SUITE FAIL` lines.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json README.md GUIDE.md docs/specs/2026-08-28-one-project-many-checkouts-design.md
git commit -m "chore: v0.25.0 — docs + spec touch-ups for checkout propagation"
```

---

### Task 6: Ship — PR, CI, merge, close-out

**Files:**
- Modify: `docs/project-tracking/action-items.md` / `resolved.md` (done move)
- Modify: `docs/project-tracking/decisions-log.md` (append the Closes line)

**Interfaces:**
- Consumes: `A-20260828-checkout-propagation`, `D-20260828-propagation-intent-fact-lines` (Task 1).

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin feat/checkout-propagation
gh pr create --title "One project, many checkouts: propagation schema + matrix view (v0.25.0)" --body "Ships the remaining halves of the one-project-many-checkouts idea: Propagation:/Propagated-to: schema lines, scripts/checkout-groups.sh, /project-status matrix, /project-log propagated. Spec: docs/specs/2026-08-28-one-project-many-checkouts-design.md. Decision: D-20260828-propagation-intent-fact-lines."
```
(Repo PR-body trailer conventions apply.)

- [ ] **Step 2: Wait for CI in the foreground — never a background watcher**

```bash
gh pr checks --watch
```
CI here runs ~10s; foreground only (standing rule). Expected: all checks pass. If not: fix, push, re-check.

- [ ] **Step 3: Merge, pull, update the plugin**

```bash
gh pr merge --squash --delete-branch
git checkout main && git pull
claude plugin update workspace-os@workspace-os
```

- [ ] **Step 4: Tracking close-out**

Following `/project-log done` + the idea-ship ritual (idea already left `ideas.md` in Task 1):
- Move `A-20260828-checkout-propagation` from `action-items.md` to `resolved.md`, appending `- Completed: 2026-08-28` and `- Commit: <squash sha> (PR #<N>, v0.25.0)`; restore the `_No open items yet._` placeholder if the file is left empty; add one body line: `Closes the one-project-many-checkouts idea (both remaining halves).`
- Append below the `D-20260828-propagation-intent-fact-lines` record: `Closes one-project-many-checkouts (idea COMPLETE: link-resolution half v0.22.1, propagation schema + matrix v0.25.0).`

- [ ] **Step 5: Lint + commit close-out to main**

```bash
python3 scripts/memory_graph.py --check
git add docs/project-tracking/ && git commit -m "chore(tracking): close A-20260828-checkout-propagation (v0.25.0)" && git push origin main
```
