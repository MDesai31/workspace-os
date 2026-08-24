#!/usr/bin/env python3
"""Derive the knowledge-graph from a repo's docs/memory/ markdown, and lint the links.

The deterministic backbone of /memory-lint: it DERIVES a graph from the markdown we
already write, rather than maintaining a parallel store. No database, no embeddings,
pure stdlib so it runs identically in a session, a pre-commit hook, and CI.

What it reads:
  - [[wikilinks]]            note-to-note edges (the real knowledge graph)
  - [text](relative.md)      index edges (the MEMORY.md hub-and-spoke star)
  Code spans (`...`) and fenced ``` blocks are stripped first so prose that merely
  MENTIONS "[[wikilinks]]" as an example is not counted as a link.

Typed edges: a wikilink may carry an optional predicate, kept in plain markdown so the
substrate stays portable and the graph gains meaning without a graph DB:
    [[supersedes::old-fact]]      ->  edge type "supersedes"
    [[blocked_by::other-fact]]    ->  edge type "blocked_by"
    [[fact]]                      ->  edge type "related" (untyped, default)
Aliases still work: [[type::target|label]] or [[target|label]]. Suggested vocabulary:
supersedes, superseded_by, blocked_by, depends_on, derived_from, verifies, contradicts,
part_of. Not enforced; typed coverage is just reported so the gap stays visible.

What it reports:
  - BROKEN LINKS     a [[wikilink]] resolving to neither a memory file nor an A-/D-
                     tracking record (fail gate)
  - INDEX PARITY     memory files missing from MEMORY.md + dangling index entries
                     (fail gate; conventions/memory.md: exactly one entry per fact)
  - ORPHANS          a note with no wikilink in or out (reachable only via the index)
  - WEAKLY LINKED    degree-1 notes in the wikilink graph
  - HUBS             highest-degree notes
  - NAMING DRIFT     a target referenced as both hyphen and underscore form
  - DUPLICATES       duplicate frontmatter `name:` or duplicate file basenames
  - TYPED COVERAGE   share of wikilink edges that carry a predicate
Semantic duplicate-FACT and stale-claim detection are intentionally NOT here; those are
judgment calls for the model pass of /memory-lint.

Modes:
  (no flags)         scan and print the full report.
  --root DIR         memory root (default: docs/memory).
  --tracking-root DIR  where A-/D- record headings are harvested from so
                     [[D-YYYYMMDD-slug]] links resolve (default: docs/project-tracking;
                     missing dir = no records, no error).
  --json PATH        also write the graph (nodes + typed edges + degree) as JSON.
  --mermaid PATH     also write a Mermaid graph of the wikilink edges.
  --check            print only problems; exit 1 on any BROKEN LINK, unindexed file,
                     or dangling index entry. Wire into pre-commit/CI of a target repo.

Vendored & adapted from keystone-engine (zachburke9/keystone-engine
starter/scripts/memory_graph.py @ cecb4b9, MIT, Zach Burke) — continuing that repo's
courtesy-attribution lineage. workspace-os adaptations: docs/memory default root
(single-tier; no source/mirror machinery), A-/D- tracking-record link resolution,
index-parity checks, MEMORY.md excluded from orphan noise. Trimmed upstream modes we
do not use (--html view, --relink, --suggest-hublinks, --recency) — re-vendor from
upstream if ever wanted.

Usage:
  python3 scripts/memory_graph.py
  python3 scripts/memory_graph.py --check
  python3 scripts/memory_graph.py --json graph.json --mermaid graph.mmd
"""
import argparse
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

WIKILINK = re.compile(r"\[\[([^\]]+?)\]\]")
MDLINK = re.compile(r"\]\(([^)]+?\.md)\)")
FENCE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE = re.compile(r"`[^`]*`")
FRONTMATTER_NAME = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)
FRONTMATTER_DESC = re.compile(r"^description:\s*(.+?)\s*$", re.MULTILINE)
FRONTMATTER_APPLIES = re.compile(r"^applies-to:\s*(branch|repo):(\S.*?)\s*$", re.MULTILINE)
FRONTMATTER_VERIFIED = re.compile(
    r"^verified-against:\s*([0-9a-fA-F]{7,40})\s+(\d{4}-\d{2}-\d{2})\s*$", re.MULTILINE)
RECORD_HEADING = re.compile(r"^###\s+([AD]-\d{8}-[A-Za-z0-9-]+)", re.MULTILINE)

# Citation lint: a `path.ext:NNN` line-number citation, a backticked `path::symbol` anchor,
# and a bare backticked identifier used as the adjacency signal for a line citation.
CITATION = re.compile(r"([\w./-]+\.[A-Za-z][A-Za-z0-9]*):(\d+)")
ANCHOR = re.compile(r"`([\w./-]+)::([A-Za-z_][A-Za-z0-9_]*)`")
BACKTICK_SYMBOL = re.compile(r"`([A-Za-z_][A-Za-z0-9_]*)`")
# Tracking-boundary lint: the bolded MEASURED evidence marker.
MEASURED = re.compile(r"\*\*MEASURED\*\*")

INDEX_NAME = "MEMORY.md"


def norm(s: str) -> str:
    """Canonical node id: lowercase, hyphen and space folded to underscore."""
    return s.strip().lower().replace("-", "_").replace(" ", "_")


def strip_code(text: str) -> str:
    """Remove fenced blocks and inline code so example links in prose do not count."""
    return INLINE_CODE.sub("", FENCE.sub("", text))


def _frontmatter(text: str) -> str:
    """Return the leading `---` frontmatter block, or "" when the file has none.

    Parsed as a block rather than with a fixed character window: a long description can push
    later fields past any fixed slice, and the provenance fields sit below `type:`.
    """
    if not text.startswith("---"):
        return ""
    end = text.find("\n---", 3)
    return text[:end] if end != -1 else ""


def parse_wikilink(raw: str):
    """Return (edge_type, target_norm, raw_target) for one [[...]] payload.

    Handles [[target]], [[target|alias]], [[type::target]], [[type::target|alias]].
    Drops a trailing #heading anchor. Untyped links get type 'related'.
    """
    payload = raw.split("|", 1)[0].strip()  # drop alias
    payload = payload.split("#", 1)[0].strip()  # drop heading anchor
    if "::" in payload:
        etype, target = payload.split("::", 1)
        etype = norm(etype)
    else:
        etype, target = "related", payload
    return etype, norm(target), target.strip()


def harvest_records(tracking_root: Path):
    """Collect normalized A-/D- record IDs from `### A-...`/`### D-...` headings so a
    [[D-YYYYMMDD-slug]] wikilink resolves. Missing dir = empty set (fail open)."""
    records = set()
    if not tracking_root.is_dir():
        return records
    for f in sorted(tracking_root.rglob("*.md")):
        text = f.read_text(encoding="utf-8", errors="ignore")
        for m in RECORD_HEADING.finditer(text):
            records.add(norm(m.group(1)))
    return records


def scan(root: Path):
    files = sorted(root.rglob("*.md"))
    present = {}  # norm stem -> Path
    raw_targets = defaultdict(set)  # norm target -> set of raw spellings seen
    names = defaultdict(list)  # frontmatter name: -> [paths]
    basenames = defaultdict(list)  # file basename -> [paths]
    wiki_edges = []  # (src, type, dst, raw, file, lineno)
    descriptions = {}  # norm stem -> frontmatter description: (one line, may be "")
    applies_to = {}  # norm stem -> "branch:<name>" / "repo:<name>" (only for scoped facts)
    index_edges = set()  # (src, dst)  markdown-link hub->leaf
    index_targets = set()  # norm stems of every .md the index links to (resolved or not)

    for f in files:
        s = norm(f.stem)
        present[s] = f
        basenames[f.name].append(str(f))

    index_stem = norm(Path(INDEX_NAME).stem)

    for f in files:
        s = norm(f.stem)
        text = f.read_text(encoding="utf-8", errors="ignore")
        for m in FRONTMATTER_NAME.finditer(text[:400]):  # frontmatter is near the top
            names[norm(m.group(1))].append(str(f))
        dm = FRONTMATTER_DESC.search(text[:400])
        descriptions[s] = dm.group(1).strip() if dm else ""
        am = FRONTMATTER_APPLIES.search(_frontmatter(text))
        if am:
            applies_to[s] = f"{am.group(1)}:{am.group(2)}"
        # wikilinks, with ACCURATE line numbers: walk the original lines and skip fenced
        # code blocks + inline code spans (so example links in prose are not counted, and
        # collapsing fences does not shift the reported line numbers).
        in_fence = False
        for lineno, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for m in WIKILINK.finditer(INLINE_CODE.sub("", line)):
                etype, dst, raw = parse_wikilink(m.group(1))
                if dst and dst != s:
                    wiki_edges.append((s, etype, dst, raw, str(f), lineno))
                    raw_targets[dst].add(raw)
        # markdown-link index edges (only those resolving to a real file)
        clean = strip_code(text)
        for m in MDLINK.finditer(clean):
            dst = norm(Path(m.group(1)).stem)
            if s == index_stem and f.parent == root:
                index_targets.add(dst)
            if dst in present and dst != s:
                index_edges.add((s, dst))

    return {
        "files": files,
        "present": present,
        "descriptions": descriptions,
        "applies_to": applies_to,
        "raw_targets": raw_targets,
        "names": names,
        "basenames": basenames,
        "wiki_edges": wiki_edges,
        "index_edges": index_edges,
        "index_targets": index_targets,
        "index_stem": index_stem,
    }


def analyze(data, records):
    present = data["present"]
    wiki_edges = data["wiki_edges"]
    index_stem = data["index_stem"]

    # degree in the wikilink graph (undirected, by distinct neighbor)
    neighbors = defaultdict(set)
    for s, _t, d, _raw, _f, _ln in wiki_edges:
        neighbors[s].add(d)
        neighbors[d].add(s)
    deg = {n: len(neighbors[n]) for n in set(list(neighbors) + list(present))}

    # HARD broken: normalizes to neither a memory file nor an A-/D- tracking record.
    broken = sorted(
        {(d, f, ln) for s, _t, d, _raw, f, ln in wiki_edges
         if d not in present and d not in records},
        key=lambda x: (x[0], x[1]),
    )

    # Index parity (conventions/memory.md: every fact has exactly one MEMORY.md entry).
    notes = set(present) - {index_stem}
    unindexed = sorted(notes - data["index_targets"])
    dangling = sorted(data["index_targets"] - set(present) - records)

    linked = {n for n in notes if deg.get(n, 0) > 0}
    orphans = sorted(notes - linked)
    weak = sorted([n for n in notes if deg.get(n, 0) == 1])
    hubs = sorted(
        [(deg.get(n, 0), n) for n in notes], key=lambda x: (-x[0], x[1])
    )[:12]

    # naming drift: a normalized target whose raw spellings include both - and _
    drift = []
    for tgt, spellings in data["raw_targets"].items():
        has_h = any("-" in sp for sp in spellings)
        has_u = any("_" in sp for sp in spellings)
        if has_h and has_u:
            drift.append((tgt, sorted(spellings)))
    drift.sort()

    dup_names = {k: v for k, v in data["names"].items() if len(v) > 1}
    dup_base = {k: v for k, v in data["basenames"].items() if len(v) > 1}

    typed = Counter(t for _s, t, _d, _raw, _f, _ln in wiki_edges)
    typed_total = sum(typed.values())
    typed_meaningful = typed_total - typed.get("related", 0)

    return {
        "n_files": len(present),
        "n_records": len(records),
        "n_wiki_edges": len(wiki_edges),
        "n_index_edges": len(data["index_edges"]),
        "n_linked": len(linked),
        "broken": broken,
        "unindexed": unindexed,
        "dangling": dangling,
        "orphans": orphans,
        "weak": weak,
        "hubs": hubs,
        "drift": drift,
        "dup_names": dup_names,
        "dup_base": dup_base,
        "typed": typed,
        "typed_total": typed_total,
        "typed_meaningful": typed_meaningful,
        "deg": deg,
        "neighbors": neighbors,
    }


def print_report(data, a, root):
    p = print
    p(f"\nMemory knowledge-graph: {root}")
    p("=" * 64)
    p(f"  files (nodes)        {a['n_files']}")
    p(f"  tracking records     {a['n_records']}   (A-/D- link targets)")
    p(f"  wikilink edges       {a['n_wiki_edges']}   (note-to-note; the real graph)")
    p(f"  index edges          {a['n_index_edges']}   (markdown links; hub-and-spoke)")
    p(f"  wikilink-connected   {a['n_linked']} / {max(a['n_files'] - 1, 0)}")

    p(f"\nBROKEN LINKS ({len(a['broken'])})  -- a [[link]] resolving to no memory file or A-/D- record:")
    if a["broken"]:
        for tgt, f, ln in a["broken"]:
            p(f"  [[{tgt}]]  <-  {Path(f).as_posix()}:{ln}")
    else:
        p("  none")

    p(f"\nINDEX PARITY  -- conventions/memory.md: exactly one {INDEX_NAME} entry per fact:")
    p(f"  unindexed files ({len(a['unindexed'])}): "
      + (", ".join(a["unindexed"]) if a["unindexed"] else "none"))
    p(f"  dangling entries ({len(a['dangling'])}): "
      + (", ".join(a["dangling"]) if a["dangling"] else "none"))

    p(f"\nTYPED-EDGE COVERAGE:")
    p(f"  {a['typed_meaningful']} / {a['typed_total']} edges carry a predicate; "
      f"{a['typed'].get('related', 0)} are untyped 'related'.")
    for t, c in a["typed"].most_common():
        if t != "related":
            p(f"    {t}: {c}")

    p(f"\nORPHANS ({len(a['orphans'])})  -- no wikilink in or out (reachable only via the index):")
    p("  " + (", ".join(a["orphans"]) if a["orphans"] else "none"))

    p(f"\nWEAKLY LINKED ({len(a['weak'])})  -- degree-1 notes:")
    p("  " + (", ".join(a["weak"]) if a["weak"] else "none"))

    p(f"\nNAMING DRIFT ({len(a['drift'])})  -- same target spelled both hyphen and underscore:")
    if a["drift"]:
        for tgt, forms in a["drift"]:
            p(f"  {tgt}: {forms}")
    else:
        p("  none")

    if a["dup_names"] or a["dup_base"]:
        p(f"\nDUPLICATES:")
        for k, v in a["dup_names"].items():
            p(f"  frontmatter name '{k}': {v}")
        for k, v in a["dup_base"].items():
            p(f"  basename '{k}': {v}")

    p(f"\nHUBS (top by wikilink degree):")
    for dg, n in a["hubs"]:
        p(f"  {dg:>2}  {n}")

    scoped = data.get("applies_to", {})
    if scoped:
        p(f"\nSCOPED FACTS ({len(scoped)})  -- facts narrowed by applies-to:")
        for stem, scope in sorted(scoped.items()):
            p(f"  {stem}: {scope}")
    p("")


def print_search(data, query):
    """Print facts whose name (file stem) or description contains QUERY, case-insensitive.

    Name-matches sort before description-only matches; alphabetical within each group.
    Empty query or no matches -> MATCHES (0). Display uses the real hyphenated file stem.
    """
    q = query.strip().lower()
    present = data["present"]
    descriptions = data["descriptions"]
    index_stem = data["index_stem"]
    hits = []  # (rank, sort_key, display_name, description)
    if q:
        for s in sorted(present):
            if s == index_stem:  # the MEMORY.md index is not a fact
                continue
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


def _resolve_src(path_str, src_root):
    """Resolve a cited path under src_root. Returns (status, value):
      ("ok", Path)          an exact relative path, or a unique basename match
      ("ambiguous", [Path]) a bare basename matching more than one file (disambiguate first)
      ("missing", None)     no match under src_root
    An exact relative path always wins, so a fully-pathed citation is never ambiguous."""
    p = src_root / path_str
    if p.is_file():
        return ("ok", p)
    base = Path(path_str).name
    matches = [m for m in sorted(src_root.rglob(base)) if m.is_file()]
    if len(matches) == 1:
        return ("ok", matches[0])
    if len(matches) > 1:
        return ("ambiguous", matches)
    return ("missing", None)


def _symbol_block(lines, symbol):
    """Return the (start, end) 1-indexed line range of SYMBOL's definition block, or None.

    A block runs from the symbol's definition line to just before the next top-level
    (column-0) definition, or EOF. Only definition-shaped occurrences anchor a block, so a
    citation to any line INSIDE a long function reads as correct, not stale -- this is the
    discriminator that keeps the lint from firing on every in-body line citation.
    """
    esc = re.escape(symbol)
    def_pat = re.compile(
        rf"^\s*(?:export\s+)?(?:async\s+)?(?:def|class|function)\s+{esc}\b"
        rf"|^\s*(?:export\s+)?(?:const|let|var)\s+{esc}\b"
    )
    topdef = re.compile(
        r"^(?:export\s+)?(?:async\s+)?(?:def|class|function|const|let|var)\s+\w"
    )
    def_line = None
    topdefs = []
    for i, line in enumerate(lines, 1):
        if topdef.match(line):
            topdefs.append(i)
        if def_line is None and def_pat.match(line):
            def_line = i
    if def_line is None:
        return None
    end = len(lines)
    for t in topdefs:
        if t > def_line:
            end = t - 1
            break
    return (def_line, end)


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


def check_citations(root, src_root):
    """Verify `path:NNN` and `path::symbol` citations in memory facts against the real source.

    Returns (stale, unresolvable, unanchored), each a list of (fact_filename, detail):
      STALE        a line citation whose NNN is outside the adjacent symbol's block, or a
                   `path::symbol` anchor whose symbol no longer exists (fail gate).
      UNRESOLVABLE the cited file is absent under src_root (non-fatal; it may live elsewhere).
      UNANCHORED   a line citation with no adjacent backticked symbol to check against.
      UNVERIFIED-SINCE  the fact carries `verified-against: <sha> <date>` and a cited file changed
                   after that sha, so nobody has confirmed the claim since the code moved
                   (advisory; never a fail gate).
    """
    stale, unresolvable, unanchored, ambiguous, unverified = [], [], [], [], []
    cited_paths = defaultdict(set)  # fact filename -> {absolute resolved Path}
    fact_sha = {}                   # fact filename -> sha from verified-against
    for f in sorted(root.rglob("*.md")):
        if f.name == INDEX_NAME:
            continue
        fact = f.name
        text = f.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines()
        vm = FRONTMATTER_VERIFIED.search(_frontmatter(text))
        if vm:
            fact_sha[fact] = vm.group(1)
        sym_by_line = defaultdict(list)
        for i, line in enumerate(lines, 1):
            for m in BACKTICK_SYMBOL.finditer(line):
                sym_by_line[i].append(m.group(1))

        # 1) `path::symbol` anchors -> existence check (no line math; the rot-proof form).
        for line in lines:
            for m in ANCHOR.finditer(line):
                path_str, symbol = m.group(1), m.group(2)
                status, val = _resolve_src(path_str, src_root)
                if status == "ok":
                    cited_paths[fact].add(val.resolve())
                if status == "missing":
                    unresolvable.append((fact, f"`{path_str}::{symbol}` (file not found under src-root)"))
                elif status == "ambiguous":
                    ambiguous.append((fact, f"`{path_str}::{symbol}` ({len(val)} files match; add a path prefix)"))
                elif not re.search(rf"\b{re.escape(symbol)}\b",
                                   val.read_text(encoding="utf-8", errors="ignore")):
                    stale.append((fact, f"`{path_str}::{symbol}` but symbol not found in {val.name}"))

        # 2) `path.ext:NNN` line citations -> block containment against an adjacent DEFINED symbol.
        # Only a backticked token that is actually defined in the resolved file is a checkable
        # symbol; a nearby import/exception/literal is not, so it degrades to UNANCHORED, never
        # STALE. This keeps STALE high-precision on real facts, where prose backticks many tokens.
        for i, line in enumerate(lines, 1):
            for m in CITATION.finditer(line):
                path_str, nnn = m.group(1), int(m.group(2))
                candidates = []
                for dist in (0, 1, 2):
                    for j in ([i] if dist == 0 else [i - dist, i + dist]):
                        for sym in sym_by_line.get(j, []):
                            if sym not in candidates:
                                candidates.append(sym)
                if not candidates:
                    unanchored.append((fact, f"{path_str}:{nnn} (no adjacent `symbol`)"))
                    continue
                status, val = _resolve_src(path_str, src_root)
                if status == "ok":
                    cited_paths[fact].add(val.resolve())
                if status == "missing":
                    unresolvable.append((fact, f"{path_str}:{nnn} (file not found under src-root)"))
                    continue
                if status == "ambiguous":
                    ambiguous.append((fact, f"{path_str}:{nnn} ({len(val)} files match; add a path prefix)"))
                    continue
                src = val
                src_lines = src.read_text(encoding="utf-8", errors="ignore").splitlines()
                blocks = [(sym, _symbol_block(src_lines, sym)) for sym in candidates]
                blocks = [(sym, b) for sym, b in blocks if b is not None]
                if not blocks:
                    unanchored.append((fact, f"{path_str}:{nnn} (no defined symbol adjacent to check)"))
                    continue
                if any(start <= nnn <= end for _sym, (start, end) in blocks):
                    continue  # citation lands inside a cited symbol's block -> correct
                sym, (start, end) = blocks[0]
                stale.append((fact, f"{path_str}:{nnn} cites `{sym}` whose block is lines {start}-{end}"))

    # Freshness: batch one `git diff` per DISTINCT sha (after a bulk /ingest most facts share
    # one), then attribute the changed paths back to each fact. Advisory throughout -- every
    # unanswerable case degrades to a note, never an error and never a fail gate.
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
                        unverified.append(
                            (fct, f"freshness unverifiable (sha {sha} not in src-root repo)"))
                    continue
                for fct in sorted(facts):
                    hits = sorted(p.name for p in cited_paths.get(fct, ()) if p in changed)
                    if hits:
                        unverified.append(
                            (fct, f"verified at {sha}; changed since: {', '.join(hits)}"))
    return stale, unresolvable, unanchored, ambiguous, unverified


def print_citations(stale, unresolvable, unanchored, ambiguous, unverified, root, src_root):
    print(f"CITATION LINT  (root={Path(root).as_posix()}, src-root={Path(src_root).as_posix()})")
    print(f"  stale: {len(stale)}   ambiguous: {len(ambiguous)}   "
          f"unresolvable: {len(unresolvable)}   unanchored: {len(unanchored)}   "
          f"unverified: {len(unverified)}")
    for label, items in (("STALE", stale), ("AMBIGUOUS", ambiguous),
                         ("UNRESOLVABLE", unresolvable), ("UNANCHORED", unanchored),
                         ("UNVERIFIED-SINCE", unverified)):
        if items:
            print(f"{label} ({len(items)}):")
            for fact, detail in items:
                print(f"  {fact}: {detail}")
    if not stale:
        print("citations: clean (no stale citations)")


def _iter_records(text):
    """Yield (record_id, body_lines) for each `### A-/D-` record; any heading closes a record."""
    cur_id, body = None, []
    for line in text.splitlines():
        if re.match(r"^#{1,6}\s", line):
            if cur_id:
                yield cur_id, body
            cur_id, body = None, []
            hm = RECORD_HEADING.match(line)
            if hm:
                cur_id = hm.group(1)
        elif cur_id is not None:
            body.append(line)
    if cur_id:
        yield cur_id, body


def check_tracking(tracking_root, max_lines):
    """Flag A-/D- tracking records whose body exceeds max_lines or carries a **MEASURED**
    block -- long detail and measured evidence belong in memory/, not a tracking record body
    (conventions/project-tracking.md). Returns a list of (record_id, reason). Missing dir =
    no violations (fail open)."""
    violations = []
    if not tracking_root.is_dir():
        return violations
    for f in sorted(tracking_root.rglob("*.md")):
        text = f.read_text(encoding="utf-8", errors="ignore")
        for rec_id, body in _iter_records(text):
            # Strip inline code so a record that merely MENTIONS `**MEASURED**` in prose is not
            # flagged -- only a real evidence block counts (mirrors the wikilink example handling).
            if MEASURED.search(INLINE_CODE.sub("", "\n".join(body))):
                violations.append((rec_id, "contains a **MEASURED** block (measured evidence belongs in a memory fact)"))
            trimmed = list(body)
            while trimmed and not trimmed[0].strip():
                trimmed.pop(0)
            while trimmed and not trimmed[-1].strip():
                trimmed.pop()
            if len(trimmed) > max_lines:
                violations.append((rec_id, f"body is {len(trimmed)} lines > {max_lines} (long detail belongs in memory/, not the record body)"))
    return violations


def print_tracking(violations, tracking_root, max_lines):
    print(f"TRACKING BOUNDARY LINT  (tracking-root={Path(tracking_root).as_posix()}, "
          f"max-record-lines={max_lines})")
    print(f"  violations: {len(violations)}")
    for rec_id, reason in violations:
        print(f"  {rec_id}: {reason}")
    if not violations:
        print("tracking: clean (records within the memory/tracking boundary)")


def write_json(data, a, path):
    nodes = [
        {"id": n, "file": data["present"][n].as_posix(), "degree": a["deg"].get(n, 0)}
        for n in sorted(data["present"])
    ]
    edges = [
        {"source": s, "type": t, "target": d, "file": Path(f).as_posix(), "line": ln}
        for s, t, d, _raw, f, ln in data["wiki_edges"]
    ]
    index_edges = [{"source": s, "target": d} for s, d in sorted(data["index_edges"])]
    Path(path).write_text(
        json.dumps({"nodes": nodes, "wikilink_edges": edges, "index_edges": index_edges},
                   indent=2),
        encoding="utf-8",
    )
    print(f"wrote {path}  ({len(nodes)} nodes, {len(edges)} wikilink edges)")


def write_mermaid(data, a, path):
    lines = ["graph LR"]
    for s, t, d, _raw, _f, _ln in data["wiki_edges"]:
        label = "" if t == "related" else f"|{t}|"
        lines.append(f"  {s} -->{label} {d}")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {path}")


def main():
    ap = argparse.ArgumentParser(description="Derive and lint the docs/memory knowledge-graph.")
    ap.add_argument("--root", default="docs/memory",
                    help="memory root to scan (default: docs/memory)")
    ap.add_argument("--tracking-root", default="docs/project-tracking",
                    help="dir harvested for A-/D- record link targets "
                         "(default: docs/project-tracking; missing = no records)")
    ap.add_argument("--link-root", action="append", default=[],
                    help="additional memory dir(s) whose file stems resolve [[wikilinks]] "
                         "(e.g. the sidecar workspace tier); scanned for names only, "
                         "not linted (missing dir = fail open)")
    ap.add_argument("--json", help="also write graph JSON to this path")
    ap.add_argument("--mermaid", help="also write a Mermaid graph to this path")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 on broken links / unindexed files / dangling index "
                         "entries; print problems only")
    ap.add_argument("--search", metavar="QUERY",
                    help="print facts whose name or description contains QUERY "
                         "(case-insensitive); read-only recall, exit 0 even if none match")
    ap.add_argument("--backlinks", metavar="NODE",
                    help="print LINKS OUT and BACKLINKS for NODE from the wikilink graph; "
                         "read-only, exit 0 even if NODE is unknown")
    ap.add_argument("--check-citations", action="store_true",
                    help="verify `path:NNN` / `path::symbol` citations against a source tree "
                         "(requires --src-root); exit 1 on any stale citation")
    ap.add_argument("--src-root", metavar="DIR",
                    help="source tree that citations resolve against (required with "
                         "--check-citations)")
    ap.add_argument("--check-tracking", action="store_true",
                    help="flag A-/D- tracking records that exceed --max-record-lines or carry a "
                         "**MEASURED** block (the memory/tracking boundary); exit 1 on findings")
    ap.add_argument("--max-record-lines", type=int, default=40, metavar="N",
                    help="record-body line ceiling for --check-tracking (default 40)")
    args = ap.parse_args()

    # Tracking-boundary lint scans the tracking tree, not the memory root -- handle before the
    # memory-root existence gate so it works in a tracking-only tree.
    if args.check_tracking:
        violations = check_tracking(Path(args.tracking_root), args.max_record_lines)
        print_tracking(violations, args.tracking_root, args.max_record_lines)
        return 1 if violations else 0

    root = Path(args.root)
    if not root.exists():
        print(f"error: root not found: {root}", file=sys.stderr)
        return 2

    if args.check_citations:
        if not args.src_root:
            print("error: --check-citations requires --src-root", file=sys.stderr)
            return 2
        src_root = Path(args.src_root)
        if not src_root.is_dir():
            print(f"error: src-root not found: {src_root}", file=sys.stderr)
            return 2
        stale, unresolvable, unanchored, ambiguous, unverified = check_citations(root, src_root)
        print_citations(stale, unresolvable, unanchored, ambiguous, unverified, root, src_root)
        return 1 if stale else 0

    records = harvest_records(Path(args.tracking_root))
    for lr in args.link_root:
        lrp = Path(lr)
        if lrp.is_dir():
            for f in sorted(lrp.rglob("*.md")):
                records.add(norm(f.stem))
    data = scan(root)
    if args.search is not None:
        print_search(data, args.search)
        return 0
    if args.backlinks is not None:
        print_backlinks(data, args.backlinks)
        return 0
    a = analyze(data, records)

    if args.check:
        problems = 0
        if a["broken"]:
            problems += len(a["broken"])
            print(f"memory_graph: {len(a['broken'])} broken [[link]](s):", file=sys.stderr)
            for tgt, f, ln in a["broken"]:
                print(f"  [[{tgt}]]  <-  {Path(f).as_posix()}:{ln}", file=sys.stderr)
        if a["unindexed"]:
            problems += len(a["unindexed"])
            print(f"memory_graph: {len(a['unindexed'])} file(s) missing from {INDEX_NAME}: "
                  + ", ".join(a["unindexed"]), file=sys.stderr)
        if a["dangling"]:
            problems += len(a["dangling"])
            print(f"memory_graph: {len(a['dangling'])} dangling {INDEX_NAME} entr(ies): "
                  + ", ".join(a["dangling"]), file=sys.stderr)
        if problems:
            return 1
        print("memory_graph: clean (links resolve; index in parity)")
        return 0

    print_report(data, a, root)
    if args.json:
        write_json(data, a, args.json)
    if args.mermaid:
        write_mermaid(data, a, args.mermaid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
