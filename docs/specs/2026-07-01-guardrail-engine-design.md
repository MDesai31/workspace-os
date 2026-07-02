# Guardrail engine + provenance rules — Design Spec

**Date:** 2026-07-01
**Status:** Approved design, ready for plan
**Ideas:** `hook-starter-library` + `provenance-guard`, `ideas.md`
**Relates to:** `hooks/memory-secret-guard.sh` (retired here), the global `~/.claude/hooks/guard.sh`
(secret-deny + destructive-ask), `ARCHITECTURE.md` (engine/data split), [[SP4-meta-onboarding]]
(future hooks-registry consumer)

---

## 1. Summary

A single portable **guardrail engine** (one plugin-shipped PreToolUse hook) that applies declarative,
per-repo rules to Bash commands and Edit/Write operations — emitting a hard **deny** or an advisory
**warn**. It folds the `hook-starter-library` and `provenance-guard` ideas into **one mechanism, two
rule packs**: a generic command/content guardrail, plus a provenance rules template keyed by a repo
`ip_class` tag.

This mirrors workspace-os's existing engine/data split: one central script (the engine, carried
job-to-job and updated centrally) reading per-repo, version-controlled data (`.claude/guardrails.json`).
No external-plugin dependency — the "carry the engine job-to-job" premise is exactly why an external
dependency is rejected.

**Value-add over the global `guard.sh`.** The user's machine already runs `~/.claude/hooks/guard.sh`,
which hard-denies secrets and asks on destructive commands *globally*. workspace-os does **not**
re-ship those denies. Its distinct contribution is (a) **declarative per-repo rules** and (b) the
**provenance `ip_class`** layer. Its built-in defaults are therefore **warn-only** — a portable safety
net for fresh machines where `guard.sh` does not exist, that can never conflict with `guard.sh`'s deny.

## 2. Scope

**In:**
- `hooks/guardrail.sh` — the engine: read per-repo rules, match, emit deny/warn.
- Register it in `hooks/hooks.json` on `Bash|Edit|Write`.
- Built-in warn-only universal defaults + a small set of high-confidence secret **denies**.
- Retire `hooks/memory-secret-guard.sh`; fold its secret-content check into the engine.
- `.claude/guardrails.json` schema + a shipped `templates/guardrails.json` (provenance template).
- A bash test harness + CI wiring.
- Tracking close-out: action record + decision record; move the two ideas (or their covered
  sub-slices) toward `resolved.md`.

**Out (YAGNI / deferred):**
- The PostToolUse advisory-lint template (`ruff`/`eslint`) — separate hook, separate concern; stays
  in `ideas.md` under `hook-starter-library`.
- Any `/guardrails` skill or `/project-init` change. Opting in = copying the template; the engine
  fails open without the file, so no wiring is required this slice.
- Foreign-format detection, portfolio registry, hooks-registry management ([[SP4-meta-onboarding]]).

## 3. Architecture

```
hooks/guardrail.sh   (engine — plugin, portable, updated centrally)
  ├─ reads  <repo>/.claude/guardrails.json   (data — per-repo, version-controlled)
  ├─ applies built-in warn-only defaults      (baked into the engine)
  └─ deny → exit 2 + reason on stderr  |  warn → reason on stderr, exit 0
hooks/hooks.json     ── registers guardrail.sh on Bash|Edit|Write
templates/guardrails.json ── provenance/starter template (ip_class + example rules)
```

The engine is stack- and repo-agnostic. All *rules* are data — either built-in defaults (in the
engine) or per-repo entries (in `guardrails.json`). Adding a rule never touches the engine.

## 4. Per-repo data: `.claude/guardrails.json`

```json
{
  "ip_class": "personal | employer | clean-room",
  "bash":  [ { "name": "no-raw-duckdb", "match": "duckdb\\.connect\\(", "action": "deny",
               "reason": "Use mcp__duckdb__query, not raw connections." } ],
  "write": [ { "name": "employer-tripwire", "match": "AcmeCorpInternal|acme\\.internal",
               "field": "content", "action": "warn",
               "reason": "clean-room repo: write matches an employer tripwire." } ]
}
```

- `ip_class` — optional repo tag (`personal` · `employer` · `clean-room`). Informational; surfaced
  in provenance warn messages. Does not by itself gate rules.
- `bash` rules match the command string (`tool_input.command`).
- `write` rules match either the target `path` or the `content`, per each rule's `field`
  (`"path"` | `"content"`, default `"content"`). Applies to `Edit` (`new_string`) and `Write`
  (`content`); path from `tool_input.file_path`.
- Each rule: `{ name, match (regex), action: "deny"|"warn", reason }` (+ `field` for `write`).
- `action: "deny"` → **exit code 2** with `reason` on stderr (PreToolUse blocking contract — the
  reason is surfaced to Claude). `action: "warn"` → `reason` on stderr, **exit 0** (advisory,
  non-blocking; same mechanism the current `memory-secret-guard.sh` uses).

**Fail open, always:** no per-repo file → skip per-repo rules (built-in defaults from §5 still run).
No match anywhere → exit 0. Malformed JSON or missing `jq` → emit a one-line stderr warning and skip
per-repo rules (never block a tool call on engine failure). The engine only ever *blocks* on an
explicit `deny` match; every failure path is non-blocking.

## 5. Built-in defaults (baked into the engine)

Warn-only, so they never conflict with `guard.sh`'s deny and are safe on a fresh machine:

| Default | Trigger | Action |
|---|---|---|
| secret-content | Edit/Write content matches the secret regex (lifted from `memory-secret-guard.sh`: `api[_-]?key`, `secret`, `token`, `password`, …) | **warn** |
| force-push | Bash `git push` with `--force`/`-f` to a protected branch (`main`/`master`) | **warn** |
| rm-rf-root | Bash `rm -rf` targeting at/near repo root | **warn** |

The **only built-in denies** are high-confidence secret patterns (essentially never false-positive):
`-----BEGIN [A-Z ]*PRIVATE KEY-----`, `AKIA[0-9A-Z]{16}`, `sk-[A-Za-z0-9]{20,}`. These deny on
Edit/Write content.

Rationale for warn on generic `.env`/secrets rather than deny: a hard deny bites `.env.example`
copies, editing a local `.env`, and test fixtures with fake keys. Per-repo rules may escalate any of
these to `deny` in their own `guardrails.json`.

Precedence: if any matching rule (built-in or per-repo) is a `deny`, the call is denied (exit 2 with
all matched deny reasons on stderr). Otherwise all matching `warn` reasons are printed to stderr and
the engine exits 0.

## 6. Retiring `memory-secret-guard.sh`

The existing hook warns on suspected secrets in `docs/memory/` writes only. Its content regex becomes
the engine's warn-only **secret-content** default, **broadened to all Edit/Write** (not just
`docs/memory/`). This is a deliberate behavior change, not a silent cleanup:

- Delete `hooks/memory-secret-guard.sh`.
- Replace its entry in `hooks/hooks.json` with the `guardrail.sh` registration (now on
  `Bash|Edit|Write`, previously `Edit|Write`).
- The docs/memory-specific message becomes the generic secret-content warning.

## 7. Provenance rules pack

Ships as `templates/guardrails.json` — a starter/provenance template a repo copies to
`.claude/guardrails.json` and fills in:

- The `ip_class` field (with a comment explaining `personal` · `employer` · `clean-room`).
- Commented example `write` rules for cross-boundary tripwires (employer names, internal hostnames,
  project codenames) — **user-provided per repo**, because regex cannot detect "IP leakage" in the
  abstract. The engine's contribution is the declarative home + the matching + surfacing `ip_class`
  in the warn message.
- A commented example `bash` rule (the OA `duckdb.connect(` → `mcp__duckdb__query` redirect) showing
  the generic "use the sanctioned path, not the raw one" pattern.

## 8. Changes by file

- **`hooks/guardrail.sh`** — new engine (bash + jq). Reads stdin JSON, dispatches by tool
  (`Bash` vs `Edit`/`Write`), applies built-in defaults + per-repo rules, emits deny/warn JSON.
- **`hooks/hooks.json`** — replace the `memory-secret-guard.sh` entry with `guardrail.sh` on
  `Bash|Edit|Write`.
- **`hooks/memory-secret-guard.sh`** — **deleted**.
- **`templates/guardrails.json`** — new provenance/starter template (all rules commented/inert so a
  copied file is a no-op until edited).
- **`tests/`** (new) — bash harness: feed JSON on stdin, assert exit code + emitted decision for each
  built-in default, a per-repo `deny`, a per-repo `warn`, fail-open (no file / malformed / no match).
- **`.github/workflows/ci.yml`** — run the test harness (and keep `validate-plugin.py`).
- **`README.md` / `ARCHITECTURE.md`** — document the guardrail layer + `.claude/guardrails.json`
  opt-in (short; the engine fails open so it's opt-in by copying the template).
- **`docs/project-tracking/`** — on completion: action record, decision record
  (one-engine-two-packs + warn-only-vs-guard.sh + retire memory-secret-guard), update the two ideas.

## 9. Verification

- `scripts/validate-plugin.py` passes.
- Test harness green for: each built-in default fires with the right action; high-confidence secret
  denies block; per-repo `deny` blocks and `warn` injects context; fail-open on no-file / malformed /
  no-match; `Bash` vs `Edit`/`Write` dispatch and `field: path` vs `content`.
- Manual reasoning check: the OA `duckdb.connect(` rule expressed in `guardrails.json` reproduces the
  behavior of OA's current bespoke guardrail hook.
- Confirm no double-deny with `guard.sh`: workspace-os built-ins are warn-only except the
  high-confidence secret patterns (which `guard.sh` already denies — a redundant deny is harmless; a
  *conflicting* decision is what we avoid, and warn never conflicts).

## 10. Open questions

None. Decisions resolved during brainstorming:
mechanism = one engine, two rule packs; built-in defaults = warn-only (portable net, no conflict with
`guard.sh`); `.env`/secrets = warn, deny only high-confidence patterns; `memory-secret-guard.sh` =
retired into the engine; PostToolUse lint + `/guardrails` skill + `project-init` wiring = deferred.
