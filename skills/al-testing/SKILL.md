---
name: al-testing
description: Design and implement Microsoft Dynamics 365 Business Central AL tests  maintainable with test patterns. Use when creating or updating AL test codeunits, organizing App vs Test project files, adding coverage for business logic, building test data setup, or reviewing AL tests for reliability and readability.
---

# AL Testing

Use this workflow.

1. Apply baseline conventions first.
- Use `$al-conventions` as baseline for naming, structure, and review format.

2. Confirm test scope and project layout.
- Confirm the repository is an AL project (`app.json` and/or `.al` files).
- Detect AL-Go split layout (`App/` and `Test/`) versus single project layout.
- Place test artifacts only in test folders/projects.
- If no test work is requested, do not execute this skill.

3. Build a test plan from behavior.
- Convert requested behavior into Given/When/Then scenarios.
- Identify required setup data, action under test, and assertions.
- Cover both success path and relevant validation or failure paths.

4. Create test objects correctly.
- Use `codeunit` with `Subtype = Test`.
- Use descriptive test names in Given/When/Then style.
- Keep one behavior assertion target per test procedure.
- Use `references/test-templates.md` for starter skeletons.

5. Use standard test libraries first.
- Prefer Business Central `Library - *` codeunits for setup and posting.
- Use `Assert` codeunit for validations.
- Keep setup deterministic and avoid hidden dependencies between tests.

6. Organize files and dependencies.
- Mirror App feature structure inside Test project folders.
- Keep application logic out of test projects and vice versa.
- Ensure Test `app.json` depends on App `app.json` (never reverse).

7. Enforce quality checks.
- Avoid hardcoded magic values where helper setup is clearer.
- Keep tests isolated and idempotent.
- Verify each test has explicit and meaningful assertions.
- Flag missing negative tests or missing edge-case coverage.
- If production changes are needed for testability, request or document those changes explicitly.

8. Run the tests after every change.
- After creating or modifying AL code, run the suite and confirm it is green.
- Use `references/run-tests.md` for the headless `ALTestRunner` command (derives ids,
  names, and launch config from the project; works across AL projects).
- Trust the console Success/Failure lines; ignore the documented non-fatal noise.

9. Report outcome clearly.
- List created or updated test files.
- Report the per-codeunit Success/Failure results from the run.
- Map tests to the scenarios they cover.
- Note residual gaps and next tests to add.

## References

- Read `references/test-checklist.md` for review-time quality checks.
- Read `references/test-templates.md` for baseline test codeunit patterns.
- Read `references/run-tests.md` to run the suite headless after changes.
