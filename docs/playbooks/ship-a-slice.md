---
name: ship-a-slice
description: the full spec-to-close-out ritual for shipping a workspace-os slice - the close-out half is the part everything else forgets
trigger-bash: gh pr (create|merge)
surface: before
---
# Ship a slice

The end-to-end ritual for a workspace-os feature slice. The generic middle (commit, PR,
review) is ordinary; the close-out at the end is the part with no native tooling and the
most forgettable steps - it is why this playbook exists.

## Preconditions

- On `main`, clean tree, local checkout pulled.
- The slice has an approved spec (`docs/specs/YYYY-MM-DD-<slug>-design.md`) and a plan
  (`docs/plans/YYYY-MM-DD-<slug>.md`).
- An `A-` action record is open for it (graduate the idea if one exists).

## Steps

1. Branch (`feat/<slug>`); first commit = spec + plan + the action record.
2. Build. Any new script gets a TDD'd `tests/test-*.sh` (red first), listed in
   `.github/workflows/ci.yml`. Skills point at conventions; conventions are the SoT.
3. Bump `version` in `.claude-plugin/plugin.json` (user-visible change = bump, always).
4. Verify locally: `python3 scripts/validate-plugin.py` AND the full suite
   (`for t in tests/test-*.sh; do bash "$t"; done`) - green before the PR, not after.
5. Commit + push; `gh pr create` (body ends with the generated-with line + session URL).
6. `sleep 10 && gh pr checks --watch` - foreground, once. Merge only on green:
   `gh pr merge <N> --squash --delete-branch`.
7. `git checkout main && git pull`, then
   `claude plugin update workspace-os@workspace-os` (local checkout first - the update
   snapshots the directory, not GitHub).
8. **Close-out (the forgettable half)** - all of it, in one tracking commit to main:
   - move the `A-` record to `resolved.md` with `- Commit: <sha> (PR #N, merged to main, vX.Y.Z)`;
   - append the `Closes <idea>` line to the decision record carrying the idea's reasoning;
   - remove the shipped idea from `ideas.md` (a partially shipped idea stays, with a
     Shipped line naming what remains);
   - repoint `[[wikilinks]]` to the closed idea into `<name> (shipped)` prose;
   - `python3 scripts/memory_graph.py --check --root docs/memory --tracking-root docs/project-tracking`;
   - commit, push.
9. Update session memory (the workspace-os project fact + its MEMORY.md index line).

## Verify

- CI green BEFORE the merge (never after); suite + validator green locally.
- `memory_graph: clean` on the close-out commit.
- `claude plugin update` reports the new version.
- `ideas.md` h3 count dropped by the ideas closed (no fully-shipped idea left in the queue).

## Known traps

- `gh pr checks --watch` races CI registration right after `pr create` - exit 1 "no checks
  reported". Always `sleep 10` first. NEVER background-watch CI (dead-watcher incident
  2026-08-24); foreground only.
- A plan doc written before branching shows up as an uncommitted change at push time -
  commit spec + plan as the branch's first commit (step 1), not after.
- Stacked PRs + squash-merge silently close the child PR - merge bottom-up, repoint the
  child before deleting the base branch.
- The doc-freshness gate: every new skill (`/name`) and hook filename must be mentioned in
  README.md or GUIDE.md, or the validator fails the PR.
- A fully shipped idea left in `ideas.md` keeps counting toward the open backlog and
  over-reports the tier (`/project-status`) - the queue-not-archive rule.
- Bash heredocs that themselves contain a `<<'EOF'` heredoc terminate the outer one early -
  use a distinct outer delimiter or write a script file instead.
