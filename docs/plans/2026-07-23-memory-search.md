# `/memory-search` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a read-only recall tool over this repo's `docs/memory/` (or the sidecar `<data_root>/memory/`) - find a fact by keyword, and see what links to/from a fact - as two new query modes on the existing graph engine plus a thin dispatcher skill.

**Architecture:** Both features are operations over the knowledge graph `scripts/memory_graph.py` already derives from the markdown (it scans every fact and builds a directed `wiki_edges` list). Add `--search QUERY` and `--backlinks NODE` modes to that one script (no new store, no second parser), then a `skills/memory-search/SKILL.md` that resolves the data root and dispatches to the right mode. Mirrors `skills/memory-lint/SKILL.md`'s read-only, no-commit posture.

**Tech Stack:** Python 3 stdlib only (extends `memory_graph.py`), the existing plain-bash test harness (`tests/test-memory-graph.sh`), a markdown skill file.

## Global Constraints

- **No new runtime dependencies.** `memory_graph.py` stays pure stdlib (argparse/json/re/sys/collections/pathlib already imported). Tests stay plain bash + python3. Do not add any library.
- **Existing modes are untouched.** `--check`, `--json`, `--mermaid`, and the default report must produce byte-identical output after these changes. The full existing `tests/test-memory-graph.sh` must stay green.
- **Read-only, no commit.** The engine only reads and prints; the skill only runs the engine and prints. No `Edit`/`Write` of memory, no `git` writes. (Distinct from `memory-lint`, which may offer to fix mechanical issues - `memory-search` never edits at all.)
- **Exit codes:** exit `0` on success **including an empty result** (finding nothing, or an unknown backlinks node, is a valid answer, not an error). Exit `2` stays reserved for "root not found" (the existing `main()` behavior - do not add new non-zero exits in these modes).
- **Search scope is name + description only** - no body/full-text search. Match is case-insensitive substring of the query against a fact's file stem (its name) OR its one-line frontmatter `description`. `type` is NOT parsed this slice.
- **Display real spellings, match on lowercased ones.** Show the hyphenated file stem (e.g. `fact-a`) and the raw wikilink target (e.g. `D-20260101-fixture-decision`) - never the normalized underscore id. The raw pre-norm spelling is already retained in each edge tuple's `raw` field (position 3) and via `present[stem].stem`; use those, do not un-normalize.
- **No em dashes in engine output.** Use a plain ASCII separator (`  -  `) between a fact name and its description snippet in `--search` output. (User rule: no em dashes in generated deliverables; stdout is one.)
- **Version bump on completion:** `0.13.0 -> 0.14.0` in `.claude-plugin/plugin.json`.
- **Record IDs use today's date:** action record `A-20260723-memory-search`; decision `D-20260723-memory-search-scope`.

---

### Task 1: `--search QUERY` engine mode

Add a `description:` frontmatter parse to `scan()`, a `print_search()` function, the `--search` argument, and its dispatch in `main()`. The clean fixture already carries `description:` frontmatter (`fact-a` = "first fixture fact", `fact-b` = "second fixture fact"), so no fixture edit is needed.

**Files:**
- Modify: `scripts/memory_graph.py`
- Test: `tests/test-memory-graph.sh`

**Interfaces:**
- Consumes: `scan(root)` return dict - gains a new key `descriptions` (`{norm_stem: str}`); existing keys (`present`, `wiki_edges`, ...) unchanged.
- Produces: `print_search(data, query)` - prints `MATCHES (N)  for "<query>"` then one indented line per hit (`<file-stem>  -  <description snippet>`), name-matches before description-only matches, alphabetical within each group. `main()` dispatches `--search` after `scan()` and returns 0.

- [ ] **Step 1: Write the failing tests**

In `tests/test-memory-graph.sh`, insert these blocks immediately before the final `echo "----"` summary line (near line 64):

```bash
# --- search mode: name/description substring, case-insensitive, empty result = exit 0 ---
out="$(python3 "$SCRIPT" --search "second fixture" --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "search finds fact by description" "$ec" "0" "$out" "fact-b"

out="$(python3 "$SCRIPT" --search "FIRST FIXTURE" --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "search is case-insensitive" "$ec" "0" "$out" "fact-a"

out="$(python3 "$SCRIPT" --search "zzz-no-such-term" --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "search no-match is MATCHES (0), exit 0" "$ec" "0" "$out" "MATCHES (0)"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-memory-graph.sh`
Expected: the three new checks FAIL (argparse errors on unknown `--search`, so exit code is 2 not 0 and the substrings are absent). Every pre-existing check still PASSes.

- [ ] **Step 3: Add the `description:` regex**

In `scripts/memory_graph.py`, immediately after the `FRONTMATTER_NAME` line (line 72), add:

```python
FRONTMATTER_DESC = re.compile(r"^description:\s*(.+?)\s*$", re.MULTILINE)
```

- [ ] **Step 4: Capture descriptions in `scan()`**

In `scan()`, add a `descriptions` dict alongside the other accumulators. After the line `wiki_edges = []  # (src, type, dst, raw, file, lineno)` (line 123), add:

```python
    descriptions = {}  # norm stem -> frontmatter description: (one line, may be "")
```

Inside the `for f in files:` loop that reads text (the loop starting at line 134), right after the `for m in FRONTMATTER_NAME.finditer(text[:400]):` block (after line 138), add:

```python
        dm = FRONTMATTER_DESC.search(text[:400])
        descriptions[s] = dm.group(1).strip() if dm else ""
```

Then add `descriptions` to the returned dict - in the `return {` block (lines 163-173), add this line after `"present": present,`:

```python
        "descriptions": descriptions,
```

- [ ] **Step 5: Add `print_search()`**

In `scripts/memory_graph.py`, add this function immediately before `def write_json(` (before line 302):

```python
def print_search(data, query):
    """Print facts whose name (file stem) or description contains QUERY, case-insensitive.

    Name-matches sort before description-only matches; alphabetical within each group.
    Empty query or no matches -> MATCHES (0). Display uses the real hyphenated file stem.
    """
    q = query.strip().lower()
    present = data["present"]
    descriptions = data["descriptions"]
    hits = []  # (rank, sort_key, display_name, description)
    if q:
        for s in sorted(present):
            display = present[s].stem
            desc = descriptions.get(s, "")
            in_name = q in display.lower()
            in_desc = q in desc.lower()
            if in_name or in_desc:
                hits.append((0 if in_name else 1, display.lower(), display, desc))
    hits.sort(key=lambda h: (h[0], h[1]))
    print(f'MATCHES ({len(hits)})  for "{query}"')
    for _rank, _sort, display, desc in hits:
        snippet = desc if len(desc) <= 70 else desc[:67] + "..."
        sep = "  -  " if snippet else ""
        print(f"  {display}{sep}{snippet}")
```

- [ ] **Step 6: Add the `--search` argument**

In `main()`, after the `--check` argument block (after line 344, before `args = ap.parse_args()`), add:

```python
    ap.add_argument("--search", metavar="QUERY",
                    help="print facts whose name or description contains QUERY "
                         "(case-insensitive); read-only recall, exit 0 even if none match")
```

- [ ] **Step 7: Dispatch `--search` in `main()`**

In `main()`, immediately after `data = scan(root)` (line 358) and before `a = analyze(data, records)` (line 359), add:

```python
    if args.search is not None:
        print_search(data, args.search)
        return 0
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-memory-graph.sh`
Expected: all three new search checks PASS and every pre-existing check still PASSes (final line `N passed, 0 failed`).

- [ ] **Step 9: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add scripts/memory_graph.py tests/test-memory-graph.sh
git commit -m "feat(memory): add --search mode to memory_graph.py"
```

---

### Task 2: `--backlinks NODE` engine mode

Add a `print_backlinks()` function, the `--backlinks` argument, and its dispatch. Uses only `present` + `wiki_edges` from `scan()` (no new parsing). The clean fixture's `fact-a` has a typed `supersedes` edge to `fact-b`, a `related` edge to a `D-` record, and one backlink from `fact-b` - enough to exercise both sections and type display.

**Files:**
- Modify: `scripts/memory_graph.py`
- Test: `tests/test-memory-graph.sh`

**Interfaces:**
- Consumes: `scan(root)` return dict keys `present` and `wiki_edges` (unchanged).
- Produces: `print_backlinks(data, node)` - for a known fact, prints the fact name then `LINKS OUT (n):` (each `<type> -> <raw-target>`) and `BACKLINKS (n):` (each `<source-stem> (<type>)`); for an unknown node, prints `no such fact: <node>` plus up to 5 near spellings, always returning without error. `main()` dispatches `--backlinks` after `scan()` and returns 0.

- [ ] **Step 1: Write the failing tests**

In `tests/test-memory-graph.sh`, insert immediately after the Task-1 search blocks (still before the final `echo "----"` summary):

```bash
# --- backlinks mode: typed LINKS OUT + a BACKLINK both appear; unknown node = no crash ---
out="$(python3 "$SCRIPT" --backlinks fact-a --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "backlinks shows typed LINKS OUT" "$ec" "0" "$out" "supersedes -> fact-b"
check "backlinks shows BACKLINK source" "$ec" "0" "$out" "fact-b (related)"

out="$(python3 "$SCRIPT" --backlinks no-such-fact --root "$CLEAN/docs/memory" 2>&1)"; ec=$?
check "backlinks unknown node = no crash, exit 0" "$ec" "0" "$out" "no such fact"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-memory-graph.sh`
Expected: the three new backlinks checks FAIL (argparse errors on unknown `--backlinks`, exit 2). The Task-1 search checks and all pre-existing checks still PASS.

- [ ] **Step 3: Add `print_backlinks()`**

In `scripts/memory_graph.py`, add this function immediately after `print_search()` (before `def write_json(`):

```python
def print_backlinks(data, node):
    """Print LINKS OUT (edges from NODE) and BACKLINKS (edges into NODE) for one fact.

    Display uses raw wikilink targets and real source stems, not normalized ids.
    Unknown NODE -> a 'no such fact' line + up to 5 near spellings, still exit 0.
    """
    target = norm(node)
    present = data["present"]
    wiki_edges = data["wiki_edges"]

    if target not in present:
        print(f"no such fact: {node}")
        near = sorted(s for s in present if target in s or s in target)[:5]
        if near:
            print("  did you mean: " + ", ".join(present[s].stem for s in near))
        return

    print(present[target].stem)
    out = sorted({(etype, raw) for s, etype, _d, raw, _f, _ln in wiki_edges if s == target})
    print(f"  LINKS OUT ({len(out)}):")
    for etype, raw in out:
        print(f"    {etype} -> {raw}")
    back = sorted({(present[s].stem, etype)
                   for s, etype, d, _raw, _f, _ln in wiki_edges if d == target})
    print(f"  BACKLINKS ({len(back)}):")
    for src, etype in back:
        print(f"    {src} ({etype})")
```

- [ ] **Step 4: Add the `--backlinks` argument**

In `main()`, immediately after the `--search` argument added in Task 1, add:

```python
    ap.add_argument("--backlinks", metavar="NODE",
                    help="print LINKS OUT and BACKLINKS for NODE from the wikilink graph; "
                         "read-only, exit 0 even if NODE is unknown")
```

- [ ] **Step 5: Dispatch `--backlinks` in `main()`**

In `main()`, immediately after the `--search` dispatch block added in Task 1 (and still before `a = analyze(data, records)`), add:

```python
    if args.backlinks is not None:
        print_backlinks(data, args.backlinks)
        return 0
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && bash tests/test-memory-graph.sh`
Expected: all six new checks (3 search + 3 backlinks) PASS and every pre-existing check still PASSes (final line `N passed, 0 failed`).

- [ ] **Step 7: Manual spot-check against a real fact (proves display + typed edges on real data)**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/memory_graph.py --backlinks memory-adopt --root docs/memory`
Expected: prints `memory-adopt`, a `LINKS OUT (n):` section, and a `BACKLINKS (n):` section, all with hyphenated real names (no underscores). If `memory-adopt` is not a fact in this repo's memory, substitute any name from `docs/memory/MEMORY.md`.

Run: `python3 scripts/memory_graph.py --search memory --root docs/memory`
Expected: `MATCHES (n)  for "memory"` with one hyphenated fact name + description snippet per line, no em dashes.

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add scripts/memory_graph.py tests/test-memory-graph.sh
git commit -m "feat(memory): add --backlinks mode to memory_graph.py"
```

---

### Task 3: `/memory-search` skill

Create the user-invocable dispatcher skill. It resolves the data root exactly as `memory-lint` does, then routes `--links <fact>` / `links <fact>` to `--backlinks` and anything else to `--search`.

**Files:**
- Create: `skills/memory-search/SKILL.md`

**Interfaces:**
- Consumes: `scripts/resolve-data-root.sh` (data-root resolution, same as `memory-lint`), and the `--search` / `--backlinks` modes from Tasks 1-2.
- Produces: a skill auto-discovered from `skills/` (no manifest wiring needed).

- [ ] **Step 1: Create the skill file**

Create `skills/memory-search/SKILL.md` with exactly this content:

```markdown
---
name: memory-search
description: Search this repo's memory for a fact by keyword, or show what links to/from a fact (backlinks). Use for recall over docs/memory - find a fact, see its neighbors - not for editing memory.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Memory Search

Read-only recall over this repo's `<data_root>/memory/` (`docs/memory/` in in-repo mode): find a
fact by keyword, or list what links to and from a fact. Runs the same deterministic graph engine as
`/memory-lint` (`scripts/memory_graph.py`) in one of two query modes. Never edits, never commits.

**Prerequisite - resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` (see `conventions/data-root.md`).
Memory lives at `<data_root>/memory/`; if missing, say so and stop. Announce the resolved mode
(in-repo vs sidecar), exactly like `/memory-lint`.

## Dispatch

Resolve the plugin root via `${CLAUDE_PLUGIN_ROOT}` when set, else the plugin's install directory.

- If the argument is `--links <fact>` or `links <fact>` (or just `<fact>` when the user clearly
  wants neighbors), run the **backlinks** mode:

      python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" --backlinks "<fact>" \
        --root "<data_root>/memory"

- Otherwise treat the whole argument as a search **query**:

      python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" --search "<query>" \
        --root "<data_root>/memory"

In **in-repo mode** you may omit `--root` (it defaults to `docs/memory`). In **sidecar mode** pass
the resolved `--root "<data_root>/memory"`; both modes read only the memory tree (search and
backlinks do not consult tracking records or the workspace tier, so `--tracking-root` / `--link-root`
are not needed here).

Note: the word `links` is a dispatch keyword - a query like `links optimizer` is read as
"backlinks for optimizer", not a text search for "links". Documented limitation; to search for the
literal word, phrase the query differently.

## Report

Print the engine's output verbatim; you may add a one-line summary (e.g. how many matches, or the
most relevant fact). Both modes exit 0 even when nothing is found - an empty result is a valid
answer, not an error. **No edits, no commit** - read-only recall, same posture as `/memory-lint`.
```

- [ ] **Step 2: Validate the plugin still loads**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py`
Expected: passes (exit 0), with `memory-search` recognized as a skill. If `validate-plugin.py` takes no such check, at minimum it must exit 0 with no error about the new skill directory.

- [ ] **Step 3: Live end-to-end check**

In this session, invoke `/memory-search memory` and then `/memory-search --links <a-real-fact>` (pick a fact from `docs/memory/MEMORY.md`). Confirm the data-root line is announced, the search returns hits, and the backlinks call prints LINKS OUT / BACKLINKS. This exercises the resolve-data-root + dispatch path the harness cannot cover.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add skills/memory-search/SKILL.md
git commit -m "feat(memory): add /memory-search skill"
```

---

### Task 4: Docs, tracking close-out, and version bump

Update the plugin description prose + version, mark the shipped half of the idea, and append the action + decision records. Do this last so the records reference the real commits.

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `docs/project-tracking/ideas.md`
- Modify: `docs/project-tracking/resolved.md`
- Modify: `docs/project-tracking/decisions-log.md`
- Modify (optional): `README.md`, `ARCHITECTURE.md`

**Interfaces:**
- Consumes: the commits from Tasks 1-3 (for the `Commit:` line in the action record).
- Produces: version `0.14.0`; a closed idea half; an `A-20260723-memory-search` action record and a `D-20260723-memory-search-scope` decision record.

- [ ] **Step 1: Bump version and mention the skill in plugin.json**

In `.claude-plugin/plugin.json`, change the version line to:

```json
  "version": "0.14.0",
```

And add `memory-search` to the memory skill family in the `description` string. Change the fragment `ingest/memory-lint/memory-sync/memory-adopt/tracking-adopt` to:

```
ingest/memory-lint/memory-search/memory-sync/memory-adopt/tracking-adopt
```

- [ ] **Step 2: Mark the shipped half in ideas.md**

In `docs/project-tracking/ideas.md`, under the `### memory-backlinks-search` entry, append a new line immediately after the existing `**Shipped (2026-07-05, the graph half):**` line (line 151):

```markdown
- **Shipped (2026-07-23, the search/backlink view):** `scripts/memory_graph.py` gained `--search QUERY` (name + description substring) and `--backlinks NODE` (LINKS OUT + BACKLINKS from the wikilink graph), surfaced by the new `/memory-search` skill. See `resolved.md` A-20260723-memory-search and `decisions-log.md` D-20260723-memory-search-scope. Remaining: the note-templates set, and the optional property-views by type/tag.
```

- [ ] **Step 3: Append the action record to resolved.md**

Add this entry to `docs/project-tracking/resolved.md`, following the existing append order (newest at the end of the file, matching the file's convention):

```markdown
### A-20260723-memory-search - /memory-search: search + backlink view over the memory graph (v0.14.0)
- Workstream: memory
- Status: done
- Created: 2026-07-23
- Completed: 2026-07-23
- Commit: <fill from git log after Task 3; branch feature/memory-search>

Extended `scripts/memory_graph.py` with two read-only query modes reusing `scan()`/`wiki_edges`: `--search QUERY` (case-insensitive substring over each fact's name + frontmatter description; added a `description:` parse) and `--backlinks NODE` (LINKS OUT + BACKLINKS with real spellings + typed edges). New `/memory-search` skill dispatches `--links <fact>`→backlinks, else query→search; read-only, no commit, mirrors `/memory-lint`. Tests added to `tests/test-memory-graph.sh` (all green, existing modes unchanged). Spec: `docs/specs/2026-07-19-memory-search-design.md`. Plan: `docs/plans/2026-07-23-memory-search.md`. Decision: D-20260723-memory-search-scope. Closes the search/backlink half of `memory-backlinks-search` (property-views + note-templates remain).
```

- [ ] **Step 4: Append the decision record to decisions-log.md**

Add this entry to `docs/project-tracking/decisions-log.md` (append-only, newest at the end):

```markdown
### D-20260723-memory-search-scope - /memory-search matches name+description only, off the derived graph; property-views deferred
- Workstream: memory
- Created: 2026-07-23
- Rationale: recall is built as two modes on the existing `memory_graph.py` (reusing `scan()` + `wiki_edges`), not a new `memory_search.py` and not logic in the skill - a second parser would drift from the linter's view of the graph. Search scope was narrowed to name + one-line `description` (no body/full-text) so the whole feature runs off the graph the engine already derives, with zero new file-grep data source; `type` is therefore not parsed this slice. Property-views by type/tag and the note-templates set (the idea's other two capabilities) are deferred to later slices. Invocation is user-only (`disable-model-invocation: true`, matching `/memory-lint`; reversible in one line).
- Spawns: none

Full design: `docs/specs/2026-07-19-memory-search-design.md`. Plan: `docs/plans/2026-07-23-memory-search.md`.
```

- [ ] **Step 5: (Optional) README / ARCHITECTURE line**

If the memory section of `README.md` or `ARCHITECTURE.md` lists the memory skills (as it does for `/memory-lint`), add a short parallel line for `/memory-search` (search a fact by keyword / show backlinks; read-only). Match the existing phrasing and depth; skip if it would add noise. This is the one judgment step - no forced edit.

- [ ] **Step 6: Verify the whole suite once more**

Run: `cd "C:/Users/206936855/Documents/workspace-os" && python3 scripts/validate-plugin.py && bash tests/test-memory-graph.sh`
Expected: validate passes; test harness ends `N passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/206936855/Documents/workspace-os"
git add .claude-plugin/plugin.json docs/project-tracking/ideas.md docs/project-tracking/resolved.md docs/project-tracking/decisions-log.md README.md ARCHITECTURE.md
git commit -m "docs(memory): v0.14.0 memory-search close-out (idea, action, decision records)"
```

(Drop `README.md`/`ARCHITECTURE.md` from the `git add` if Step 5 made no change.)

---

## Verification (whole feature)

- `python3 scripts/validate-plugin.py` passes; `memory_graph.py`'s existing modes (`--check`, `--json`, `--mermaid`, default report) produce unchanged output.
- `bash tests/test-memory-graph.sh` ends `N passed, 0 failed` - all prior cases plus the six new ones.
- **Live check (not just the harness):** from the repo root, `python3 scripts/memory_graph.py --search <known-keyword>` returns the expected fact(s); `--backlinks <known-fact>` lists the edges that fact's markdown actually has (spot-check against the file). Then `/memory-search` end-to-end so the data-root resolution + dispatch path is exercised.
- **Sidecar smoke:** run once with `--root` pointing at a sidecar-style tree (or the real `Codebase/_meta` workspace tier) to confirm cross-tier resolution behaves like `/memory-lint`.
- Both new modes exit 0 on empty result / unknown node (never a false failure).
```
