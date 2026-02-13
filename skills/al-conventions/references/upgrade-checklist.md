# Upgrade Checklist

## Trigger Design

- Set `Subtype = Upgrade`.
- Keep `OnUpgradePerCompany` and `OnUpgradePerDatabase` triggers as method calls only.
- Avoid `OnCheckPreconditions*` and `OnValidateUpgrade*` triggers unless explicitly justified.

## Execution Control

- Use upgrade tags to gate each upgrade routine.
- Register every new upgrade tag in the correct `Upgrade Tag` subscriber.
- Avoid complex branching and deep nesting in upgrade logic.

## Data Safety and Reliability

- Wrap every `Get`, `Find`, `FindSet`, `FindFirst`, and `FindLast` in `if`.
- Minimize blocking errors; log and continue when practical.
- Avoid `HttpClient`, DotNet interop, and other external calls during upgrade.

## Data Migration Patterns

- Prefer `DataTransfer` for large-volume updates and field initialization.
- Add upgrade logic for new fields that use `InitValue` when existing records need backfill.
- Use loop/modify patterns only when data volume and trigger behavior make it necessary.
