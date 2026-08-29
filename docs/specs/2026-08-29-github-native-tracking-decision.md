# GitHub-native tracking — decision spec

Date: 2026-08-29. Status: ratified 2026-08-29 (D-20260829-markdown-stays-canonical). A decision spec, not a build spec —
the github-native-tracking idea (brainstorm 2026-06-28) was captured as "a decision to
deliberate: this forks the data model." Deciding closes it.

## The question

Tracking today is markdown-canonical: append-`union` files in
`<data_root>/project-tracking/`, linted by `memory_graph.py`, wikilinked from memory,
carried by the repo. Zach's setup pushes tracking into GitHub-native surfaces instead:
issue templates, a `project-autofill` workflow, and a weekly GraphQL
(`createProjectV2StatusUpdate`) status post to a Projects v2 board. Three options:

- **A. Markdown-canonical** (status quo): files are the single source of truth.
- **B. Projects-canonical**: migrate canon to GitHub Issues/Projects v2.
- **C. One-way mirror**: markdown stays canonical; a workflow publishes a read-only board.

## The weighing

### What Projects-canonical would buy

A real board UI; native issue↔PR linking; visibility for collaborators and leadership
without opening files; Zach's automation patterns exist to borrow (MIT).

### What it would break — and why the breaks are structural, not preferences

1. **Sidecar mode becomes impossible.** The enterprise data layer is a local-only git repo
   with **no remote** — its entire point is that employer-adjacent work-state never leaves
   the machine. Projects-canonical means tracking lives in GitHub's cloud; there is no
   sidecar equivalent. The plugin's flagship differentiator (the 2026-08-28 market survey
   found no analog) would fork into "personal repos use Projects, enterprise uses files" —
   two data models, every skill written twice.
2. **It inverts the strategy decision.** D-20260828-build-only-what-native-wont commits new
   surfaces to being opinionated/deterministic/**git-native**/boundary-aware, because those
   are the classes platforms don't absorb. Projects-canonical migrates canon *onto* a
   platform surface — the exact dependency class the strategy exists to avoid, and one GitHub
   has changed before (Projects classic was sunset in 2024).
3. **The deterministic layer goes dark.** `memory_graph.py` link resolution (facts
   wikilinking `A-`/`D-`/`F-` ids), `--check-tracking` boundaries, `merge=union`
   collision-proofing, and the vendor-neutral `AGENTS.md` layer all read files. Against an
   API they become network calls behind a PAT — and the audit's strongest finding was that
   surfaces needing credentials + hand-config score 1-3/10 in real use while
   file-and-command surfaces score 6-9.
4. **Offline/portability regress.** Tracking currently works on a plane, in a clean room,
   and in any git host (the repo could move to GitLab tomorrow); user-owned Projects v2
   boards additionally require a **classic PAT** — more standing secret surface for a plugin
   that today needs none.

### What a one-way mirror would cost now

A GraphQL workflow + PAT + field-mapping config, maintained against a moving API, for a
board nobody has asked to see: every current consumer of tracking is a Claude session or
the user reading files. This is precisely the "neutral convenience" the strategy says to
borrow-or-await, and the audit says a config-heavy surface with no daily payoff goes dark.

## Decision (ratified)

**A — markdown stays canonical. No build.** B is rejected structurally (sidecar
incompatibility, strategy inversion, deterministic-layer loss). C is not rejected on merits
but **deferred behind an evidence gate**: it becomes worth building when a real second
reader wants a board — a collaborator on a shared repo, or a leadership-visibility ask.
When that day comes, the sanctioned shape is: dormant-by-default (no-op until a
`PROJECTS_PAT` secret exists, pinned action SHA, fail-loud cost guard — the
integrity-auditor cloud-tier pattern), strictly one-way (files → board; the board is a
render, never an input), and adapted from Zach's workflows rather than written fresh.
`/project-log release-notes` (v0.29.0) already covers the "human-readable outward view"
need without any of the costs.

Re-evaluation triggers, recorded so this isn't re-litigated ad hoc: (1) a second regular
human reader of any workspace-os-tracked repo's status; (2) portfolio-registry going
active (its cross-repo view may want a board as one renderer); (3) GitHub shipping
Projects automation that removes the classic-PAT requirement.

## Consequences

- The idea closes: the deliberation was the work. No `A-` record spawns.
- `portfolio-registry` inherits a note: if it builds, a Projects board is a candidate
  *renderer* of its registry, never the registry itself.
