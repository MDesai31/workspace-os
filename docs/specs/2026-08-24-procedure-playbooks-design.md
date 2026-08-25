# Procedure playbooks - design

- Date: 2026-08-24
- Status: accepted (design approved; implementation pending)
- Workstream: skills

## Problem

The 2026-08 EC2 audit measured 1,063 lines of procedural how-to across five hand-rolled files in
the UDX workspace's `_meta/conventions/` (Snowflake querying, notebook editing,
git-across-checkouts, run triage). They live outside the plugin because no artifact class fits:
memory is one-fact-per-file (a `type: convention` fact cannot hold a 300-line procedure) and
tracking records are work-state, not how-to. Worse, they only help when the model happens to read
them at the right moment - the workspace INDEX.md literally pleads "read the relevant one before
writing queries, not after they fail." Prose routing of procedures has measurably failed; the
audit's general lesson (an affordance with no capture-time or use-time surfacing gets zero
adoption) applies to know-how exactly as it did to guardrail rules.

## Goals

- A first-class **playbook** artifact: trigger, preconditions, steps, verify, known traps -
  version-controlled in the data layer, both repo and workspace tiers.
- **Trigger-time surfacing**: the playbook reaches the model when a matching tool call happens,
  at most once per session per playbook - not by hoping it gets recalled.
- A `/playbook` capture skill: author conversationally, adopt existing convention docs,
  list - propose-confirm like every capture skill.
- Zero cost on non-matching calls; fail-open everywhere in the hook.

## Non-goals

- No change to `/project-init` scaffolding (the skill creates `playbooks/` on first write;
  stamping it at init is a possible follow-up).
- No playbook lint pass in `/memory-lint` (follow-up if the class takes hold).
- No cross-repo playbook registry; tiers are the existing data-root and workspace levels.
- Not a replacement for memory flavors (`/ingest gotcha:` stays for single facts) or for
  guardrail rules (a playbook guides; a rule blocks).

## Verified constraint that shapes the design

Per current Claude Code hooks documentation (verified 2026-08-24 via docs agent):
**PreToolUse command hooks cannot inject model context non-blockingly** -
`hookSpecificOutput.additionalContext` is honored only on `"ask"` escalations there. What IS
available: a PreToolUse deny (exit 2, stderr reason) reaches the model at decision time;
PostToolUse supports `additionalContext` unconditionally, but by definition after the call ran.
Hence surfacing is a per-playbook choice between a one-time deny-and-retry ("before") and a
frictionless after-first-use injection ("after"). Default: `before` - the audit's plea is
literally "before, not after they fail," and the one blocked call + read + retry costs far less
than the measured failure mode (~484k tokens re-deriving existing output). This constraint and
choice are documented in `conventions/playbooks.md` and the decision record.

## Design

### 1. The playbook artifact

Home: `<data_root>/playbooks/<slug>.md` (repo tier; sidecar-aware via
`resolve-data-root.sh`) and `<workspace_root>/playbooks/<slug>.md` (workspace tier - where
UDX's shared conventions belong, spanning its four checkouts). Flat, greppable frontmatter
(bash hooks parse it with sed/grep; no nesting):

    ---
    name: snowflake-querying
    description: how to query Snowflake with sfq.py without burning retries
    trigger-bash: sfq\.py
    trigger-path:
    surface: before
    ---
    # Snowflake querying

    ## Preconditions
    ## Steps
    ## Verify
    ## Known traps

- `trigger-bash`: ERE matched (`grep -E`) against Bash `command`. `trigger-path`: ERE matched
  against Edit/Write `file_path`. Either or both; a playbook with neither is never
  auto-surfaced (docs-only, still listable).
- `surface`: `before` (default when absent) or `after`.
- Body sections are the recommended shape, not enforced.
- Source of truth: new `conventions/playbooks.md` (shape, trigger semantics, surface modes,
  the verified hook constraint, sizing advice). Example ships as `templates/playbook.md`.

### 2. `hooks/playbook-surface.sh` - trigger-time surfacing

One script registered on BOTH events, branching on `hook_event_name` from stdin:

- PreToolUse, joined to the existing `Bash|Edit|Write` guardrail entry's matcher scope via its
  own hooks entry (parallel hooks are independent).
- PostToolUse, a new `Bash|Edit|Write` entry (existing lint entry covers `Edit|Write|MultiEdit`
  only; playbook after-mode needs Bash too).

Per invocation (fail open: any error, missing jq, unresolvable root -> silent exit 0):

1. Parse stdin: `hook_event_name`, `session_id`, `tool_name`, `tool_input.command` /
   `tool_input.file_path`.
2. Resolve tiers: `<data_root>/playbooks` and, when a workspace exists,
   `<workspace_root>/playbooks`. Neither present -> exit 0.
3. Scan each `*.md`'s frontmatter (first `---` block only) for `name`, `trigger-bash`,
   `trigger-path`, `surface`. Malformed or trigger-less files are skipped silently.
4. Match: Bash calls against `trigger-bash`, Edit/Write calls against `trigger-path`
   (`grep -E`).
5. Once-per-session gate: marker file `${TMPDIR:-/tmp}/workspace-os-surfaced-<session_id>/<slug>`;
   marker exists -> exit 0 for that playbook. The marker is written BEFORE surfacing, so the
   post-deny retry passes.
6. Surface, by the playbook's mode and the current event:
   - `before` + PreToolUse: exit 2 with stderr
     `playbook '<name>' applies to this call - read <abs path> first, then retry.`
     (One playbook per call: first match in slug order wins; others get their turn on later
     calls - simultaneous multi-deny reads badly and the marker ordering makes each fire once.)
   - `after` + PostToolUse: emit
     `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"<content>"}}`
     where content is the full body for playbooks <= 300 body lines, else a one-line
     instruction to read `<abs path>`.
   - `before` playbooks do nothing on PostToolUse; `after` playbooks nothing on PreToolUse.

### 3. `/playbook` skill

Model-invocable capture skill (propose-confirm; no `disable-model-invocation`), modes:

- **author** (default): elicit the procedure (or take it from args/conversation), draft into
  the shape, choose triggers + surface mode with the user, validate each trigger compiles
  (`grep -E` against empty input), propose the full file, on confirm write it to
  `<data_root>/playbooks/<slug>.md` (or the workspace tier when the user says
  workspace-wide), report - including that surfacing starts next session (hooks already
  loaded keep running; markers are per-session).
- **adopt**: read an existing convention/how-to doc, propose a reshaping into one or more
  playbooks (propose-confirm-apply; source doc untouched - pointer note suggested instead of
  deletion). The path for UDX's five files.
- **list**: both tiers - slug, description, triggers, surface mode.

No helper script: unlike guardrails there is no shared fragile JSON to protect - each playbook
is its own new file, the failure blast radius of a bad write is that file, and the skill
validates the regex before writing.

Capture cadence: one new line in `hooks/capture-cadence.sh` -
`- a repeated multi-step procedure -> /playbook`.

### 4. Testing

`tests/test-playbook-surface.sh` (plain bash + jq; fixtures built in mktemp), in ci.yml:

- before-mode: matching Bash call -> exit 2, reason names playbook + absolute path; SAME
  session second call -> exit 0 silent; DIFFERENT session -> denies again.
- after-mode: PostToolUse matching call -> stdout JSON with `additionalContext` containing
  body text; once per session; >300-line body -> instruction line instead of content.
- path trigger: Edit file_path match works on both events per mode.
- mode/event cross-checks: `before` playbook silent on PostToolUse; `after` silent on
  PreToolUse.
- ordering: two before-playbooks matching one command -> first denies; after its marker
  exists the second denies on the next call.
- silence: non-matching call, no playbooks dir, malformed frontmatter, trigger-less playbook,
  not-a-git-repo cwd -> all exit 0, no output.
- tiers: workspace-tier playbook surfaces for a sidecar repo (marker keyed per session).
- capture-cadence test gains the `/playbook` line assertion.

### 5. Packaging & close-out

- `conventions/playbooks.md` (SoT) + `templates/playbook.md`.
- `hooks/hooks.json`: PreToolUse entry + new PostToolUse `Bash|Edit|Write` entry.
- README: "Playbooks" section. `plugin.json` -> 0.24.0, description gains "+ trigger-surfaced
  procedure playbooks (/playbook)". ci.yml registers the new test. Validator: 15 skills.
- Tracking: action `A-20260824-procedure-playbooks`; decision
  `D-20260824-playbook-surface-before-default` (the verified constraint + the before default +
  rejected alternatives: always-after loses the audit's ask, UserPromptSubmit injection is
  prompt-scoped not tool-scoped); `**Shipped**` annotation on the idea; follow-up idea line for
  `/project-init` stamping + memory-lint playbook pass folded into the idea's remaining notes.

## Error handling

Hook: silent exit 0 on every failure path (missing jq, bad stdin, unreadable playbook,
unwritable marker dir - surfacing lost beats a broken session; same posture as capture
hooks). Skill: fail loud in conversation - a bad regex or unwritable path is reported, and
nothing is written without confirmation.

## Open questions

None - scope (shape + hook + skill), mechanism (per-playbook before/after, default before),
and tiers (repo + workspace) decided in brainstorming, 2026-08-24.
