# Packaging sweep — design (2026-06-28)

## Summary

Close the three open packaging action items, reducing install friction and adding a structural
CI gate:

- `A-20260625-visibility-decision` → **make the repo public**
- `A-20260625-default-branch-main` → **rename default branch `master` → `main`**
- `A-20260625-meta-ci` → **add a minimal validation CI** gated by branch protection on `main`

## Decisions (from brainstorm)

- **Public** — workspace-os is a generic, portable plugin with no proprietary content or secrets;
  public gives frictionless install (`/plugin marketplace add MDesai31/workspace-os`, no auth/SSH
  dance — the friction hit on 2026-06-28). klapp is already public.
- **meta-CI scope = minimal** — manifests + skill frontmatter only. Tracking-*record* schema
  linting (the `- Status: done` drift) is explicitly OUT — that's a separate future validator
  (`tracking-lint`, parallel to `/memory-lint`).
- **Branch protection on `main` requires the CI check** — mirrors the OA repo ("CI gates PRs into
  main"). CI is a real gate, not advisory. Accepts minor solo-repo friction (own PRs wait for green).

## 1. Visibility → public

- **Pre-flight secret scan** of the tracked tree before flipping (public exposes all history).
  Expect none; verify anyway. If anything is found, STOP and surface it.
- `gh repo edit MDesai31/workspace-os --visibility public --accept-visibility-change-consequences`.

## 2. `master` → `main`

- `git branch -m master main` → `git push -u origin main` → `gh repo edit --default-branch main`
  → `git push origin --delete master`.
- Update in-repo `master` references (README / ARCHITECTURE / PORTABILITY_NOTES / conventions, as
  found by grep) and the auto-memory `project_workspace_os` / git-auth lines.
- The local path-based plugin marketplace is unaffected; a future *remote* marketplace add tracks
  `main` automatically.

## 3. meta-CI — `.github/workflows/ci.yml`

- **Triggers:** `pull_request` targeting `main`, and `push` to `main`.
- **Permissions:** `contents: read` (least privilege).
- **Actions:** SHA-pinned (e.g. `actions/checkout` pinned to a commit SHA, not a tag).
- **Validator:** a single `python3` script (preinstalled on `ubuntu-latest`; the repo has no JS/Py
  runtime of its own) that fails non-zero on any violation:
  1. `.claude-plugin/plugin.json` parses as JSON and has `name` + `version`.
  2. `.claude-plugin/marketplace.json` parses as JSON and has `name` + `plugins`.
  3. Every `skills/*/SKILL.md` has a YAML frontmatter block with non-empty `name` + `description`.
- The script lives in the repo (e.g. `scripts/validate-plugin.py`) so it is runnable locally too.

## 4. Branch protection on `main`

- After the CI workflow has merged and run once (so the check context name exists), require the CI
  status check to pass before merge. Set via `gh api` / branch-protection endpoint.

## 5. Delivery sequence + tracking close-out

Admin ops are not file changes and do not go through a PR; file changes do.

1. Pre-flight secret scan.
2. Flip visibility → public (admin).
3. Rename `master` → `main` (admin).
4. Feature branch `packaging-sweep` off `main`: add `ci.yml` + `validate-plugin.py`, the
   `master`→`main` doc reference updates, and the tracking close-out. Open PR → `main`; the CI
   runs on its own PR (self-validating). Merge when green.
5. Add branch protection requiring the CI check.
6. Close `A-20260625-visibility-decision`, `A-20260625-default-branch-main`, `A-20260625-meta-ci`
   → `resolved.md`; log a decision if warranted; update memory (visibility + default branch).

## Out of scope

- Tracking-record schema linting (`tracking-lint`) — future.
- Any change to skills' behavior. This is packaging only.

## Verification

- `gh repo view --json visibility,defaultBranchRef` shows `public` + `main`.
- The `packaging-sweep` PR shows the CI check **passing**.
- `git ls-remote --heads origin` shows `main`, not `master`.
- Branch-protection API shows the CI check required on `main`.
- All three action items moved to `resolved.md` with commit refs.
