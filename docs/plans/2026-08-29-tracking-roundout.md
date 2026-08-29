# Tracking roundout remainder — implementation plan

Spec: `docs/specs/2026-08-29-tracking-roundout-design.md`. Version target: v0.29.0.
Branch: `feat/tracking-roundout`. Inline execution. Skill-prose only — no scripts/hooks.

## Task 1 — conventions

`conventions/project-tracking.md`: add `meetings/` (file name shape, ledgers-stay-SoT
extraction rule), the work-log `discovery` entry heading, `RELEASES.md` location per mode.

## Task 2 — skills

1. `skills/project-log/SKILL.md`: three new modes (discovery with /ingest boundary routing +
   chain question; meeting with extraction; release-notes with the never-invent rule,
   window/audience handling, confirm-gated write). Update frontmatter description +
   argument-hint.
2. `skills/work-journal/SKILL.md`: prep mode (read-only), argument-hint update.

## Task 3 — docs, version, ship

1. README feature map rows (`/project-log`, `/work-journal`); GUIDE daily-workflow bullets.
2. plugin.json → 0.29.0. Validator + full suite. PR → green CI → squash-merge → pull →
   plugin update.
3. Close-out: update the tracking-skills-roundout idea (Shipped line; remaining = portfolio
   mode only — idea stays, demoted note) or ship-close if nothing else remains except the
   blocked portfolio mode (keep the idea, re-scoped to that). Resolve the action record.
