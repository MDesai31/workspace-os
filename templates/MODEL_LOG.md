# MODEL_LOG — <model name>

<!--
The run-layer fallback when no experiment tracker (MLflow/W&B/SageMaker) is available.
One file per model, at docs/models/<model-name>.md in the target repo. Append-only —
declare it `merge=union` in .gitattributes like the tracking ledgers.

Discipline: one row per EVALUATED CANDIDATE — a build you'd want to find again — not
every debug run or epoch. Git already records what changed (configs/hyperparameters in
the diff between Build shas); this table's unique job is the association:
this sha → these numbers → this verdict. Don't re-record inputs git already holds.

Decision records in docs/project-tracking/decisions-log.md point here via their `Run:`
field (`MODEL_LOG.md <date> row`) when there is no tracker run ID to point at.
-->

**Scope:** <what this model does, one line>
**Validation protocol:** <the standing protocol rows are measured under — split/CV/walk-forward + leakage guards. If the protocol changes, log a D- record and note the row from which it applies.>

| Date | Build (sha/tag) | What changed | Headline metrics | Verdict |
|---|---|---|---|---|
| YYYY-MM-DD | `abc1234` | <one line — the delta vs the previous row> | <metric name + value> | champion \| challenger — kept \| discarded |
