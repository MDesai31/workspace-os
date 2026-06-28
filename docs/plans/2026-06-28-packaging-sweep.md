# Packaging Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `MDesai31/workspace-os`'s default branch `master`→`main` and add a minimal validation CI gated by branch protection — closing the three open packaging action items (visibility resolved as: stay private, reassess later).

**Architecture:** Two repo-admin operations (branch rename, branch protection) run directly in the main session because they are stateful and need owner auth. The one code change (a dependency-free `python3` manifest/skill validator + its GitHub Actions workflow) plus the decision log and tracking close-out ride a single `packaging-sweep` PR into `main`, so the CI validates itself before merge.

**Tech Stack:** GitHub Actions (one SHA-pinned action: `actions/checkout`), bare `python3` (no third-party deps), `gh` CLI + GitHub MCP for admin ops.

## Global Constraints

- Active gh account MUST be `MDesai31` for all git/gh ops (`gh auth switch --user MDesai31`); it is the repo owner. The default `ManthanDesai-dev` lacks access.
- meta-CI scope is **minimal**: manifests + skill frontmatter only. NO tracking-record linting (future `tracking-lint`).
- CI workflow: `permissions: contents: read`; every `uses:` action pinned to a full commit SHA, not a tag.
- Validator script is **dependency-free** — runs on a bare `python3` (no pip install, no `setup-python`), so it is runnable locally and in CI identically.
- No changes to any skill's behavior. Packaging only.
- Repo stays **private** (user decision 2026-06-28; reassess later). No visibility flip; the decision is recorded as `D-20260628-stay-private` in Task 2's PR.

---

> **Visibility:** No task. The repo stays private (user decision 2026-06-28, reassess later). The decision is recorded as `D-20260628-stay-private` and the action item resolved in Task 2's PR — no admin op here.

### Task 1: Rename default branch `master` → `main`

**Files:** none (repo-admin op).

- [ ] **Step 1: Confirm active account + up-to-date master**

Run:
```bash
gh auth switch --user MDesai31
cd /home/manthan01/Documents/Codebase/workspace-os
git checkout master && git pull --ff-only origin master
```
Expected: account is MDesai31; local `master` up to date at the latest commit (the spec commit `cba91a1` or later).

- [ ] **Step 2: Rename locally and push `main`**

Run:
```bash
git branch -m master main
git push -u origin main
```
Expected: `main` created on origin, local `main` tracking `origin/main`.

- [ ] **Step 3: Set the remote default branch to `main`**

Run: `gh repo edit MDesai31/workspace-os --default-branch main`
Expected: no error.

- [ ] **Step 4: Delete the old remote `master`**

Run: `git push origin --delete master`
Expected: `- [deleted]  master`

- [ ] **Step 5: Verify**

Run:
```bash
git ls-remote --heads origin
gh repo view MDesai31/workspace-os --json defaultBranchRef --jq .defaultBranchRef.name
```
Expected: only `refs/heads/main` listed; default branch = `main`.

(No commit — admin op. Note: there are NO substantive `master` references in README/ARCHITECTURE/PORTABILITY/conventions — verified by `git grep`. The only mentions are the action-item text, closed in Task 3, and the spec, which correctly describes the rename and is left as-is.)

---

### Task 2: meta-CI (validator + workflow + decision + tracking close-out) via `packaging-sweep` PR

**Files:**
- Create: `scripts/validate-plugin.py`
- Create: `.github/workflows/ci.yml`
- Modify: `docs/project-tracking/decisions-log.md` (append `D-20260628-stay-private`)
- Modify: `docs/project-tracking/action-items.md` (remove the 3 closed records)
- Modify: `docs/project-tracking/resolved.md` (append the 3 closed records)
- Modify: `docs/project-tracking/ideas.md` (mark packaging items shipped, if referenced)

**Interfaces:**
- Produces: `scripts/validate-plugin.py` — exits `0` if `.claude-plugin/plugin.json` (keys `name`,`version`) and `.claude-plugin/marketplace.json` (keys `name`,`plugins`) parse and every `skills/*/SKILL.md` has non-empty frontmatter `name`+`description`; else prints violations and exits `1`. The workflow calls it as `python3 scripts/validate-plugin.py`.

- [ ] **Step 1: Create the feature branch**

Run:
```bash
cd /home/manthan01/Documents/Codebase/workspace-os
git checkout -b packaging-sweep main
```

- [ ] **Step 2: Write the validator**

Create `scripts/validate-plugin.py`:
```python
#!/usr/bin/env python3
"""Structural validation for the workspace-os plugin manifests and skills.

Exits non-zero (listing every violation) if anything is malformed. Dependency-free:
runs identically on a bare python3 locally and in CI."""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
errors = []


def check_json(rel_path, required_keys):
    p = REPO / rel_path
    if not p.exists():
        errors.append(f"{rel_path}: file missing")
        return
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{rel_path}: invalid JSON ({e})")
        return
    for key in required_keys:
        if key not in data:
            errors.append(f"{rel_path}: missing required key '{key}'")


def frontmatter_fields(text):
    """Return {key: value} for top-level `key: value` lines in the leading
    `---`-delimited frontmatter block, or None if the block is absent/unterminated."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        if ":" in line and not line.startswith((" ", "\t")):
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    return None  # no closing delimiter


def check_skill(skill_md):
    rel = skill_md.relative_to(REPO)
    fields = frontmatter_fields(skill_md.read_text())
    if fields is None:
        errors.append(f"{rel}: missing or unterminated YAML frontmatter")
        return
    for field in ("name", "description"):
        if not fields.get(field):
            errors.append(f"{rel}: frontmatter missing non-empty '{field}'")


check_json(".claude-plugin/plugin.json", ["name", "version"])
check_json(".claude-plugin/marketplace.json", ["name", "plugins"])

skills = sorted((REPO / "skills").glob("*/SKILL.md"))
for skill_md in skills:
    check_skill(skill_md)

if errors:
    print("Plugin validation FAILED:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print(f"Plugin validation passed ({len(skills)} skills checked).")
```

- [ ] **Step 3: Run the validator against the real repo (positive test)**

Run: `python3 scripts/validate-plugin.py`
Expected: `Plugin validation passed (8 skills checked).` and exit code 0.

- [ ] **Step 4: Negative test — break, confirm failure, restore**

Run:
```bash
cp .claude-plugin/plugin.json /tmp/plugin.json.bak
python3 - <<'PY'
import json,pathlib
p=pathlib.Path(".claude-plugin/plugin.json"); d=json.loads(p.read_text()); d.pop("version",None); p.write_text(json.dumps(d,indent=2))
PY
python3 scripts/validate-plugin.py; echo "exit=$?"
cp /tmp/plugin.json.bak .claude-plugin/plugin.json
python3 scripts/validate-plugin.py; echo "restored exit=$?"
```
Expected: first run prints `missing required key 'version'` with `exit=1`; after restore, `restored exit=0`. (No test framework is added — the repo has no runtime; this break/restore + the CI run on the PR are the validator's tests, per YAGNI.)

- [ ] **Step 5: Resolve the pinned SHA for `actions/checkout`**

Run: `gh api repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha + " " + .object.type'`
If `.object.type` is `tag` (annotated), dereference:
`gh api repos/actions/checkout/git/tags/<SHA-from-above> --jq .object.sha`
Record the resulting **commit** SHA as `<CHECKOUT_SHA>` for the next step.

- [ ] **Step 6: Create the workflow**

Create `.github/workflows/ci.yml` (substitute `<CHECKOUT_SHA>` from Step 5):
```yaml
name: validate
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<CHECKOUT_SHA> # v4
      - run: python3 scripts/validate-plugin.py
```

- [ ] **Step 7: Decision log + tracking close-out**

In `docs/project-tracking/decisions-log.md`, append (match the existing `D-` record format — Workstream, Created, Rationale, Spawns):
```markdown
### D-20260628-stay-private — keep workspace-os private for now
- Workstream: packaging
- Created: 2026-06-28
- Rationale: Public would give frictionless install (no auth/SSH dance), but the user prefers to keep the repo private and reassess later. Public is read+install-for-anyone / write-for-owner-only and exposes all git history permanently; the user wants to weigh that deliberately, not as a side effect of the packaging sweep. The branch rename and CI are independent of visibility and proceed regardless. Reversal is one `gh repo edit --visibility public` away.
- Spawns: none
```

In `docs/project-tracking/action-items.md`, remove the three records `A-20260625-default-branch-main`, `A-20260625-visibility-decision`, `A-20260625-meta-ci` (and `A-20260625-meta-ci`'s body). If that leaves the file empty of records, restore the `_No open items yet._` placeholder.

In `docs/project-tracking/resolved.md`, append (use the exact field order/format of existing resolved records — Workstream, Status, Created, Completed, Commit):
```markdown
### A-20260625-visibility-decision — decide repo visibility
- Workstream: packaging
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-28
- Commit: decided private — see D-20260628-stay-private

### A-20260625-default-branch-main — rename default branch master→main
- Workstream: packaging
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-28
- Commit: n/a (repo-admin op; see PR #<N>)

### A-20260625-meta-ci — add validation CI to workspace-os
- Workstream: packaging
- Status: done
- Created: 2026-06-25
- Completed: 2026-06-28
- Commit: PR #<N>
```
(Replace `#<N>` with the real PR number after Step 9; reference the PR number — NOT a commit SHA of the commit that contains this record, which can't self-reference. Lesson from the tracking-adopt T3 amend-pin bug.)

If `docs/project-tracking/ideas.md` has a packaging entry, add a one-line "shipped 2026-06-28" note; otherwise skip.

- [ ] **Step 8: Commit and push the branch**

Run:
```bash
git add scripts/validate-plugin.py .github/workflows/ci.yml docs/project-tracking/
git commit -m "$(printf 'ci: add minimal plugin validation workflow + close packaging items\n\nDependency-free python3 validator (manifests parse + required keys; every\nSKILL.md has name/description frontmatter), run on PRs/pushes to main with\ncontents:read and a SHA-pinned checkout. Closes the three packaging action items.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
git push -u origin packaging-sweep
```

- [ ] **Step 9: Open the PR and watch CI**

Create the PR (base `main`) via GitHub MCP `create_pull_request`. Then poll the PR's check runs (MCP `pull_request_read` method `get_check_runs`, or `gh pr checks packaging-sweep`) until the `validate` job concludes.
Expected: the `validate` check is **success** (green). If it fails, read the job log, fix, re-push, re-check.

- [ ] **Step 10: Backfill the PR number and merge**

Edit `resolved.md` to replace `#<N>` with the real PR number; commit (`docs: pin PR ref in resolved records`) and push. Wait for CI green again, then squash-merge the PR via MCP `merge_pull_request`.

- [ ] **Step 11: Post-merge branch cleanup**

Run:
```bash
git checkout main && git pull --ff-only origin main
git branch -D packaging-sweep
git push origin --delete packaging-sweep
```

---

### Task 3: Branch protection on `main` + memory update

**Files:** none in-repo (admin op + auto-memory, which lives outside the repo).

> **Outcome (2026-06-28): Steps 1–2 BLOCKED and skipped.** Branch protection and rulesets both return `403: Upgrade to GitHub Pro or make this repository public` on a free private repo. Per `D-20260628-ci-advisory`, CI stays **advisory**. Steps 3–4 (memory + task close-out) still apply.

- [ ] **Step 1: Require the CI check on `main`**

The `validate` check has now run on `main` (the push after merge), so its context name exists. Run:
```bash
gh api -X PUT repos/MDesai31/workspace-os/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=validate' \
  -f 'enforce_admins=true' \
  -f 'required_pull_request_reviews=' \
  -f 'restrictions=' 2>&1 || echo "see note"
```
If the `-f` form rejects the nested/null fields, fall back to a JSON body:
```bash
gh api -X PUT repos/MDesai31/workspace-os/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{"required_status_checks":{"strict":true,"contexts":["validate"]},"enforce_admins":true,"required_pull_request_reviews":null,"restrictions":null}
JSON
```
Expected: 200 response with the protection object.

- [ ] **Step 2: Verify protection**

Run: `gh api repos/MDesai31/workspace-os/branches/main/protection/required_status_checks --jq '.contexts'`
Expected: `["validate"]`

- [ ] **Step 3: Update memory**

Update `MEMORY.md` + `project_workspace_os.md` + `reference_mdesai31_git_cli_auth.md`: workspace-os default branch is now **main** and meta-CI gates PRs into main; visibility **stays private** (decision `D-20260628-stay-private`, reassess later). (These are durable, cross-session facts.)

- [ ] **Step 4: Close out the tracking task**

Mark the packaging-sweep task complete in the session task list.

---

## Notes on execution model

Tasks 1 and 3 are repo-admin operations (owner-auth, stateful) — run them directly in the main session, not via a subagent. Task 2 is the only code change and self-validates through its own PR. Recommended: **inline execution** in this session.
