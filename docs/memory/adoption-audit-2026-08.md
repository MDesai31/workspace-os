---
name: adoption-audit-2026-08
description: After ~2 months of real use, workspace-os surfaces that run automatically scored 6-9/10 and every surface needing hand-authored JSON scored 1-3; typed wikilinks have zero adoption across three bases
type: domain
applies-to: repo:workspace-os
---

An audit of workspace-os against ~2 months of daily use in the UDX workforce-planning workspace
(2026-07-08 to 2026-08-24, 112 commits in `_meta`, roughly 2.4/day). Numbers below were measured,
not estimated.

## The central finding: automatic surfaces adopted, declarative-config surfaces did not

Scores split cleanly on one line, and it is a design signal rather than a discipline problem:

- **Adopted (6-9/10):** memory capture, tracking, portability. All run automatically or via a single
  command, and a SessionStart hook nudges the capture ones mid-work.
- **Dark (1-3/10):** the guardrail engine (2/10) and the advisory lint hook (1/10). Both require a
  hand-authored JSON config (`.claude/guardrails.json`, `.claude/lint.json`). **Zero of either file
  exists in any real workspace**, verified independently on both the EC2 workspace and the Windows
  checkout. `/continuity` is likewise unused, with no `CONTINUITY.md` at either root.

A working day never has a quiet moment to write schema. That is the whole explanation.

## The guardrail engine lost to hookify on ergonomics, not capability

The workspace carries exactly the hazards the engine was designed for (an employer IP boundary, a
never-push enterprise remote). What actually enforces them is three *hookify* rules:
`block-bundle-ship`, `block-enterprise-push`, `warn-em-dashes`. Hookify rules get authored by asking
for one mid-task; `guardrails.json` must be hand-written against a schema. See the
`guardrail-conversational-authoring` idea in `docs/project-tracking/ideas.md`. (Plain reference, not
a `[[wikilink]]`: `memory_graph.py` resolves link targets to fact slugs and `A-`/`D-` records only,
so an idea name is never a resolvable target from a memory fact.)

Secondary limit: the engine matches regex over command/content/path text only, so no rule can depend
on state ("is this the remote we never push to", "is disk under 5%").

## Typed wikilinks: shipped, linted, never once used

Zero predicates across three independent bases: 0 of 478 edges in the EC2 workspace, 0 of 128 in the
Windows `_meta` mirror, 0 of 1 in workspace-os's own `docs/memory/`. The vocabulary shipped in
v0.7.0 and `memory_graph.py` reports coverage, but `/ingest` never asks for a predicate at capture
time, so none is ever written. **The general lesson: a schema affordance with no capture-time prompt
gets zero adoption regardless of how well it is documented or linted.** Either teach the capture
path to propose one, or retire the vocabulary. This is the same failure mode as the `Priority:`
drift and the rejected `volatility` enum: metadata nothing prompts for and nothing validates does
not survive contact with a working day.

## Artifact classes the plugin does not model

All hand-rolled in the workspace: 1,063 lines of procedural playbooks in `_meta/conventions/`; a
tool lifecycle (`sfq.py`, `nbtool.py`, `run_diff.sh`, `htmlcheck.py`) with no registry; VP-bound
deliverables in `_meta/visuals/` and `_meta/briefings/`; and a six-agent roster with a
hand-maintained version-history folder.

## Structural mismatch: four checkouts of one repo

The four UDX folders are branches of a single repo, but each is modelled as an independent data
root. Measured cost: 10 permanently-reported "broken links" at the workspace tier that all resolve
to real records in the repo tiers, and propagation state written as freeform prose in a `Status:`
field because the schema cannot express "landed in two of four checkouts."

## Bottom line

As a memory and tracking system for this work, 7.5/10 and doing the heaviest lifting. As the
"workspace OS" the README describes, 4/10: three headline features are dark in the workspace with
the strongest case for them.

Cheapest moves to close the gap: wire `--check-citations --src-root` at the four checkouts, teach
the validator to resolve cross-tier `A-`/`D-` targets (kills the 10 false positives before they
train you to ignore lint), and give guardrails a conversational authoring path.
