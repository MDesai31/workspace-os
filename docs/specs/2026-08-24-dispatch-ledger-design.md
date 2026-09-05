# Dispatch ledger - design

- Date: 2026-08-24
- Status: accepted (design approved; implementation pending)
- Workstream: meta

## Problem

Subagent dispatch costs are invisible until they hurt. The 2026-08 EC2 audit measured two
dispatches burning ~484k tokens re-deriving a CSV the pipeline had already written - a 0.25s
probe would have surfaced it - and noted that every number in the audit came from ad hoc probes
because the plugin has no reporting of its own. The lesson lives as CLAUDE.md prose, written
only after the cost was paid, binding only while the model chooses to obey it. Cost rules
should be derivable from data, not hindsight. The ledger is also the missing substrate under
two other captured ideas: `probe-first-dispatch-gate` (needs to know which dispatch classes
are expensive) and `agent-self-improvement` (assumes a per-agent observation log exists).

## Goals

- Log every subagent dispatch automatically: agent type, prompt/response sizes, estimated
  tokens, harness-reported usage where available, outcome flag.
- Local-only by construction: the ledger can never be committed to any repo.
- Zero session risk: pure telemetry - fail open, fast, no behavior change, no blocking.
- A minimal read-back: totals, per-agent breakdown, top-N most expensive dispatches.

## Non-goals

- No gating or blocking of dispatches (`probe-first-dispatch-gate`, later, separately —
  shipped v0.35.0 as `dispatch` rules in the guardrail engine, see
  `2026-09-04-probe-first-dispatch-gate-design.md`).
- No prompt/response TEXT in the ledger - sizes and a short description label only.
- No `/dispatch-report` skill yet; the summary script is the read surface for now.
- No cross-machine aggregation; telemetry is machine-local like the audit numbers were.

## Decisions

- **Location: user-global.** `~/.claude/workspace-os/dispatch-ledger.jsonl` - outside every
  repo by construction, so the "never ships to an employer repo" constraint holds without
  gitignore mutation or per-mode paths. Entries carry `repo` + `cwd` so per-repo analysis is a
  filter, not a file layout. (Rejected: data-root placement - commits telemetry in in-repo
  mode; hybrid - two code paths for no analytical gain.)
- **Token source: opportunistic + estimate.** The PostToolUse payload is not documented to
  carry usage data; the hook probes common field shapes and records them when present
  (`tokens`, `duration_ms` else null) and ALWAYS records `est_tokens` =
  (prompt_chars + response_chars) / 4. Estimates are labelled as such by the field name.
- **Split scripts, matching the guardrail factoring:** capture in `hooks/`, read in
  `scripts/` (hooks/guardrail.sh vs scripts/guardrails-upsert.sh precedent). Capture is
  deterministic bash+jq, not a prompt hook.

## Design

### 1. `hooks/dispatch-ledger.sh` - capture (PostToolUse, matcher `Task|Agent`)

Reads the hook JSON on stdin, appends one JSON line, exits 0 **unconditionally** - jq
missing, malformed stdin, unwritable ledger, any error: silent exit 0 (telemetry must never
break a session; same fail-open posture as every hook in this plugin). No stdout output on
success (nothing to inject into context).

Entry fields (one JSONL object):

| field | source |
|---|---|
| `ts` | `date -u +%FT%TZ` |
| `session_id` | `.session_id // ""` |
| `cwd` | `.cwd // ""` |
| `repo` | basename of `git -C <cwd> rev-parse --show-toplevel`, `""` outside a repo |
| `agent` | `.tool_input.subagent_type // .tool_input.agentType // "unknown"` |
| `desc` | `.tool_input.description // ""`, truncated to 120 chars |
| `prompt_chars` | `.tool_input.prompt \| length` (0 when absent) |
| `response_chars` | length of the response rendered to a string (`.tool_response // .tool_result`; objects/arrays stringified via `tojson`) |
| `est_tokens` | `(prompt_chars + response_chars) / 4`, integer |
| `tokens` | first present of `.tool_response.totalTokens`, `.tool_response.usage.total_tokens`, `.tool_response.usage.totalTokens`; else `null` |
| `duration_ms` | first present of `.tool_response.totalDurationMs`, `.tool_response.duration_ms`; else `null` |
| `is_error` | `.tool_response.is_error // .tool_result.is_error // null` |

Privacy invariant: the prompt and response TEXT never reach the ledger - lengths and the
short `desc` label only. This is what makes a home-dir file safe to keep while working in
employer repos.

Ledger path: `${DISPATCH_LEDGER:-$HOME/.claude/workspace-os/dispatch-ledger.jsonl}` -
`DISPATCH_LEDGER` is the test seam (the `GUARDRAIL_CONFIG` pattern). Parent dir
auto-created. Append is a single `>>` write of one line.

### 2. `hooks/hooks.json` wiring

One new PostToolUse entry, matcher `Task|Agent` (classic harness names the dispatch tool
`Task`; some environments name it `Agent`). Existing entries untouched. Hooks load at
session start - capture begins after the next restart; the README notes this.

### 3. `scripts/dispatch-ledger-summary.sh` - read-back

Read-only, bash + jq, **fail-loud** (a read tool that errors should say so - the
guardrails-upsert posture, not the hook's). Usage:

    dispatch-ledger-summary.sh [--repo NAME] [--top N]

Output: header (ledger path, entry count, total est_tokens, span first->last ts); a
per-agent table (count, est_tokens summed, harness `tokens` summed where present); top-N
dispatches by `est_tokens` (default 10: ts, agent, repo, est_tokens, desc). `--repo NAME`
filters every section. Missing ledger -> a one-line note, exit 0 (nothing captured yet is
not an error). Malformed lines are skipped with a count (`N unparseable lines skipped`) -
an append-only file written by a fail-open hook may contain a torn line; the reader must
not die on it.

### 4. Testing

`tests/test-dispatch-ledger.sh` (plain bash + jq; `DISPATCH_LEDGER` seam), registered in
`.github/workflows/ci.yml`:

- capture: synthetic Task payload -> entry appended, all fields correct; agentType fallback;
  desc truncated at 120; absent optional fields -> `null`s; object response stringified for
  `response_chars`; second dispatch appends (2 lines).
- privacy: a sentinel string in prompt + response text does NOT appear in the ledger file.
- fail-open: malformed stdin -> exit 0, no ledger line, no output; unwritable ledger dir ->
  exit 0; non-Task-shaped input (missing tool_input) -> exit 0.
- summary: fixture ledger -> totals, per-agent rows, top-N order, `--repo` filter; missing
  ledger note (exit 0); torn line skipped and counted.

### 5. Packaging & close-out

- `plugin.json` -> 0.23.0; description gains "+ a local-only dispatch ledger".
- README: short "Dispatch ledger" section - what is captured, where it lives, the privacy
  invariant, the summary one-liner, restart note.
- Tracking: action `A-20260824-dispatch-ledger` (workstream meta; location decision folded
  into the record body); `**Shipped**` annotation on the dispatch-ledger idea; note on
  `probe-first-dispatch-gate` that its ledger prerequisite now exists.

## Error handling

Capture: every failure path is silent exit 0 (spec §1) - a telemetry hook that can break a
session is worse than no telemetry. Summary: fails loud on unreadable/garbage ledger but
tolerates individual torn lines (skip + count). The two postures are deliberate and match
the plugin's engine-vs-authoring split.

## Open questions

None - location (user-global), scope (capture + minimal summary), and token source
(opportunistic + labelled estimate) decided in brainstorming, 2026-08-24.
