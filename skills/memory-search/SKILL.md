---
name: memory-search
description: Search this repo's memory for a fact by keyword, or show what links to/from a fact (backlinks). Use for recall over docs/memory - find a fact, see its neighbors - not for editing memory.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Memory Search

Read-only recall over this repo's `<data_root>/memory/` (`docs/memory/` in in-repo mode): find a
fact by keyword, or list what links to and from a fact. Runs the same deterministic graph engine as
`/memory-lint` (`scripts/memory_graph.py`) in one of two query modes. Never edits, never commits.

**Prerequisite - resolve the data root first:** run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"` (see `conventions/data-root.md`).
Memory lives at `<data_root>/memory/`; if missing, say so and stop. Announce the resolved mode
(in-repo vs sidecar), exactly like `/memory-lint`.

## Dispatch

Resolve the plugin root via `${CLAUDE_PLUGIN_ROOT}` when set, else the plugin's install directory.

- If the argument is `--links <fact>` or `links <fact>` (or just `<fact>` when the user clearly
  wants neighbors), run the **backlinks** mode:

      python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" --backlinks "<fact>" \
        --root "<data_root>/memory"

- Otherwise treat the whole argument as a search **query**:

      python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory_graph.py" --search "<query>" \
        --root "<data_root>/memory"

In **in-repo mode** you may omit `--root` (it defaults to `docs/memory`). In **sidecar mode** pass
the resolved `--root "<data_root>/memory"`; both modes read only the memory tree (search and
backlinks do not consult tracking records or the workspace tier, so `--tracking-root` / `--link-root`
are not needed here).

Note: the word `links` is a dispatch keyword - a query like `links optimizer` is read as
"backlinks for optimizer", not a text search for "links". Documented limitation; to search for the
literal word, phrase the query differently.

## Report

Print the engine's output verbatim; you may add a one-line summary (e.g. how many matches, or the
most relevant fact). Both modes exit 0 even when nothing is found - an empty result is a valid
answer, not an error. **No edits, no commit** - read-only recall, same posture as `/memory-lint`.
