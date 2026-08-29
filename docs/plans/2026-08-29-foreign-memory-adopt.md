# Foreign memory adopt — implementation plan

Spec: `docs/specs/2026-08-29-foreign-memory-adopt-design.md`. Version target: v0.30.0.
Branch: `feat/foreign-memory-adopt`. Inline execution. Skill-prose + conventions only.

## Task 1 — conventions

`conventions/memory.md`: new "Adopting a foreign memory store" section (detection signals,
conversion mapping, read-only source, retire-reminder) before `## Concurrency`.

## Task 2 — skill

`skills/memory-adopt/SKILL.md`: `foreign <path>` mode section; detection nudge in step 2;
description + argument-hint updates.

## Task 3 — docs, version, ship

README feature map `/memory-adopt` row; GUIDE "Adopting an existing repo" bullet.
plugin.json → 0.30.0. Validator + suite → PR → green CI → squash-merge → pull → plugin
update → close-out (resolve the action; ship-close adoption-import — all four source types
now covered; Closes line on D-20260626-memory-adopt-design; repoint wikilinks).
