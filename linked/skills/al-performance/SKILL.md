---
name: al-performance
description: Optimize Microsoft Dynamics 365 Business Central AL code for runtime and scalability. Use when reviewing or implementing AL performance improvements, reducing database roundtrips, optimizing filters and loops, choosing set-based operations, using SetLoadFields, or refactoring data processing with temporary tables, dictionaries, lists, and DataTransfer.
---

# AL Performance

Use this workflow.

1. Apply baseline conventions first.
- Use `$al-conventions` as baseline for naming, safety, and output format.

2. Confirm scope and hotspot.
- Confirm AL project scope (`app.json`, `.al` files, or AL launch config).
- Identify the slow behavior or likely bottleneck path.
- Locate involved tables, loops, and read/write operations.

3. Preserve functional behavior.
- Optimize implementation details without changing business behavior by default.
- If behavior changes are required, document them explicitly before applying.

4. Reduce data early.
- Apply `SetRange` and `SetFilter` before `Find*`.
- Select appropriate keys before scanning recordsets.
- Keep query scope narrow and avoid full-table iteration.

5. Minimize loaded fields.
- Use `SetLoadFields` before `Get` and `Find*`.
- Load only fields actually used in the procedure.
- Re-check that later logic does not implicitly require unloaded fields.

6. Prefer set-based over row-by-row patterns.
- Use `CalcSums`, `ModifyAll`, and similar set-based operations where safe.
- Replace manual aggregation loops when equivalent built-ins exist.
- Batch updates when many rows are touched.

7. Use in-memory structures intentionally.
- Use temporary records for repeated multi-pass processing.
- Use `Dictionary` for fast key lookups.
- Use `List` for simple ordered collections.

8. Apply upgrade and migration performance rules when relevant.
- Use `DataTransfer` for high-volume upgrade migrations and backfills.
- Keep upgrade logic idempotent with upgrade tags.
- Protect read operations with `if Get/Find* then`.
- Hand off to `$al-upgrades` for upgrade-codeunit-heavy work.

9. Validate and report.
- Summarize changes by expected impact (reads, writes, loops removed).
- Call out behavior risks (triggers bypassed, functional side effects).
- Recommend targeted verification steps for critical scenarios.

## References

- Read `references/performance-checklist.md` for review-time checks.
- Read `references/performance-patterns.md` for refactor patterns.
