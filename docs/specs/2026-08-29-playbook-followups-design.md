# Playbook follow-ups: init stamp + deterministic lint — design

Date: 2026-08-29. Status: approved (backlog order approved 2026-08-29; defaults per
D-20260824-playbook-surface-before-default and house script/judgment split).
Closes the plugin-side remainder of the procedure-playbooks idea (shipped v0.24.0).

## Problem

Two follow-ups were deferred from the v0.24.0 playbooks slice:

1. `/project-init` does not stamp `playbooks/`, so the artifact class is invisible in a fresh
   repo until someone happens to run `/playbook` — unlike tracking and memory, which are
   scaffolded on day one.
2. Nothing validates a playbook file. The surfacing hook (`hooks/playbook-surface.sh`) fails
   open by design, so every authoring mistake is *silent non-surfacing*: frontmatter not
   starting at line 1, an unterminated block, an invalid ERE in `trigger-bash`/`trigger-path`
   (grep -E rejects it → the trigger never matches), or a typo'd `surface:` value (anything
   ≠ `after` silently coerces to `before`). A playbook you wrote and believe is guarding a
   procedure can be dead without any signal — the exact failure mode lint exists for.

## Design

### 1. `/project-init` stamps `playbooks/`

- New template `templates/playbooks/README.md`: two short paragraphs — what a playbook is
  (pointer to `conventions/playbooks.md` as SoT) and how to author (`/playbook`) / adopt
  (`/playbook adopt <path>`). No schema restatement.
- `/project-init` step 3 gains: create `<data_root>/playbooks/` and copy the template README
  into it. Same in both modes (playbooks are already per-tier data). Existing-dir guard: if
  `playbooks/` already exists, skip silently (same posture as the memory guard).
- Report step mentions `/playbook`.

### 2. `scripts/playbook-lint.sh` + `/memory-lint` playbook pass

New fail-loud script (house style: bash + grep/sed, no framework), mirroring the hook's exact
parsing dialect so lint-clean ⇒ hook-parseable:

    bash scripts/playbook-lint.sh <playbooks-dir> [<playbooks-dir>...]

Per `*.md` file (README.md excluded — it is scaffold, not a playbook):

- FAIL: no frontmatter at line 1, or unterminated block (the hook would skip / mis-parse it).
- FAIL: missing `name` or `description`; `name` ≠ filename stem (matches memory-file rules).
- FAIL: `trigger-bash` / `trigger-path` value `grep -E` rejects (silently-dead trigger).
- FAIL: `surface` present but not `before`/`after` (silent coercion to `before` masks intent).
- NOTE (non-fatal): no trigger at all (docs-only playbook — legal, worth knowing);
  body > 300 lines (surfaces as read-path instruction by design).

Exit 1 iff any FAIL; per-file `PASS`/`FAIL` lines plus a summary. A missing or empty dir is a
one-line note, exit 0 (nothing to lint is not an error).

`/memory-lint` gains a Step 1c running it on `<data_root>/playbooks` (and, sidecar, the
workspace tier `<workspace_root>/playbooks`), reported in the merged summary. The skill stays
read-only; mechanical fixes are offered, never applied to bodies.

## Non-goals

- UDX's five convention docs adopt via `/playbook adopt` on that machine — usage, not plugin work.
- No playbook checks in `memory_graph.py` (python memory tooling stays memory-scoped; the
  playbook dialect is bash/ERE and must match the hook's engine).
- No auto-fix mode; no validator-gate on the plugin's own repo (it ships no playbooks).

## Verification

- `tests/test-playbook-lint.sh`: tmpdir fixtures for every FAIL/NOTE class plus a clean
  playbook; red before implementation, green after.
- Full suite + `validate-plugin.py` clean; docs mention the new surface (doc-freshness gate).
