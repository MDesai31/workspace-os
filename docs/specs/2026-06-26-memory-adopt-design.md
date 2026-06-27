# memory-adopt — adopt a repo's existing docs into `docs/memory/`

- **Status:** approved (design); ready for implementation planning
- **Date:** 2026-06-26
- **Slice:** first slice of the `adoption-import` idea (follows SP2 memory layer)
- **Scope (this slice):** free-form docs + CLAUDE.md reference extraction → `docs/memory/`.
- **Deferred to later sub-slices:** foreign memory-format conversion (top-level `memory/`, a wiki); prior roadmap/TODO → `docs/project-tracking/`.

## 1. Purpose

Repos adopting workspace-os usually **already have documentation**. Everything built so far is
greenfield-only: `/project-init` refuses if the dirs exist, and `/ingest` authors one new fact at
a time. `/memory-adopt` is the **opt-in entry for a non-empty repo** — it reshapes pre-existing
knowledge docs into `docs/memory/`, in workspace-os style.

**Passive default unchanged:** `/project-init` stays greenfield; nothing auto-touches existing
docs. Adoption is a **deliberate, confirmed** action — the explicit exception to SP2's
"never auto-migrate existing docs" rule.

## 2. Workflow — propose → confirm → apply

1. **Bootstrap if needed.** If `docs/memory/` is absent, scaffold it exactly as `/project-init`'s
   memory step does: stamp `templates/memory/MEMORY.md` → `docs/memory/MEMORY.md`, add
   `@docs/memory/MEMORY.md` to the repo's CLAUDE.md, and add `docs/memory/MEMORY.md merge=union`
   to `.gitattributes`. (Adoption is often a repo's first memory action.)
2. **Scan candidates.** Glob `README*`, `docs/**/*.md`, common `NOTES`/design docs, and
   `CLAUDE.md`. **Exclude** `docs/memory/` and `docs/project-tracking/`. An optional argument
   narrows the scan to a path/glob. Show the candidate list.
3. **Classify** each chunk through the gates in `conventions/memory.md` (codebase-knowledge →
   knowledge-vs-state → CLAUDE.md boundary test). See §4.
4. **Propose one batch** (a table the user reviews):
   - per free-form source → proposed facts (`slug`, `type`, one-line description);
   - for CLAUDE.md → the lines to extract-to-memory **and** the proposed trim;
   - what **stays** (imperatives) and what's **skipped** (work-state / not-knowledge / about-the-person), each with a one-line rationale tied to the gate that decided it.
5. **Confirm.** User approves / edits / drops items. Nothing is written before this.
6. **Apply.** Write schema-valid, secret-scanned fact files + append index lines to `MEMORY.md`;
   remove only the **approved** CLAUDE.md trim lines. **Free-form source docs are read-only** —
   READMEs and design docs are never modified or deleted.
7. **Report.** What was created, the CLAUDE.md trim applied (if any), and what was skipped + why.
   Do **not** commit — leave changes staged-ready.

## 3. Granularity

Model judgment: a source yields 0, 1, or N facts. Split a multi-topic doc into per-topic facts;
skip trivia. Each fact gets a clean kebab `slug` (with `name:` == filename stem), a `type`, and a
one-line `description`. All proposed in the batch; the user adjusts before apply.

## 4. Routing = the existing gates (no new rules)

Adoption is a **bulk application of `conventions/memory.md`'s gates**, run per chunk:

| Chunk is… | Routes to |
|---|---|
| durable codebase/domain knowledge | a `docs/memory/` fact (`domain` / `convention` / `reference`) |
| costly-if-unseen imperative ("how to work here") | **stays in CLAUDE.md** (and, if currently elsewhere, is left where it is) |
| work-state (a goal / status / TODO) | **skip** — note "belongs in tracking (`ideas.md`/`action-items.md`)" |
| about the person, not the codebase | **skip** |

The CLAUDE.md **trim** removes only lines that pass *as memory* (i.e. NOT costly-if-unseen) and
only with explicit approval; imperatives are never trimmed. A short **"Adopting existing docs
(`/memory-adopt`)"** subsection is added to `conventions/memory.md` documenting candidate sources,
this per-chunk routing, the trim rule, and idempotency. The skill references it; it does not
restate rules.

## 5. Safety / idempotency

- **Secret scan** every proposed fact; never write secrets into memory (repos may be public — e.g.
  klapp). The warn-only secret-guard hook also fires on the writes.
- **Idempotent re-run.** Before proposing, read existing `docs/memory/`; if a proposed fact's slug
  already exists or its content is clearly already present, mark it "already adopted — skip." A
  second run on an already-adopted repo proposes ~nothing. (Model-judgment dedup; no marker file.)
- **CLAUDE.md edits** preserve file structure (remove only the approved lines; don't reflow or
  mangle); when unsure whether a line is reference vs imperative, leave it in CLAUDE.md.
- **Free-form docs are never modified.** Only CLAUDE.md may be edited, and only its approved trim.
- **No auto-commit.**

## 6. Files

- **Create** `skills/memory-adopt/SKILL.md` — model-interpreted; frontmatter `user-invocable: true`,
  `disable-model-invocation: true`, `allowed-tools: Read, Write, Edit, Bash, Glob, Grep`, optional
  `argument-hint` (a path/glob to limit the scan). References `conventions/memory.md`; bootstraps
  `docs/memory/` from `templates/memory/MEMORY.md` when absent (mirrors `/project-init`'s memory step).
- **Modify** `conventions/memory.md` — add the "Adopting existing docs (`/memory-adopt`)" subsection.
- **Finalize** — mention `/memory-adopt` in README/ARCHITECTURE/PORTABILITY; plugin version bump.

## 7. Non-goals (this slice)

- Foreign memory-format conversion (top-level `memory/`, a wiki) → workspace-os schema.
- Roadmap / TODO / issues → `docs/project-tracking/` adoption (its own skill, into tracking).
- Editing source docs other than the approved CLAUDE.md trim. No auto-commit.

## 8. Success criteria

- In a repo with a `README` + an overgrown `CLAUDE.md` (mixed imperative + reference), `/memory-adopt`
  proposes a batch, and on approval: `docs/memory/` is populated with schema-valid, indexed facts;
  CLAUDE.md is trimmed of exactly the approved reference lines; the README is untouched.
- `/memory-lint` passes on the result.
- A **re-run** proposes ~nothing (idempotent).
- A planted secret in a source is **flagged, not written**.
- An imperative line ("import X from Y, not Z") is correctly **kept** in CLAUDE.md, not moved.
- If `docs/memory/` was absent, it was scaffolded (index + the `@docs/memory/MEMORY.md` import + gitattributes).

## 9. Testing modality

`/memory-adopt` is a model-interpreted markdown skill (no pytest). Verify via (1) **structural
lint** — frontmatter + references `conventions/memory.md` + names the gates; and (2) **scratch-repo
dogfood** — seed a repo with a README (multi-topic) + a CLAUDE.md mixing imperative and reference
lines, run the documented steps, and assert: facts created (schema-valid, indexed), CLAUDE.md
trimmed of the reference lines only (imperatives retained), README unmodified, secret refused,
re-run idempotent.
