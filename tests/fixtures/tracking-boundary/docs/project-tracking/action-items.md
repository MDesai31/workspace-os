# Action Items (fixture)

### A-20260101-small - a well-scoped tracking record
- Workstream: memory
- Status: open
- Created: 2026-01-01

Do the thing, then verify it. Points at the fact in memory rather than restating it. See [[some-fact]].

### A-20260102-huge - a record whose body has grown too large
- Workstream: memory
- Status: open
- Created: 2026-01-02

This body is deliberately long to exercise the record-size boundary lint. Line 1 of filler.
Filler line 2.
Filler line 3.
Filler line 4.
Filler line 5.
Filler line 6.
Filler line 7.
Filler line 8.
Filler line 9.
Filler line 10.
Filler line 11.
Filler line 12.
Filler line 13.
Filler line 14.
Filler line 15.
Filler line 16.
Filler line 17.
Filler line 18.
Filler line 19.
Filler line 20.
Filler line 21.
Filler line 22.
Filler line 23.
Filler line 24.
Filler line 25.
Filler line 26.
Filler line 27.
Filler line 28.
Filler line 29.
Filler line 30.
Filler line 31.
Filler line 32.
Filler line 33.
Filler line 34.
Filler line 35.
Filler line 36.
Filler line 37.
Filler line 38.
Filler line 39.
Filler line 40.

### A-20260103-measured - a record duplicating measured evidence
- Workstream: memory
- Status: open
- Created: 2026-01-03

The pipeline was profiled and the numbers pinned below.

**MEASURED** (2026-01-03, run r-42): p50 latency 120ms, p99 480ms, throughput 3.1k rows/s.

This evidence belongs in a memory fact, not in the tracking record body.

### A-20260104-mention - a record that only mentions the marker in prose
- Workstream: memory
- Status: open
- Created: 2026-01-04

This record explains that a `**MEASURED**` block belongs in memory, but does not contain one.
