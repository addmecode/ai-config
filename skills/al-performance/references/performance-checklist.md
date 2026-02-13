# Performance Checklist

## Data Access

- Apply filters before `Find*` operations.
- Use keys that match filter and sort needs.
- Avoid scanning records that are later filtered in AL code.

## Field Loading

- Call `SetLoadFields` before reads.
- Include only required fields.
- Avoid accidental field access that forces extra loads.

## Loop and Aggregation Patterns

- Replace manual summation loops with `CalcSums` where possible.
- Avoid nested loops on large datasets.
- Use set-based operations for bulk changes where safe.

## Memory and Caching

- Use temporary tables for repeated transforms on the same dataset.
- Use `Dictionary` for lookup-heavy logic.
- Use `List` only when ordering is needed and key access is not.

## Upgrade and Migration

- Prefer `DataTransfer` for high-volume initialization/backfill.
- Keep migrations idempotent using upgrade tags.
- Protect all `Get`/`Find*` calls with `if`.

## Review Output

- State expected impact (fewer reads/writes, reduced loops).
- Flag behavior changes and potential trigger/event implications.
- Identify residual risk and missing benchmarks.
