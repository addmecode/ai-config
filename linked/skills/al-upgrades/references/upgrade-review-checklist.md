# Upgrade Review Checklist

## Codeunit Structure

- `Subtype = Upgrade` is set.
- `OnUpgradePerCompany` and `OnUpgradePerDatabase` only dispatch methods.
- No implementation logic is directly inside triggers.

## Trigger Use

- `OnCheckPreconditions*` and `OnValidateUpgrade*` are avoided unless explicitly justified.
- If present, precondition/validation triggers are lightweight and guarded.

## Execution Control

- Upgrade tags are used for each upgrade routine.
- New tags are registered in the correct event subscriber.
- No routine is incorrectly tagged in both per-company and per-database registration.

## Read Safety

- Every `Get`/`Find*` call is wrapped in `if`.
- Missing data paths are handled gracefully when possible.
- Upgrade is not blocked unnecessarily by recoverable inconsistencies.

## Migration and Performance

- `DataTransfer` is considered for large migrations or field backfills.
- New fields with `InitValue` have explicit backfill logic for existing records where required.
- Loop/modify patterns are justified for volume and trigger needs.

## Prohibited or High-Risk Patterns

- No external calls during upgrade (`HttpClient`, DotNet interop, web services).
- No version-branching as main execution control.
- No deeply nested branching that obscures idempotency.

## Reporting

- Review notes include method/tag mapping.
- Review notes include data impact and expected side effects.
- Residual risks and missing validations are explicitly listed.
