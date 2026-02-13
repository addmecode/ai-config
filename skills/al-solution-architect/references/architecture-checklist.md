# Architecture Checklist

Use this checklist to review AL architecture decisions before implementation.

## Scope and Bounded Context

- Confirm the feature boundary is business-capability based.
- Confirm responsibilities are split across focused objects.
- Confirm object names are descriptive and remain concise.

## Object Responsibilities

- Confirm tables store state, not orchestration logic.
- Confirm codeunits coordinate workflows and policies.
- Confirm pages/page extensions only support UI behavior.
- Confirm enums/interfaces are used for replaceable behavior.

## Extensibility Model

- Confirm integration events exist at business boundaries.
- Confirm event payload includes sufficient context.
- Confirm handled pattern is used only when necessary.
- Confirm subscribers avoid hidden side effects.

## Integration and Processing Flow

- Confirm outbound/inbound concerns are separated.
- Confirm status transitions are explicit and valid.
- Confirm retryable operations are idempotent.
- Confirm payload persistence supports troubleshooting and reprocessing.

## Performance and Data Access

- Confirm filters are applied before data reads.
- Confirm `SetLoadFields` is used before `Get` and `Find*`.
- Confirm loop-heavy logic is evaluated for set-based alternatives.
- Confirm large migrations evaluate `DataTransfer` usage.

## Upgrade and Release Safety

- Confirm upgrade logic uses upgrade tags.
- Confirm each `Get` and `Find*` is protected with `if` in upgrade routines.
- Confirm no external calls run during upgrade.
- Confirm new fields with `InitValue` are evaluated for backfill needs.

## Testing and Operability

- Confirm architecture decisions map to concrete tests.
- Confirm observability includes actionable error context.
- Confirm operator workflows are defined for failed processing states.
- Confirm unresolved assumptions are documented.
