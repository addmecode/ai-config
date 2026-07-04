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
- Place new procedures so the object reads top-down: public entry points and triggers first, followed by the procedures they call, with local helpers near their first caller when practical.
- Keep triggers thin. If a trigger needs more than one meaningful statement, move the behavior into a purpose-named local procedure and have the trigger call only that procedure.
- Preserve existing business behavior during renames, top-down reordering, and cleanup refactors unless the user explicitly asks for behavior changes. Re-check Boolean truth tables, captions, enabled/visible states, and finish/save conditions after every rename.
- Do not let one Boolean represent opposite concepts such as record existence and user intent. When both are needed, split them into purpose-named variables such as `...Exists`, `Create...`, `Update...`, and `...Enabled` so `not` expressions do not hide business meaning.
- For setup or wizard pages, model mandatory actions and optional user choices separately. If missing setup must always be created but existing setup is optionally updated, represent those paths explicitly and make `Finish` conditions match that policy.
- Qualify current-object members with `this.` when reading or writing global variables, labels, or procedures from AL object code. Do not use `this.` for local variables, parameters, record fields, or standard globals such as `Rec`, `CurrPage`, and `CurrReport`.
- Declare variables and labels in the narrowest practical scope. If a variable or label is used only by one procedure, make it local to that procedure. Keep globals only for page field backing variables, state shared by multiple procedures, single-instance state, or values that must be object-wide.
- Order object code for top-down readability: entry points first, then the procedures they call, then lower-level helpers. Keep helper chains contiguous; do not move unrelated public procedures into the middle of a write/read flow. Reordering must be behavior-preserving.
- Never modify standard application objects directly; prefer extensions and events.
- When completing an implementation TODO, update nearby README/status/problem lists when they mention the completed work, unless the user asked to avoid documentation changes.

4. Preserve extension-safe architecture.
- Prefer events and event subscribers over modifications to standard application objects.
- Add integration events at business boundaries for extensibility.
- Prefer positive, purpose-named events that add behavior or context without skipping base code.
- Avoid new `IsHandled`/handled events by default; use interfaces, setup-driven implementation selection, or smaller positive events instead.
- Use `IsHandled` only when no better extension model exists, document why it is necessary, and skip the smallest visible block of code possible. Do not use it to bypass validation or broad process flow.
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


