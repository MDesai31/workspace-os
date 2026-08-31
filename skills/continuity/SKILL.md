---
name: continuity
description: Scaffold or review a repo's CONTINUITY.md — the bus-factor runbook of recurring obligations (scheduled jobs, what silently goes stale, how a miss is detected), access pointers, and re-verify budgets. Use when the user asks for a continuity runbook, bus-factor doc, "what breaks if I'm out", or after adding/retiring a scheduled job.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[scaffold|review]   (default: scaffold if CONTINUITY.md absent, else review)"
---

# Continuity

Create or maintain `CONTINUITY.md` **at the repo root** (a bus-factor doc must be findable by a
stranger — it sits next to README.md). In sidecar mode, CONTINUITY.md lives at
`<data_root>/CONTINUITY.md` instead of the repo root, and the CLAUDE.md pointer line is skipped.
The template and its conventions live in this plugin's `templates/CONTINUITY.md`; follow its
structure exactly — the five sections and the `TODO(<owner>)` convention are the contract.

**Never write a secret** into this file — key values, tokens, passwords, connection strings.
Pointers only ("lives in `~/.config/secrets/…`, held by X"). This is the same rule as
`conventions/memory.md`, and the guardrail engine's secret patterns apply to this file like any
other write.

## Step 0

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in every repo-tier
   mode; never hardcode `docs/…`.
   With no `data_root` (`workspace-root` mode) see `conventions/data-root.md`
   § "No repo tier". Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).

## Mode: `scaffold` (CONTINUITY.md absent)

1. **Auto-inventory the repo's recurring obligations** before touching the template — the doc's
   value is pre-filled rows, not a blank form. Look for:
   - **systemd units**: `*.timer` / `*.service` files in the repo, or docs naming
     `systemctl --user` units (grep `OnCalendar`, `systemctl`, `timer`);
   - **cron**: `crontab` fragments, `cron.d` files, docs mentioning schedules
     (grep `cron`, `schedule`, `daily`, `nightly` in docs/scripts);
   - **CI schedules**: `on: schedule:` blocks in `.github/workflows/*.yml`;
   - **app-level schedulers**: task-queue beat configs, `node-cron`, APScheduler, etc.;
   - **maintenance docs**: an existing runbook/ops doc (`RUNNING.md`, `agent_docs/cron_*`,
     `ops/**`) to mine, read-only.
2. **Propose one obligation row per job found** — fill Cadence and Runs-where from the source;
   set Needs / Goes-stale / Detection from what the repo shows, and use `TODO(<owner>): …` for
   every fact you cannot verify (especially Detection — never invent a sentinel that doesn't
   exist). Owner defaults to the repo's committer (`git log -1 --format=%an`) with a TODO to
   confirm.
3. **Show the proposed file and confirm before writing** (same propose→confirm→apply discipline
   as the adopt skills). Then write `CONTINUITY.md` *(in-repo only:)* at the repo root from the
   template with the proposed rows, `<REPO>` replaced by the repo name, and the unfilled
   sections left as template guidance. *(sidecar:)* write to `<data_root>/CONTINUITY.md` instead.
4. Point it from the repo *(in-repo only)*: offer to add one line to the repo's `CLAUDE.md`
   (`- Continuity runbook: CONTINUITY.md` under an existing pointers section) — a pointer, not
   an import; this doc is for humans first and must not load every session. In sidecar mode
   this step is skipped.

## Mode: `review` (CONTINUITY.md present)

1. **Re-run the auto-inventory** and diff against the doc: report jobs that exist but have no
   row, and rows whose job no longer exists (retired unit, deleted workflow).
2. **List every open `TODO(…)`** grouped by owner — these are the named gaps awaiting a human.
3. **Staleness nudges:** section 3 rows whose "Last verified" is past their cadence; section 5's
   bus-factor test if never recorded.
4. Propose the specific row edits; apply only on confirmation. Never delete a row without
   confirmation (a retired job's row may hold recovery knowledge — offer to strike it through
   with a `retired <date>` note instead).

## After writing

Show what was created/changed and the open `TODO(<owner>)` count. Do **not** commit unless
asked. Suggest `/project-log action` for any TODO that is real work rather than a fact to fill.
