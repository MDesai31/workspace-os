---
name: project-plan
description: Capture a future project or task without starting it. Use on /project-plan or on future-intent language ("someday", "next quarter", "don't let me forget", "park this idea", "eventually"). Records the idea, the reasoning around it, and rough timing so future-you can pick it up cold. Does NOT generate a task list or begin the work.
user-invocable: true
disable-model-invocation: false
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "<natural-language description of the future idea>"
---

# Project Plan

The forward-looking tracking skill. `/project-log` records what happened; **this captures what
you intend to do later** — the idea, the context you thought of alongside it, and roughly when —
so future-you can start cold without re-deriving the reasoning.

**The contract: this skill plans, it does not execute.** No query, no code, no full task list.
Capture the intention and the context, secure the timing, and stop.

Record format (the **idea template**) and rules live in this plugin's
`conventions/project-tracking.md`. Writes to `<data_root>/project-tracking/ideas.md`
(`docs/project-tracking/ideas.md` in in-repo mode; run `/project-init` first if tracking doesn't
exist).

## Steps

0. **Resolve the data root.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
   and parse its `key=value` output (`conventions/data-root.md`). Tracking lives at
   `<data_root>/project-tracking/`, memory at `<data_root>/memory/` — in BOTH modes; never
   hardcode `docs/…`. Announce the resolved mode. In **sidecar** mode: never create, modify,
   or stage any file inside the repo's working tree, and after each write commit the change in
   the sidecar repo (`git -C <workspace_root> add -A && git -C <workspace_root> commit`).

1. **Understand the intent.** Parse the description; pull in relevant context already in the
   conversation. The value is preserving the *why*, not just a title.

2. **Tag the workstream.** Pick one tag from `<data_root>/project-tracking/README.md`'s
   `## Workstreams` list (ask if unclear).

3. **Secure the timing.** If the user didn't say when, ask plainly: intended start? any target?
   Accept fuzzy answers ("Q3", "after X", "someday") and record them verbatim, then map to
   **priority**: near-term → `high`, on-deck → `mid`, slow-burn → `low`, no timing → `someday`.

4. **Write the idea record** to `ideas.md` using the idea template: name, workstream, priority,
   intended start (verbatim), the why/context, and "to start, future-us needs" (key files / the
   open question / the dependency to clear). Replace the "_No ideas captured yet._" placeholder if
   present.

5. **Report** the record you added. Don't start the work. Don't commit unless asked.
