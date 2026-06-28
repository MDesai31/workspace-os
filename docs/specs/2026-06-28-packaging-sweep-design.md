# Packaging sweep — design (2026-06-28)

## Summary

Close the three open packaging action items, reducing install friction and adding a structural
CI gate:

- `A-20260625-visibility-decision` → **stay private for now** (reassess public later)
- `A-20260625-default-branch-main` → **rename default branch `master` → `main`**
- `A-20260625-meta-ci` → **add a minimal validation CI** gated by branch protection on `main`

## Decisions (from brainstorm)

- **Stay private (for now)** — public would give frictionless install (no auth/SSH dance), but the
  user prefers to keep the repo private and reassess later. Installs continue to require the
  `MDesai31` active gh account. Logged as `D-20260628-stay-private`. (Reversal is easy later; the
  rename + CI below are independent of visibility.)
- **meta-CI scope = minimal** — manifests + skill frontmatter only. Tracking-*record* schema
  linting (the `- Status: done` drift) is explicitly OUT — that's a separate future validator
  (`tracking-lint`, parallel to `/memory-lint`).
- **Branch protection on `main` requires the CI check** — mirrors the OA repo ("CI gates PRs into
  main"). CI is a real gate, not advisory. Accepts minor solo-repo friction (own PRs wait for green).

## 1. Visibility → stay private

- No repo change. Record the decision (`D-20260628-stay-private`) and resolve the action item with
  a note to reassess. The secret-scan gate is dropped — it only mattered as a pre-flip safeguard
  before exposing history; the repo stays private.

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
- **Outcome (2026-06-28):** NOT applied — branch protection and rulesets both return `403: Upgrade
  to GitHub Pro or make this repository public` on a free private repo. CI is therefore **advisory**
  (runs + reports, does not block merge). See `D-20260628-ci-advisory`. Revisit if the repo goes
  public or upgrades to Pro.

## 5. Delivery sequence + tracking close-out

Admin ops are not file changes and do not go through a PR; file changes do.

1. Rename `master` → `main` (admin).
2. Feature branch `packaging-sweep` off `main`: add `ci.yml` + `validate-plugin.py`, log
   `D-20260628-stay-private`, and the tracking close-out. Open PR → `main`; the CI runs on its own
   PR (self-validating). Merge when green.
3. Add branch protection requiring the CI check.
4. Close `A-20260625-visibility-decision` (decided: private), `A-20260625-default-branch-main`,
   `A-20260625-meta-ci` → `resolved.md`; update memory (default branch + CI gate; visibility stays
   private).

## Out of scope

- Tracking-record schema linting (`tracking-lint`) — future.
- Any change to skills' behavior. This is packaging only.

## Verification

- `gh repo view --json visibility,defaultBranchRef` shows `private` + `main`.
- The `packaging-sweep` PR shows the CI check **passing**.
- `git ls-remote --heads origin` shows `main`, not `master`.
- Branch-protection API shows the CI check required on `main`.
- All three action items moved to `resolved.md` with commit refs.
