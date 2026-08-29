# Foreign memory-format conversion (/memory-adopt foreign) — design

Date: 2026-08-29. Status: approved (backlog order approved 2026-08-29). Ships adoption-import
sub-slice (a) — the idea's last remaining sub-slice.

## Problem

A repo adopting workspace-os may already run a *different memory system*: a top-level
`memory/` or `notes/` dir, an Obsidian-style wiki vault, another plugin's store. Today
`/memory-adopt` treats those files as generic free-form docs — extracting fragments instead
of converting the store — and the stamped empty index then competes with the live foreign
store (the exact two-stores hazard `/project-init`'s memory guard exists for).

## Design

### New mode: `/memory-adopt foreign <path>`

Explicit, store-level conversion of one foreign store into `<data_root>/memory/` schema.
Propose-confirm-apply like everything else; the source store is **read-only** — conversion
copies, never moves or deletes.

### Detection (in the default scan)

The default `/memory-adopt` scan checks likely roots (`memory/`, `notes/`, `docs/notes/`,
`wiki/`, `kb/`, a dir holding `.obsidian/`) — excluding `<data_root>/memory/` — for a
directory that *looks like a memory store*: ≥3 `.md` files, most short, plus at least one
store signal (YAML frontmatter, `[[wikilinks]]`, or an index/MOC file such as `MEMORY.md`,
`INDEX.md`, `MOC*`, `_index*`, `00-*`). On detection it does NOT silently convert: it names
the store, points at `foreign` mode, and continues the normal scan without those files.

### Conversion mapping (per source note)

- **slug**: kebab-normalized filename (frontmatter `title` wins when present); collisions
  get a disambiguating suffix and are called out.
- **description**: frontmatter description/summary, else the first substantive line,
  condensed to one line.
- **type**: the existing content gates decide `domain|convention|reference` — foreign
  taxonomy fields are hints, never mapped 1:1 (same rule as `/memory-sync`).
- **body**: preserved, not rewritten; a `Source: <original path> (adopted YYYY-MM-DD)` line
  is appended. One-fact-per-file holds: a note bundling unrelated facts is proposed as a
  split; a procedure-shaped note (steps/how-to, large) routes to `/playbook adopt` instead;
  work-state notes route to `/tracking-adopt` or skip — each with the deciding gate named.
- **links**: `[[Foo Bar]]` → `[[foo-bar]]` when the target is adopted in the same batch;
  otherwise the link is flattened to plain text and reported (never a knowingly-broken
  wikilink).
- **foreign frontmatter**: dropped except what maps (title/description); never copied
  verbatim.

Dedup, secret-scan, batch proposal, index update: the existing `/memory-adopt` steps apply
unchanged. After apply, the report reminds the user to retire the foreign store themselves
(two live stores is the hazard; retiring is their call, never ours).

## Non-goals

- Non-markdown stores (databases, org-mode, Notion exports) — out of scope; say so if hit.
- Auto-conversion on detection (explicit `foreign` invocation only).
- Bidirectional sync with the foreign store (conversion is one-time).

## Where the rules live

`conventions/memory.md` gains "Adopting a foreign memory store" (detection signals + mapping
— the SoT); the skill points at it, per house rule.

## Verification

Skill-prose + conventions slice: validator + full suite green; doc-freshness gate covers
README/GUIDE mentions.
