# Finding record class — implementation plan

Spec: `docs/specs/2026-08-29-finding-record-class-design.md`. Version target: v0.32.0.
Branch: `feat/finding-record-class`. Inline execution.

## Task 1 — deterministic layer (TDD)

1. Commit spec + plan on the branch.
2. Locate the `A-`/`D-` harvest + `--check-tracking` file set in `scripts/memory_graph.py`;
   extend the graph test (or add one if none covers it) with red cases: a fact wikilinking
   an `F-` record resolves; `findings.md` is covered by `--check-tracking` (an over-40-line
   finding fails).
3. Implement: `F-` id shape wherever `A-`/`D-` are harvested; `findings.md` in the tracking
   file set. Green.

## Task 2 — conventions + template

1. `conventions/project-tracking.md`: findings file row, record shape, verdict enum +
   Awaiting/Closes-on semantics, close lifecycle (verdict+evidence → resolved.md), boundary
   rules (finding vs discovery vs action vs idea; behavior→memory graduation).
2. `templates/findings.md` (header + placeholder).

## Task 3 — skills + hook

1. `skills/project-log/SKILL.md`: `finding` + `verdict` modes; quick-add inference lines;
   description/argument-hint.
2. `skills/project-status/SKILL.md`: Open findings section (report), stale findings (brief).
3. `skills/project-init/SKILL.md`: stamp `findings.md`.
4. `skills/tracking-adopt/SKILL.md`: open-question routing (F- records; closed legend items
   → resolved).
5. `hooks/capture-cadence.sh`: one nudge line (keep test green).

## Task 4 — docs, version, ship

README feature map + GUIDE daily-workflow mention; plugin.json → 0.32.0; validator + full
suite; PR → green CI → squash-merge → pull → plugin update; close-out
(D-record for the verdict/Awaiting split with Closes line; resolve the action; remove the
idea; repoint wikilinks; memory_graph check).
