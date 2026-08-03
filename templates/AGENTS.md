# Agent Instructions

This repo keeps a durable knowledge base under `docs/memory/`. It is plain markdown, readable and
maintainable by any agent or human without special tooling.

## Before working here
- Read `docs/memory/MEMORY.md` first - the index of what is known about this codebase (one line per
  fact). Open the specific fact files it lists when relevant.
- `docs/memory/README.md` is the operator's manual: the schema, and how to read, verify, and add
  facts with plain file operations (no plugin, no slash commands).

## Maintaining the base
- Add a fact: follow the procedure in `docs/memory/README.md`.
- Check integrity: `python docs/tools/memory_graph.py --check` (stdlib Python, no dependencies).

## Always-loaded instructions
<!-- Costly-if-unseen facts - ones an agent must see BEFORE acting or it makes a wrong move first -
     go here as imperative bullets. Empty until the first such fact is recorded. -->

## Stale priors (training vs reality)
<!-- Managed section. Bullets of the form: "<topic>: use <Y>, NOT <X> (training prior is wrong here)."
     Written by the workspace-os /ingest gotcha: shortcut, or by hand following the same shape. -->
