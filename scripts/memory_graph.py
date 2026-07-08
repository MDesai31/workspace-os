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
import sys
from collections import Counter, defaultdict
from pathlib import Path

WIKILINK = re.compile(r"\[\[([^\]]+?)\]\]")
MDLINK = re.compile(r"\]\(([^)]+?\.md)\)")
FENCE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE = re.compile(r"`[^`]*`")
FRONTMATTER_NAME = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)
RECORD_HEADING = re.compile(r"^###\s+([AD]-\d{8}-[A-Za-z0-9-]+)", re.MULTILINE)

INDEX_NAME = "MEMORY.md"


def norm(s: str) -> str:
    """Canonical node id: lowercase, hyphen and space folded to underscore."""
    return s.strip().lower().replace("-", "_").replace(" ", "_")


def strip_code(text: str) -> str:
    """Remove fenced blocks and inline code so example links in prose do not count."""
    return INLINE_CODE.sub("", FENCE.sub("", text))


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
    p("")


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
    args = ap.parse_args()

    root = Path(args.root)
    if not root.exists():
        print(f"error: root not found: {root}", file=sys.stderr)
        return 2

    records = harvest_records(Path(args.tracking_root))
    for lr in args.link_root:
        lrp = Path(lr)
        if lrp.is_dir():
            for f in sorted(lrp.rglob("*.md")):
                records.add(norm(f.stem))
    data = scan(root)
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
