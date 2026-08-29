# Guardrails session mining — implementation plan

Spec: `docs/specs/2026-08-29-guardrails-session-mining-design.md`. Version target: v0.31.0.
Branch: `feat/guardrails-session-mining`. Inline execution. Skill-prose only.

## Task 1 — skill

`skills/guardrails/SKILL.md`: `mine` dispatch entry + a Mine mode section (near-miss
classes, not-candidates, per-rule session-moment citation, empty-mine stop; everything
downstream = author mode unchanged). Frontmatter description gains the mine trigger
language.

## Task 2 — docs, version, ship

README feature map `/guardrails` row; GUIDE Guardrails section paragraph.
plugin.json → 0.31.0. Validator + suite → PR → green CI → squash-merge → pull → plugin
update → close-out (D-20260829-mine-current-session-only with Closes line; resolve the
action; remove the idea; memory_graph check).
