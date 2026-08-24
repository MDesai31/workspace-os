# Memory Provenance Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two optional memory-fact frontmatter fields — `verified-against` (claim-freshness provenance) and `applies-to` (branch/repo scoping) — and teach `memory_graph.py` to report an advisory UNVERIFIED-SINCE citation bucket.

**Architecture:** Both fields are optional and additive; a fact carrying neither behaves byte-identically to today. `verified-against` records the sha of the **source repo being cited**, and `--check-citations` gains a fourth, advisory bucket computed by batching one `git diff --name-only <sha>..HEAD` per distinct sha and intersecting with each fact's resolved citation paths. `applies-to` is parsed and surfaced in reports but gates nothing.

**Tech Stack:** Python 3 stdlib only (no third-party imports — `memory_graph.py` is vendored into user bases and must stay dependency-free), plain-bash test harness (`bash` + `python3` only), git CLI invoked via `subprocess`.

**Spec:** `docs/specs/2026-08-19-memory-provenance-fields-design.md`

## Global Constraints

- **Stdlib only.** `scripts/memory_graph.py` is vendored into user memory bases. Never add a third-party import. `subprocess` is stdlib and is the only new import permitted by this plan.
- **UNVERIFIED-SINCE is advisory and MUST NOT change the exit code.** `--check-citations` returns `1 if stale else 0`, unchanged. A single upstream commit must never turn a base's CI red.
- **Absent fields = today's behaviour, byte-identical.** Every existing fixture must keep passing untouched.
- **Two schema statements must stay consistent:** `conventions/memory.md` § Fact schema (plugin-internal) and `templates/memory/README.md` (vendor-neutral operator's manual, stamped into user bases). Both change in the same task.
- **The sha is the source repo's**, never the memory repo's. In sidecar mode these are different git repos.
- **Field formats, verbatim:**
  - `verified-against: <sha> <YYYY-MM-DD>` — sha is 7–40 hex chars, one space, ISO date.
  - `applies-to: branch:<name>` or `applies-to: repo:<name>` — explicit prefix required; absent means whole repo, all branches.
- Tests are bash cases appended to `tests/test-memory-graph.sh`, using its existing `check <name> <got_ec> <want_ec> <got_out> <want_substr>` helper.

## Two constraints discovered while reading the code

Both are load-bearing; do not "simplify" them away.

1. **`git diff --name-only` prints paths relative to the REPO ROOT, not to `--src-root`.** `--src-root` may be a subdirectory of the repo. Resolve the repo root once via `git -C <src_root> rev-parse --show-toplevel` and convert git's output to absolute paths before matching them against the resolved citation paths. Comparing raw git output to src-root-relative paths silently produces zero matches, which looks exactly like "nothing changed."

2. **The freshness test needs a git repo built at test time.** `tests/fixtures/memory-citations/` is a plain directory, and a nested `.git` cannot be committed inside this repo's own history. Build the repo in `mktemp -d` inside the test (init, commit, capture sha, modify, commit), following the pattern already used by `tests/test-stamp-portable-layer.sh`. As a bonus, the existing non-git `memory-citations` fixture is exactly the "src-root is not a git repo" degradation case — reuse it rather than building another.

---

### Task 1: State the schema in both places

**Files:**
- Modify: `conventions/memory.md` (§ Fact schema, around lines 63–95)
- Modify: `templates/memory/README.md` (its fact-schema section)
- Test: `tests/test-memory-graph.sh` (consistency case)

**Interfaces:**
- Consumes: nothing.
- Produces: the field spellings `verified-against` and `applies-to` that every later task parses. No code.

- [ ] **Step 1: Write the failing consistency test**

Append to `tests/test-memory-graph.sh`, just before the final summary block:

```bash
# --- provenance fields: the two schema statements must agree ---
CONV="$HERE/../conventions/memory.md"
MANUAL="$HERE/../templates/memory/README.md"
for field in "verified-against" "applies-to"; do
  c=$(grep -c -- "$field" "$CONV"); m=$(grep -c -- "$field" "$MANUAL")
  if [ "$c" -gt 0 ] && [ "$m" -gt 0 ]; then
    echo "PASS: $field documented in both schema statements"; pass=$((pass+1))
  else
    echo "FAIL: $field missing (conventions:$c manual:$m)"; fail=$((fail+1))
  fi
done
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/test-memory-graph.sh 2>&1 | grep -E "verified-against|applies-to"`
Expected: two FAIL lines, `conventions:0 manual:0`.

- [ ] **Step 3: Add the fields to `conventions/memory.md`**

Replace the fenced schema block in § Fact schema with:

```
---
name: <kebab-slug>            # matches the filename stem
description: <one-line summary used for relevance at recall>
type: domain | convention | reference
verified-against: <sha> <YYYY-MM-DD>     # optional
applies-to: branch:<name> | repo:<name>  # optional
---
```

Then add this prose immediately after the existing `Types:` list:

```markdown
Two optional provenance fields, both absent by default:

- `verified-against: <sha> <YYYY-MM-DD>` — the commit this fact's claims were last confirmed
  against, plus the date. The sha is the **source repo being cited**, NOT the memory repo — in
  sidecar mode those are different git repos. `/memory-lint` uses it to report UNVERIFIED-SINCE:
  the citation still resolves, but the cited code has moved since anyone confirmed the claim.
  Advisory only; it never fails the lint.
- `applies-to: branch:<name>` or `applies-to: repo:<name>` — scopes a fact that is true only on one
  branch or in one repo. The `branch:`/`repo:` prefix is required (a bare `main` is ambiguous
  between a branch and a repo name). **Absent means the fact applies to the whole repo, all
  branches**, which is the normal case. Prefer naming a split inside one shared fact over two
  divergent copies; reach for this field only for the residue.
```

- [ ] **Step 4: Mirror it into `templates/memory/README.md`**

Add the same two bullets to the operator's manual's schema section, rewritten so they stand alone
without the plugin (the manual is read by non-Claude agents with no access to `conventions/`):

```markdown
Optional provenance fields:

- `verified-against: <sha> <YYYY-MM-DD>` — the commit of the **code repository this fact cites**
  (not this memory repo) at which the fact was last confirmed, plus the date. Update it whenever
  you re-read the cited code and confirm the fact still holds. `memory_graph.py --check-citations`
  reports facts whose cited files changed after that commit as UNVERIFIED-SINCE. Advisory: it never
  fails the check.
- `applies-to: branch:<name>` or `applies-to: repo:<name>` — use only when a fact is true on one
  branch or in one repo but not others. The prefix is required. Omit the field entirely for the
  normal case (true everywhere in this repo).
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test-memory-graph.sh 2>&1 | tail -3`
Expected: two new PASS lines; total count up by 2; `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add conventions/memory.md templates/memory/README.md tests/test-memory-graph.sh
git commit -m "docs(memory): document verified-against + applies-to in both schema statements"
```

---

### Task 2: Parse and report `applies-to`

**Files:**
- Modify: `scripts/memory_graph.py` (regex constants near line 72; `scan()` near line 126; `print_report()` near line 259)
- Test: `tests/test-memory-graph.sh`, new fixture `tests/fixtures/memory-scoped/`

**Interfaces:**
- Consumes: the field spelling from Task 1.
- Produces: `_frontmatter(text) -> str`, used by Task 3. `data["applies_to"]: dict[str, str]` mapping norm-stem → the raw scope value (e.g. `"branch:develop"`).

- [ ] **Step 1: Build the fixture**

```bash
mkdir -p tests/fixtures/memory-scoped/docs/memory
cat > tests/fixtures/memory-scoped/docs/memory/fact-scoped.md <<'EOF'
---
name: fact-scoped
description: a fact true only on the develop branch
type: domain
applies-to: branch:develop
---

Only the develop branch carries the UAT checkout roles.
EOF
cat > tests/fixtures/memory-scoped/docs/memory/fact-global.md <<'EOF'
---
name: fact-global
description: an ordinary unscoped fact
type: domain
---

True everywhere in this repo.
EOF
cat > tests/fixtures/memory-scoped/docs/memory/MEMORY.md <<'EOF'
# Memory Index

## domain
- [fact-scoped](fact-scoped.md) - develop-only checkout roles
- [fact-global](fact-global.md) - ordinary fact
EOF
```

- [ ] **Step 2: Write the failing test**

Append to `tests/test-memory-graph.sh`:

```bash
# --- applies-to: parsed and surfaced, never a gate ---
SCOPED="$HERE/fixtures/memory-scoped"
out="$(python3 "$SCRIPT" --root "$SCOPED/docs/memory" --tracking-root "$SCOPED/none" 2>&1)"; ec=$?
check "applies-to is reported" "$ec" "0" "$out" "branch:develop"
check "applies-to names the scoped fact" "$ec" "0" "$out" "fact-scoped"
out="$(python3 "$SCRIPT" --check --root "$SCOPED/docs/memory" --tracking-root "$SCOPED/none" 2>&1)"; ec=$?
check "applies-to does not fail --check" "$ec" "0" "$out" ""
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/test-memory-graph.sh 2>&1 | grep applies-to`
Expected: `FAIL: applies-to is reported` (the string `branch:develop` appears nowhere in output).

- [ ] **Step 4: Add the frontmatter helper and the regex**

Next to the existing `FRONTMATTER_NAME` / `FRONTMATTER_DESC` constants (~line 72):

```python
FRONTMATTER_APPLIES = re.compile(r"^applies-to:\s*(branch|repo):(\S.*?)\s*$", re.MULTILINE)
```

And add this helper beside `norm()` / `strip_code()` (~line 87):

```python
def _frontmatter(text: str) -> str:
    """Return the leading `---` frontmatter block, or "" when the file has none.

    Parsed as a block rather than with a fixed character window: a long description can push
    later fields past any fixed slice, and these fields sit below `type:`.
    """
    if not text.startswith("---"):
        return ""
    end = text.find("\n---", 3)
    return text[:end] if end != -1 else ""
```

- [ ] **Step 5: Collect it in `scan()`**

In `scan()`, alongside the existing `descriptions` dict, add `applies_to = {}`. Inside the per-file
loop, after the existing frontmatter handling:

```python
        fm = _frontmatter(text)
        m = FRONTMATTER_APPLIES.search(fm)
        if m:
            applies_to[norm(f.stem)] = f"{m.group(1)}:{m.group(2)}"
```

Add `applies_to` to the returned dict under the key `"applies_to"`.

- [ ] **Step 6: Surface it in `print_report()`**

At the end of `print_report()`, before its final line:

```python
    scoped = data.get("applies_to", {})
    if scoped:
        print(f"SCOPED FACTS ({len(scoped)}):")
        for stem, scope in sorted(scoped.items()):
            print(f"  {stem}: {scope}")
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bash tests/test-memory-graph.sh 2>&1 | tail -3`
Expected: 3 new PASS lines, `0 failed`.

- [ ] **Step 8: Commit**

```bash
git add scripts/memory_graph.py tests/test-memory-graph.sh tests/fixtures/memory-scoped
git commit -m "feat(memory): parse and report applies-to scope on facts"
```

---

### Task 3: `verified-against` → the UNVERIFIED-SINCE bucket

**Files:**
- Modify: `scripts/memory_graph.py` (`check_citations()` line 424, `print_citations()` line 494, `main()` citation branch)
- Test: `tests/test-memory-graph.sh`

**Interfaces:**
- Consumes: `_frontmatter()` from Task 2.
- Produces: `check_citations()` now returns a **5-tuple** `(stale, unresolvable, unanchored, ambiguous, unverified)`. Task 4 extends the same function. Every caller must be updated in this task — there is exactly one, in `main()`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-memory-graph.sh`. This builds a real git repo because the static fixture cannot carry one:

```bash
# --- verified-against: UNVERIFIED-SINCE when cited code moved after the recorded sha ---
GT="$(mktemp -d)"; mkdir -p "$GT/docs/memory" "$GT/src"
cat > "$GT/src/opt.py" <<'EOF'
def prune_prepare_inputs(rows):
    return rows
EOF
git -C "$GT" init -q
git -C "$GT" config user.email t@t.t; git -C "$GT" config user.name t
git -C "$GT" add -A >/dev/null; git -C "$GT" commit -qm one
OLD_SHA="$(git -C "$GT" rev-parse --short HEAD)"
cat > "$GT/src/opt.py" <<'EOF'
def prune_prepare_inputs(rows, limit):
    return rows[:limit]
EOF
git -C "$GT" add -A >/dev/null; git -C "$GT" commit -qm two
NEW_SHA="$(git -C "$GT" rev-parse --short HEAD)"

write_fact() {  # $1=sha
  cat > "$GT/docs/memory/fact-verified.md" <<EOF
---
name: fact-verified
description: cites a symbol that still resolves
type: domain
verified-against: $1 2026-08-19
---

Entry point: \`src/opt.py::prune_prepare_inputs\`.
EOF
  printf '# Memory Index\n\n## domain\n- [fact-verified](fact-verified.md) - x\n' \
    > "$GT/docs/memory/MEMORY.md"
}

write_fact "$OLD_SHA"
out="$(python3 "$SCRIPT" --check-citations --root "$GT/docs/memory" --src-root "$GT" 2>&1)"; ec=$?
check "stale sha reports UNVERIFIED-SINCE" "$ec" "0" "$out" "UNVERIFIED-SINCE"
check "unverified fact is named" "$ec" "0" "$out" "fact-verified"
check "UNVERIFIED-SINCE does not fail the lint" "$ec" "0" "$out" "citations: clean"

write_fact "$NEW_SHA"
out="$(python3 "$SCRIPT" --check-citations --root "$GT/docs/memory" --src-root "$GT" 2>&1)"; ec=$?
case "$out" in *UNVERIFIED-SINCE*) echo "FAIL: current sha wrongly flagged"; fail=$((fail+1));;
  *) echo "PASS: current sha not flagged"; pass=$((pass+1));; esac
rm -rf "$GT"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/test-memory-graph.sh 2>&1 | grep -i unverified`
Expected: FAIL lines — the string `UNVERIFIED-SINCE` is not in the output yet.

- [ ] **Step 3: Add the import, the regex, and the git helper**

Add `import subprocess` to the imports at the top of `scripts/memory_graph.py`. Beside the other
frontmatter constants:

```python
FRONTMATTER_VERIFIED = re.compile(
    r"^verified-against:\s*([0-9a-fA-F]{7,40})\s+(\d{4}-\d{2}-\d{2})\s*$", re.MULTILINE)
```

Add this helper just above `check_citations()`:

```python
def _git_repo_root(src_root):
    """Absolute repo root for src_root, or None when it is not a git worktree."""
    try:
        r = subprocess.run(["git", "-C", str(src_root), "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    return Path(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip() else None


def _changed_since(src_root, repo_root, sha, paths):
    """Absolute paths among `paths` that changed between sha and HEAD.

    Returns None when the question is unanswerable (unknown sha, git failure). `git diff
    --name-only` prints REPO-ROOT-relative paths, so results are rejoined onto repo_root before
    being returned -- src_root may be a subdirectory and raw output would never match.
    """
    try:
        r = subprocess.run(
            ["git", "-C", str(src_root), "diff", "--name-only", f"{sha}..HEAD", "--", *paths],
            capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return {(repo_root / line.strip()).resolve()
            for line in r.stdout.splitlines() if line.strip()}
```

- [ ] **Step 4: Collect per-fact citation paths and shas in `check_citations()`**

Change the signature's docstring to name the fifth bucket, and initialise alongside the others:

```python
    stale, unresolvable, unanchored, ambiguous, unverified = [], [], [], [], []
    cited_paths = defaultdict(set)   # fact filename -> {absolute resolved Path}
    fact_sha = {}                    # fact filename -> sha
```

Immediately after `lines = f.read_text(...)`, record the sha:

```python
        vm = FRONTMATTER_VERIFIED.search(_frontmatter("\n".join(lines)))
        if vm:
            fact_sha[fact] = vm.group(1)
```

In **both** citation loops, wherever `_resolve_src` returns `("ok", val)` and the citation is
accepted, also record the path. In the anchor loop that is the `elif not re.search(...)` branch plus
its passing case — simplest is to add one line right after the `status`/`val` unpacking in each
loop:

```python
                if status == "ok":
                    cited_paths[fact].add(val.resolve())
```

- [ ] **Step 5: Compute the bucket, batched by sha**

Immediately before `return` in `check_citations()`:

```python
    if fact_sha:
        repo_root = _git_repo_root(src_root)
        if repo_root is None:
            for fact in sorted(fact_sha):
                unverified.append((fact, "freshness unverifiable (src-root is not a git repo)"))
        else:
            by_sha = defaultdict(list)
            for fact, sha in fact_sha.items():
                by_sha[sha].append(fact)
            for sha, facts in sorted(by_sha.items()):
                paths = sorted({str(p) for fct in facts for p in cited_paths.get(fct, ())})
                if not paths:
                    continue
                changed = _changed_since(src_root, repo_root, sha, paths)
                if changed is None:
                    for fct in sorted(facts):
                        unverified.append((fct, f"freshness unverifiable (sha {sha} not in src-root repo)"))
                    continue
                for fct in sorted(facts):
                    hits = sorted(p.name for p in cited_paths.get(fct, ()) if p.resolve() in changed)
                    if hits:
                        unverified.append(
                            (fct, f"verified at {sha}; changed since: {', '.join(hits)}"))
    return stale, unresolvable, unanchored, ambiguous, unverified
```

- [ ] **Step 6: Print it and update the one caller**

In `print_citations()`, take `unverified` as a parameter, add it to the counts line
(`unverified: {len(unverified)}`) and to the label loop as `("UNVERIFIED-SINCE", unverified)`.
Leave the closing `if not stale:` line untouched — UNVERIFIED-SINCE must not suppress
`citations: clean`.

In `main()`, update the unpack and the call:

```python
        stale, unresolvable, unanchored, ambiguous, unverified = check_citations(root, src_root)
        print_citations(stale, unresolvable, unanchored, ambiguous, unverified, root, src_root)
        return 1 if stale else 0
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bash tests/test-memory-graph.sh 2>&1 | tail -3`
Expected: 4 new PASS lines, `0 failed`. Confirm the pre-existing citation cases (`stale: 2`,
`fact-good-inblock` not flagged) still pass.

- [ ] **Step 8: Commit**

```bash
git add scripts/memory_graph.py tests/test-memory-graph.sh
git commit -m "feat(memory): UNVERIFIED-SINCE bucket from verified-against provenance"
```

---

### Task 4: Degradation paths

**Files:**
- Modify: `scripts/memory_graph.py` (`check_citations()` only)
- Test: `tests/test-memory-graph.sh`

**Interfaces:**
- Consumes: `check_citations()`'s 5-tuple from Task 3.
- Produces: no new symbols. Guarantees exit 0 on every unverifiable path.

- [ ] **Step 1: Write the failing tests**

The non-git case reuses the existing plain-directory fixture. Append:

```bash
# --- verified-against degradation: never an error, always exit 0 ---
NG="$(mktemp -d)"; mkdir -p "$NG/docs/memory" "$NG/src"
printf 'def f():\n    return 1\n' > "$NG/src/opt.py"
mkfact() {  # $1=verified-against line body
  cat > "$NG/docs/memory/fact-x.md" <<EOF
---
name: fact-x
description: degradation case
type: domain
verified-against: $1
---

Entry: \`src/opt.py::f\`.
EOF
  printf '# Memory Index\n\n## domain\n- [fact-x](fact-x.md) - x\n' > "$NG/docs/memory/MEMORY.md"
}

mkfact "abc1234 2026-08-19"
out="$(python3 "$SCRIPT" --check-citations --root "$NG/docs/memory" --src-root "$NG" 2>&1)"; ec=$?
check "non-git src-root degrades, exit 0" "$ec" "0" "$out" "not a git repo"

git -C "$NG" init -q; git -C "$NG" config user.email t@t.t; git -C "$NG" config user.name t
git -C "$NG" add -A >/dev/null; git -C "$NG" commit -qm one
mkfact "deadbee 2026-08-19"
git -C "$NG" add -A >/dev/null; git -C "$NG" commit -qm two
out="$(python3 "$SCRIPT" --check-citations --root "$NG/docs/memory" --src-root "$NG" 2>&1)"; ec=$?
check "unknown sha degrades, exit 0" "$ec" "0" "$out" "not in src-root repo"

mkfact "not-a-sha whenever"
git -C "$NG" add -A >/dev/null; git -C "$NG" commit -qm three
out="$(python3 "$SCRIPT" --check-citations --root "$NG/docs/memory" --src-root "$NG" 2>&1)"; ec=$?
check "malformed field ignored, exit 0" "$ec" "0" "$out" "citations: clean"
case "$out" in *UNVERIFIED-SINCE*) echo "FAIL: malformed field produced a finding"; fail=$((fail+1));;
  *) echo "PASS: malformed field silently ignored"; pass=$((pass+1));; esac
rm -rf "$NG"
```

- [ ] **Step 2: Run to verify which fail**

Run: `bash tests/test-memory-graph.sh 2>&1 | grep -E "degrades|malformed"`
Expected: the non-git and unknown-sha cases already PASS (Task 3 handled them). The malformed cases
PASS too, because `FRONTMATTER_VERIFIED` will not match `not-a-sha whenever`, so the field is
skipped. **If all four already pass, that is the correct outcome** — record it and move to Step 4;
Task 3's implementation covered these paths by construction. Do not manufacture a change to make a
test fail.

- [ ] **Step 3: Fix only what actually failed**

If any case failed, the likely cause is `subprocess` raising on a system without git rather than
returning non-zero. Confirm both helpers catch `OSError` and `subprocess.SubprocessError` and
return `None`, and that `_git_repo_root` treats empty stdout as `None`.

- [ ] **Step 4: Verify the full suite**

Run: `bash tests/test-memory-graph.sh 2>&1 | tail -3`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add tests/test-memory-graph.sh scripts/memory_graph.py
git commit -m "test(memory): pin verified-against degradation paths to exit 0"
```

---

### Task 5: Write path and lint documentation

**Files:**
- Modify: `skills/ingest/SKILL.md`
- Modify: `skills/memory-lint/SKILL.md`

**Interfaces:**
- Consumes: field spellings (Task 1), bucket name (Task 3).
- Produces: no code.

- [ ] **Step 1: Add the stamping rule to `/ingest`**

In the step where the fact file's frontmatter is composed, add:

```markdown
**Stamp `verified-against` when the fact cites code.** If the fact body carries a `path:NNN` or
`` `path::symbol` `` citation AND the source tree is a git repo, add
`verified-against: <short-sha> <today>` to the frontmatter, where the sha comes from
`git -C <src-root> rev-parse --short HEAD` — the **source** repo being cited, not the memory repo
(in sidecar mode they differ). Include it in the batch proposal like any other field. Omit the
field entirely when the fact cites no code or the source tree is not a git repo; never invent a
sha. Never auto-stamp `applies-to` — it is authored deliberately or not at all.
```

- [ ] **Step 2: Document the bucket in `/memory-lint`**

Where the citation pass's buckets are described, add:

```markdown
- **UNVERIFIED-SINCE** (advisory) — the fact carries `verified-against: <sha> <date>`, its citation
  still resolves, but the cited file changed after that sha. Nobody has confirmed the claim since
  the code moved. Re-read the cited code; if the fact still holds, update the sha and date. This
  never fails the lint, and facts without the field are never reported.
```

- [ ] **Step 3: Verify the plugin still validates**

Run: `python scripts/validate-plugin.py`
Expected: `Plugin validation passed (13 skills checked).`

- [ ] **Step 4: Commit**

```bash
git add skills/ingest/SKILL.md skills/memory-lint/SKILL.md
git commit -m "docs(skills): /ingest stamps verified-against; /memory-lint documents the bucket"
```

---

### Task 6: Ship shape and close-out

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `docs/project-tracking/decisions-log.md`, `resolved.md`, `ideas.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a releasable v0.21.0.

- [ ] **Step 1: Bump the version**

`.claude-plugin/plugin.json`: `"version": "0.20.0"` → `"0.21.0"`.

- [ ] **Step 2: Full verification before any tracking claim**

Run all four; every one must be green before writing a resolved record:

```bash
python scripts/validate-plugin.py
python scripts/memory_graph.py --check
python scripts/memory_graph.py --tracking-root docs/project-tracking --check-tracking
for t in tests/test-*.sh; do printf '%-40s ' "$(basename $t)"; bash "$t" 2>&1 | tail -1; done
```

Expected: validation passed; graph clean; tracking 0 violations; every harness `0 failed`.

- [ ] **Step 3: Log the decision**

Append `D-20260819-memory-provenance-fields` to `decisions-log.md` using the template in
`conventions/project-tracking.md`. Its Rationale must record **why the `volatility` enum was
rejected** (hand-maintained metadata nothing validates, the same failure mode as the stale
`Priority:` lines cleaned up in PR #25) and **why absence of `verified-against` already carries the
"stable" signal**. Consequences: `--check-citations` now shells out to git, so it must degrade on
non-git source trees.

- [ ] **Step 4: Log the resolved action**

Append `A-20260819-memory-provenance-fields` to `resolved.md` with `Completed:`, the commit/PR ref,
and a body naming both fields, the advisory bucket, and the test delta.

- [ ] **Step 5: Graduate both ideas out of `ideas.md`**

Per `conventions/project-tracking.md` § Lifecycle (the completion exit added in PR #26), for
`memory-volatility-field` and `memory-applies-to-field`: append a `Closes <idea>` line to
`D-20260819-memory-provenance-fields`, confirm the resolved record names both ideas, delete both
records from `ideas.md`, and repoint inbound `[[wikilinks]]` from surviving ideas to
`<name> (shipped)` prose. Verify with:

```bash
grep -c '^### ' docs/project-tracking/ideas.md   # expect 16 here; 17 after Step 6 adds one
grep -o '\[\[memory-volatility-field\]\]\|\[\[memory-applies-to-field\]\]' docs/project-tracking/*.md | wc -l   # expect 0
```

- [ ] **Step 6: Log the deferred follow-up as a new idea**

Spec §5 defers the re-stamp flow. Capture it rather than losing it — append to `ideas.md` using the
idea template from `conventions/project-tracking.md`:

```markdown
### memory-restamp-flow — /memory-lint offers to re-stamp a re-verified fact  (spec deferral 2026-08-19)
- Workstream: memory
- Priority: mid
- Intended start: after UNVERIFIED-SINCE has produced findings on a real base
- Why/context: UNVERIFIED-SINCE tells you a fact's cited code moved after its `verified-against`
  sha, but the fix is manual: re-read the code, decide the claim still holds, hand-edit the sha and
  date. That last step is mechanical and easy to skip, and a skipped re-stamp leaves the fact
  reported forever, which trains people to ignore the bucket. A confirm-gated re-stamp
  (`/memory-lint` proposes `sha -> HEAD, date -> today` per confirmed fact) closes the loop. Held
  back from the v0.21.0 slice deliberately: build the signal first, then automate responding to it
  once we know how often it actually fires.
- To start, future-us needs: a decision on whether re-stamping is per-fact confirm or a batch, and
  whether `/memory-lint` (read-only today for the citation pass) should gain a write path at all.
  Relates to memory-provenance-fields (shipped).
```

After appending, the record count is 17 (18 - 2 graduated + 1 new). Adjust the Step 5 count check
accordingly.

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin/plugin.json docs/project-tracking/
git commit -m "chore(tracking): close out A-20260819-memory-provenance-fields (v0.21.0)"
```

---

## Definition of done

- Both fields documented identically in `conventions/memory.md` and `templates/memory/README.md`.
- A fact with `verified-against` at an outdated sha reports UNVERIFIED-SINCE; the same fact at HEAD
  does not; neither changes the exit code.
- All three degradation paths (non-git src-root, unknown sha, malformed field) exit 0.
- A fact with neither field behaves byte-identically to today; every pre-existing fixture passes
  untouched.
- `applies-to` appears in the report and gates nothing.
- Full suite green, `validate-plugin.py` green, both lints clean.
- `ideas.md` at 17 records (18 - 2 graduated + 1 deferral captured) with no dangling links; both
  ideas closed on the decision record.
