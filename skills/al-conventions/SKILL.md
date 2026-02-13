---
name: al-conventions
description: Apply baseline Microsoft Dynamics 365 Business Central AL conventions for coding, refactoring, and review output quality. Use as the default companion skill for AL work, then pair it with specialized skills for object creation, testing, performance, integrations, or upgrades.
---

# AL Conventions

Use this workflow.

1. Confirm scope.
- Treat the repository as an AL project if `app.json` exists, `.al` files exist, or `.vscode/launch.json` contains `"type": "al"`.
- Stop using this skill if none of those conditions are true.

2. Route to a specialized skill when needed.
- Pair with `$al-object-builder` for new AL objects or large scaffolding tasks.
- Pair with `$al-testing` for test codeunits and coverage changes.
- Pair with `$al-performance` for optimization and query-loop refactors.
- Pair with `$al-integration` for outbox/inbox and transport-handler flows.
- Pair with `$al-upgrades` for `Subtype = Upgrade` codeunits and data migrations.

3. Apply core implementation rules.
- Use 2-space indentation.
- Use PascalCase for AL objects, variables, and procedures.
- Use file naming pattern `<ObjectName>.<ObjectType>.al`.
- Keep object names descriptive and short.
- Organize by feature (`src/<feature>/...`) instead of object-type folders.
- Never modify standard application objects directly; prefer extensions and events.

4. Preserve extension-safe architecture.
- Prefer events and event subscribers over modifications to standard application objects.
- Add integration events at business boundaries for extensibility.
- Use handled patterns when subscribers need to control flow.
- Use descriptive event parameter names.

5. Implement robust error handling and messaging.
- Use labels for `Error`, `Message`, and warnings; avoid hardcoded text.
- Use `TryFunction` patterns when failure handling is required.
- Add translator comments for parameterized labels.

7. Apply upgrade safeguards when relevant.
- Read `references/upgrade-checklist.md` before editing upgrade codeunits.
- Use upgrade tags instead of data-version branching.
- Protect every `Get` and `Find*` call with `if`.
- Avoid external calls during upgrade.
- Keep `OnUpgrade*` triggers as method dispatch only.

8. Apply performance baseline checks when relevant.
- Apply `SetRange` and `SetFilter` before data access loops.
- Apply `SetLoadFields` before `Get` and `Find*` operations.
- Prefer set-based operations like `CalcSums` over manual aggregation loops.
- Use temporary tables, dictionaries, and lists for transient processing.

## Review Output

Report reviews in this order.

1. Findings by severity with file and line reference.
2. Open questions or assumptions.
3. Brief change summary.
4. Residual risk or test gaps (or explicit no-findings statement).

## References

- Read `references/core-checklist.md` for day-to-day AL implementation checks.
- Read `references/upgrade-checklist.md` for upgrade code reviews and changes.
