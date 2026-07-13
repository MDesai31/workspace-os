# PostToolUse advisory-lint hook — Design Spec

**Date:** 2026-07-13
**Status:** Approved design, ready for plan
**Idea:** `hook-starter-library` (remaining sub-slice — closes the idea), `ideas.md`
**Relates to:** `hooks/guardrail.sh` (PreToolUse sibling — same engine/data split, this is the
PostToolUse counterpart), `docs/specs/2026-07-01-guardrail-engine-design.md` (deferred this hook
explicitly), `ARCHITECTURE.md` (engine/data split), `conventions/data-root.md` (sidecar fallback)

---

## 1. Summary

A second portable hook — an **advisory-lint engine** (one plugin-shipped PostToolUse hook) that runs
a repo-declared linter on the file that was just edited and feeds any diagnostics back to Claude as
`additionalContext` ("fix if quick"). Clean result → silent.

It is the PostToolUse counterpart to `guardrail.sh` and reuses the same **engine/data split**: one
central script (the engine, carried job-to-job, updated centrally) reads per-repo, version-controlled
data (`.claude/lint.json`). The engine hardcodes no linter — the file-glob → command mapping is all
data, so it is language-parameterized (`ruff` for Python, `eslint` for JS/TS, or anything else a repo
declares).

**Why a separate hook, not a fold into `guardrail.sh`.** The guardrail is PreToolUse (it inspects a
tool call *before* it runs, to deny/warn). Linting must run *after* the edit lands on disk. Different
event, different timing — they cannot share one script.

**Why the channel diverges from the guardrail.** The guardrail emits `systemMessage` (a user-facing
warning) and deliberately avoids `additionalContext` so routine edits don't pollute Claude's context.
The lint hook is the opposite case by design: its output exists precisely for **Claude to act on**, so
`additionalContext` is the correct channel. The two hooks make opposite channel choices for the same
reason — match the channel to the intended reader (user vs model).

## 2. Scope

**In:**
- `hooks/lint.sh` — the engine: resolve config, match the edited file's path, run the linter, inject
  diagnostics or stay silent.
- Register it in `hooks/hooks.json` on `PostToolUse` for `Edit|Write|MultiEdit`.
- `.claude/lint.json` schema + a shipped `templates/lint.json` (inert until edited).
- Sidecar config fallback (in-repo first, then `_meta/<repo>/lint.json`), matching the guardrail.
- A bash test harness (stub fixture linter) + CI wiring.
- Docs: `ARCHITECTURE.md` + `README.md` gain the lint layer. Version bump to v0.13.0.
- Tracking close-out: action record + decision record; mark `hook-starter-library` COMPLETE.

**Out (YAGNI / deferred):**
- Built-in default linters baked into the engine — unlike the guardrail's warn-only defaults, a linter
  *executes external tooling* that may not be installed and is repo-specific, so nothing runs until a
  repo opts in.
- Diff-scoped diagnostics (only lines the edit touched). Whole edited file is the chosen behavior.
- Auto-detection of linters from `pyproject.toml`/`eslintrc`. Opt-in is explicit config only.
- `/project-init` wiring and any `/lint` skill. Opting in = copying the template; the engine fails open
  without the file, so no wiring is required this slice.

## 3. Architecture

```
hooks/lint.sh   (engine — plugin, portable, updated centrally)
  ├─ reads  <repo>/.claude/lint.json          (data — per-repo, version-controlled)
  │         └─ sidecar fallback: _meta/<repo>/lint.json   (conventions/data-root.md)
  ├─ lints the EDITED FILE ON DISK  (PostToolUse fires after the edit is applied)
  └─ non-empty linter output → additionalContext (under hookSpecificOutput) ; clean → silent
hooks/hooks.json     ── registers lint.sh on PostToolUse Edit|Write|MultiEdit
templates/lint.json  ── starter template (linters: [] + commented examples; a copied file is a no-op)
```

The engine is stack- and repo-agnostic. All linter choices are data — per-repo entries in
`lint.json`. Adding or changing a linter never touches the engine.

## 4. Per-repo data: `.claude/lint.json`

```json
{
  "_comment": "workspace-os lint rules for THIS repo. Copy to .claude/lint.json and edit.",
  "linters": [
    { "name": "python", "match": "\\.py$",            "command": "ruff check" },
    { "name": "js",     "match": "\\.(js|ts|jsx|tsx)$", "command": "eslint" }
  ]
}
```

- A separate file from `.claude/guardrails.json`: PreToolUse security-blocking and PostToolUse
  quality-advice are different concerns with different lifecycles; one file per concern keeps each
  readable and independently editable.
- `linters` is an ordered array. Each entry: `{ name, match (regex on the file path), command }`.
- For the edited file's path, **every** entry whose `match` matches runs, in array order; their
  outputs concatenate. (A typical file matches exactly one.)
- The linter is invoked as `<command> <file_path>` (e.g. `ruff check /path/to/x.py`). The command
  string may include flags; the file path is appended as the final argument.
- The template ships with `linters: []` plus a commented `_examples` block, so a copied-but-unedited
  file lints nothing.

## 5. Engine behavior (`hooks/lint.sh`)

1. Read stdin JSON. `command -v jq` absent → exit 0 (can't parse → fail open).
2. `file_path` = `tool_input.file_path`. Empty → exit 0. Normalize a forward-slash view of the path
   for matching (Windows `file_path` is backslashed — the guardrail's `tr '\\' '/'` lesson).
3. Resolve config (same pattern as `guardrail.sh` §config resolution):
   - `root` = `git rev-parse --show-toplevel`, else `CLAUDE_PROJECT_DIR`/`PWD`.
   - `config` = `<root>/.claude/lint.json`.
   - Sidecar fallback: if that file is absent and `resolve-data-root.sh` reports `mode=sidecar`, use
     `<data_root>/lint.json`.
   - No readable/valid config → exit 0.
4. For each matching `linters[]` entry, run `<command> <file_path>`, capturing combined stdout+stderr
   and the exit code.
   - **Linter not found (exit 127) → skip silently** (fail open — the jq/PATH lesson; a repo that
     declares `ruff` on a machine without `ruff` gets no noise).
   - Otherwise, if the captured output is **non-empty**, collect it (prefixed with the linter `name`).
   - Empty output → contributes nothing (clean file → silent).
5. If any collected output exists, emit it as `additionalContext`; else exit 0 with no output.

**Output contract (CONFIRMED 2026-07-13 against the Claude Code hooks docs).** PostToolUse
additional-context output nests under `hookSpecificOutput`, and `hookEventName` is **required** and
must equal `"PostToolUse"`:

```json
{ "hookSpecificOutput": { "hookEventName": "PostToolUse", "additionalContext": "<diagnostics>" } }
```

Confirmed facts the engine relies on: `additionalContext` is delivered to the **model** (wrapped as a
system reminder at the tool result's position — Claude acts on it), whereas top-level `systemMessage`
is user-facing only; **exit 0** is the non-blocking success code (stdout JSON is parsed); **stdout must
be JSON-only** on exit 0 (invalid/extra output → non-blocking error, JSON ignored); and
`additionalContext` is **capped at 10,000 characters**. The engine therefore truncates its report to a
safe margin (~9,500 chars) with a truncation marker before emitting. A live smoke-test is still listed
in §9 (a diff cannot prove end-to-end injection), but the shape is no longer an open risk.

**Fail open everywhere.** No jq, no `file_path`, no config, malformed JSON, linter absent or crashing
→ exit 0, no output. The hook never blocks or disrupts a session; PostToolUse cannot deny anyway, and
a lint engine failure must be invisible.

## 6. Accepted tradeoffs (design decisions, not gaps)

- **Whole edited file, any diagnostic** (not diff-scoped). Simplest, matches the OA hook this
  generalizes. Known cost: diagnostics may include pre-existing issues Claude did not introduce, or
  transient errors during a multi-edit sequence (e.g. a name defined in a later edit). Accepted for
  simplicity; diff-scoping is a deferred future refinement.
- **Synchronous per-edit lint adds latency.** `ruff` is ~milliseconds; heavier linters (`eslint`,
  type-checkers) cost more on every edit. The repo opts in knowingly by declaring the command.
- **No built-in linters.** The engine is inert until a repo declares one — the opposite of the
  guardrail's baked-in warn defaults, because running an uninstalled/irrelevant linter globally is
  worse than doing nothing.

## 7. Matcher: `Edit|Write|MultiEdit`

The hook's purpose is to lint files after they change. `Edit`, `Write`, and `MultiEdit` all change a
file and all carry `tool_input.file_path`; `MultiEdit` is included so multi-hunk edits are not a blind
spot. (The guardrail matches `Bash|Edit|Write`; its omission of `MultiEdit` is a separate pre-existing
concern and is not touched here.) Because PostToolUse fires after the write, the hook reads the file
from disk and never needs `content`/`new_string` from `tool_input`.

## 8. Changes by file

- **`hooks/lint.sh`** — new engine (bash + jq). Reads stdin JSON, resolves config (in-repo → sidecar),
  matches the file path against `linters[]`, runs each match, emits `additionalContext` or nothing.
- **`hooks/hooks.json`** — add a `PostToolUse` entry matching `Edit|Write|MultiEdit` →
  `${CLAUDE_PLUGIN_ROOT}/hooks/lint.sh`. (Leave the existing PreToolUse/SessionStart entries intact.)
- **`templates/lint.json`** — new starter template: `linters: []` + a commented `_examples` block
  (ruff + eslint), so a copied file is a no-op until edited.
- **`tests/test-lint.sh`** (new) + fixtures — a stub linter script (`echo` + configurable exit code)
  so tests need no real ruff/eslint. Cases: inject-on-nonempty-output; silent-on-clean (exit 0, no
  output); silent-on-missing-linter (exit 127); glob match vs no-match; multiple matches concatenate;
  fail-open on malformed/absent config; sidecar-fallback config resolution.
- **`.github/workflows/ci.yml`** — run `tests/test-lint.sh` alongside the existing harnesses.
- **`ARCHITECTURE.md`** — add `lint.sh` to the "how the pieces relate" map and a short bullet on the
  lint layer (PostToolUse, additionalContext, opt-in via `.claude/lint.json`, fails open).
- **`README.md`** — document the lint hook + `.claude/lint.json` opt-in (short; opt-in by copying the
  template).
- **`.claude-plugin/plugin.json`** — version bump to `0.13.0`.
- **`docs/project-tracking/`** — on completion: action record; decision record (separate hook +
  additionalContext-not-systemMessage + no-built-in-linters + separate-config-file); update
  `hook-starter-library` in `ideas.md` to mark this sub-slice shipped → idea COMPLETE.

## 9. Verification

- `scripts/validate-plugin.py` passes; `hooks/hooks.json` remains valid JSON with all prior entries.
- `tests/test-lint.sh` green for every case in §8.
- **Live check (not just the harness):** in a scratch repo with a `.claude/lint.json` declaring a
  trivially-failing linter, perform a real `Edit` and confirm the diagnostics actually reach Claude via
  the PostToolUse `additionalContext` channel (proves §5's output contract), and that a clean file
  produces no injection.
- Confirm fail-open: rename the declared linter so it is not on PATH → the edit completes with no
  injection and no error surfaced.

## 10. Open questions

None. Decisions resolved during brainstorming:
- opt-in model = **explicit per-repo `.claude/lint.json`** (not auto-detect, not hybrid);
- injection rule = **whole edited file, any diagnostic** (not diff-scoped);
- channel = **`additionalContext`** (diverges from the guardrail's `systemMessage` — output is for the
  model to act on); exact PostToolUse nesting confirmed against the docs (see §5), no longer open;
- **no built-in linters** (pure opt-in); separate config file from `guardrails.json`; separate hook
  from `guardrail.sh` (PostToolUse ≠ PreToolUse).
