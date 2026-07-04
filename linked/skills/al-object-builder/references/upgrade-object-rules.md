# Upgrade Object Rules

Use these checks when creating or editing upgrade codeunits.

## Trigger Usage

- Set `Subtype = Upgrade`.
- Keep `OnUpgradePerCompany` and `OnUpgradePerDatabase` triggers as dispatch-only.
- Avoid placing implementation code directly in triggers.
- Avoid `OnCheckPreconditions*` and `OnValidateUpgrade*` unless explicitly justified.

## Execution Control

- Use upgrade tags to make upgrade routines idempotent.
- Register each new tag in the correct `Upgrade Tag` subscriber.
- Prefer flat control flow and minimal nesting.

## Data Safety

- Protect every `Get` and `Find*` with `if`.
- Minimize blocking errors; continue where safe and practical.
- Avoid external calls during upgrade (`HttpClient`, DotNet interop, external integrations).

## Performance

- Prefer `DataTransfer` for high-volume initialization and migration.
- Consider backfill for existing records when new fields are added with `InitValue`.
