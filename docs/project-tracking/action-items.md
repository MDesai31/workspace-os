# Action Items (open)

Open, actionable work. Added by `/project-log action`; on completion, `/project-log done`
moves the record to `resolved.md`. Records use the action template from the conventions doc.

### A-20260831-dogfood-defect-batch — four defects found by using the plugin, not by auditing it
- Workstream: schema
- Status: open
- Created: 2026-08-31

Four defects surfaced by ordinary use across two machines, fixed as one batch (v0.33.0). All
four are silent failures: none errored, none logged, each just quietly did nothing.

1. **The workspace tier was dead from the workspace root.** `resolve-data-root.sh` exited 1
   outside a git work tree, so `capture-cadence.sh` hit `|| exit 0` and emitted **0 bytes**.
   Measured before/after on the real `Documents/Codebase` workspace: exit 1 and 0 bytes, then
   `mode=workspace-root` and 1033 bytes. The capture nudge had never fired in a normal session.
   Decision: D-20260825-workspace-root-mode.
2. **The handoff block had a second, independent gate** on `[ -n "$data_root" ]`, so handoffs
   would still not have surfaced from the workspace root even with (1) fixed. Decision:
   D-20260831-workspace-root-handoff-fanout.
3. **Bare dates silently truncate every git window.** Git fills a bare date's missing time with
   the **current time of day**, not midnight. Measured on a fixture with commits at 02:00,
   06:00, 09:00, 23:00 run at 13:23: `--since=<today>` returned 1 commit against 4 for
   `'<today> 00:00'`. A same-day `/work-journal` would report that nothing happened. Testing
   also showed `--until` truncates from the other end, where `00:00` is the wrong suffix (0
   commits) and `23:59` is right — so the rule is per-edge, not a blanket midnight suffix.
   Four call sites carried it: `/work-journal` summary, log (a date parsed from `work-log.md`)
   and prep (a date read from a `meetings/` filename), and `/project-log release-notes` (only
   when `since:` is a date, not a ref). Stated once in `conventions/project-tracking.md`
   § "Date windows over git history"; the skills point at it, per skills-point-at-conventions.
   `/guardrails mine` was checked and is clean — it mines the session conversation, not a date
   window.
4. **`checkout-groups.sh` normalized before validating.** It stripped a trailing `_meta`
   component and only then tested `-d`. Since `dirname` of a bare relative name is always `.`,
   which always exists, the `-d` guard was validating a directory the caller never named:
   `_meta` from a cwd with no `_meta` scanned that cwd's tree and printed results, while `.`
   from inside `_meta` matched no basename test and reported nothing. Now the argument is
   validated as given, resolved to absolute, and normalized last — restoring the fail-loud
   contract the script's own header already promised.

5. **The fix made 11 skills reachable from a mode none of them handled.** Auditing only the 7
   executable consumers missed the ~17 model-driven ones: every tracking skill said data lives
   at `<data_root>/…` "in BOTH modes", which reads as `/project-tracking/…` from the filesystem
   root once `data_root` is unset. Defect 1 turned that from unreachable into invited, since the
   cadence block now fires there and names `/ingest`, `/project-log`, and `/handoff`. Routing is
   now stated in `conventions/data-root.md` § "No repo tier" (tracking skills stop; memory
   skills use the workspace tier; read-only skills repoint their `--root`), and all 11 skills
   point at it. The stale "BOTH modes" phrasing is gone: there are four modes, not two.

Verification: 15 test scripts / 382 assertions / 0 failures; validator clean at 17 skills;
`memory_graph: clean`. (1), (2) and (4) gained regression tests — +8 assertions in
`test-capture-cadence.sh` including a sidecar-leak guard, +3 in `test-checkout-groups.sh`, +6
in `test-resolve-data-root.sh`. (3) ships as **documentation only**: skills are not executed by
the suite and there is no `tests/test-work-journal.sh`, so a green suite is not evidence for it
— the evidence is the measured fixture above.
