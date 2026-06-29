---
name: al-solution-architect
description: Design and review Microsoft Dynamics 365 Business Central AL solution architecture before implementation. Use when decomposing requirements into AL objects, defining extension-safe boundaries, selecting event and interface patterns, planning integration and upgrade impacts, and producing implementation blueprints with risks and tradeoffs.
---

# AL Solution Architect

Use this workflow.

1. Apply baseline AL rules first.
- Use `$al-conventions` for naming, folder structure, event safety, and review output style.
- Confirm AL context (`app.json`, `.al` files, or AL launch config).

2. Define architecture scope and constraints.
- Capture business capability, actor flows, and non-functional constraints.
- Identify data volume, extension boundaries, upgrade impact, and integration dependencies.
- Record assumptions explicitly when requirements are incomplete.

3. Decompose into feature modules.
- Split by business capability (`src/<feature>/...`) instead of object type folders.
- Assign object responsibilities (table, page, codeunit, enum, interface, extension).
- Keep orchestration in codeunits and persistence in tables.

4. Choose extensibility model.
- Prefer interface-driven composition for handlers and providers.
- Add integration events at business boundaries, not inside low-level helpers.
- Prefer positive, purpose-named events for additive extension points.
- Avoid `IsHandled`/handled patterns as an override mechanism; use interfaces, setup, or separate implementation objects when downstream control replacement is required.
- Allow `IsHandled` only as a last resort, with explicit rationale and the smallest skipped code block possible. Never use it to bypass validation or large process flow.

5. Design data and process flow.
- Define authoritative tables, status fields, and transition rules.
- Separate command processing from transport/integration details.
- Ensure idempotent processing for retryable operations.

6. Plan cross-cutting architecture.
- Define error strategy (`TryFunction` boundaries, label-based messaging).
- Define performance strategy early (`SetRange`, `SetLoadFields`, set-based operations).
- Define upgrade strategy early (upgrade tags, migration routines, no version branching).

7. Define implementation blueprint.
- Produce object map with file names using `<ObjectName>.<ObjectType>.al`.
- Produce event map: publisher, subscriber, and payload contract.
- Produce dependency map: interfaces and concrete implementations.
- Produce risks and fallback plan per critical decision.

8. Coordinate specialized skills.
- Use `$al-object-builder` to scaffold the decided object model.
- Use `$al-integration` for outbox/inbox and transport-message design.
- Use `$al-performance` for heavy data paths and throughput hotspots.
- Use `$al-upgrades` for migration planning and upgrade codeunits.
- Use `$al-testing` when converting architecture decisions into test scenarios.

## Outputs

When finishing architecture work, output these artifacts.

1. Decision log with chosen option and rejected alternatives.
2. Object and file plan by feature folder.
3. Event and interface contract plan.
4. Performance, upgrade, and testing implications.
5. Open questions and assumptions requiring user confirmation.

## References

- Read `references/architecture-checklist.md` for review-time checks.
- Read `references/architecture-patterns.md` for starter solution patterns.
