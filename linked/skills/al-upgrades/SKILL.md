---
name: al-upgrades
description: Implement and review Microsoft Dynamics 365 Business Central AL upgrade codeunits safely and efficiently. Use when creating or modifying Subtype Upgrade codeunits, adding upgrade tags, migrating data for new fields, applying DataTransfer, replacing version checks, and validating upgrade reliability and performance.
---

# AL Upgrades

Use this workflow.

1. Apply baseline conventions first.
- Use `$al-conventions` as baseline for naming, readability, and review output.

2. Confirm upgrade scope.
- Continue only for AL projects (`app.json`, `.al` files, or AL launch config).
- Identify whether logic runs per-company or per-database.
- List target tables, new fields, and migration intent.

3. Build upgrade codeunit structure first.
- Set `Subtype = Upgrade`.
- Keep `OnUpgradePerCompany` and `OnUpgradePerDatabase` triggers as method dispatch only.
- Avoid direct implementation code inside triggers.
- Avoid `OnCheckPreconditions*` and `OnValidateUpgrade*` unless explicitly justified.

4. Control execution with upgrade tags.
- Guard every upgrade routine with a dedicated upgrade tag.
- Register each tag in the correct subscriber:
  `OnGetPerCompanyUpgradeTags` for per-company routines,
  `OnGetPerDatabaseUpgradeTags` for per-database routines.
- Avoid version-based branching except first-install checks where explicitly appropriate.

5. Enforce safe database access.
- Wrap each `Get`, `Find`, `FindSet`, `FindFirst`, and `FindLast` in `if`.
- Prefer non-blocking handling where data is inconsistent.
- Use labels for user-facing error messages.

6. Optimize migration strategy.
- Prefer `DataTransfer` for high-volume backfills.
- Add explicit upgrade logic for existing records when new fields rely on `InitValue`.
- Use loop/modify only when trigger behavior must be preserved and data volume is acceptable.

7. Respect upgrade constraints.
- Avoid external calls during upgrade (`HttpClient`, DotNet interop, external systems).
- Keep control flow simple; avoid deep nesting in upgrade routines.
- Use execution-context guards only when clearly justified.

8. Validate and report.
- Summarize routines, tags, and tag registration points.
- Document data migration behavior and expected side effects.
- Call out residual risks and missing validation scenarios.

## References

- Read `references/upgrade-review-checklist.md` for review-time verification.
- Read `references/upgrade-patterns.md` for starter implementation patterns.
