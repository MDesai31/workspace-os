---
name: stacked-pr-squash-merge
description: stacked PRs + squash-merge silently close the child PR here — merge bottom-up and repoint the child before deleting the base branch
type: convention
---

On this repo, a **stacked PR does not survive its base PR's squash-merge**. Observed 2026-07-05:
PR #9 (`memory-graph-vendor`, based on `guardrail-engine`) was auto-**closed** by GitHub the
moment PR #8 merged with `--squash --delete-branch` — no auto-retarget to `main`, and a closed
PR whose base branch is gone **cannot be reopened or retargeted** (a fresh PR is required; #10
superseded #9).

Why: squash-merge rewrites the base branch's commits into one new commit on `main`, so the child
branch's history is no longer contained in `main` and GitHub drops the retarget path when the
base branch is deleted.

The working sequence when a stack exists:
1. Merge the bottom PR **without** deleting its branch yet.
2. Rebase the child onto `main` (`git rebase --onto origin/main <old-base-head> <child>` — clean,
   since the squashed content equals the old base tree) and `git push --force-with-lease`.
3. Retarget the child PR to `main` (`gh pr edit N --base main`) **while it is still open**.
4. Now delete the base branch.

Also relevant: CI (`validate`) only triggers on PRs targeting `main`, so a stacked child shows
**no checks at all** until it points at `main` — run the test suites locally before relying on it.
Decision context: [[D-20260705-keystone-reposition]] (the slice this was learned on).
