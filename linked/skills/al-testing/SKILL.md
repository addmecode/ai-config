---
name: al-testing
description: Design and implement Microsoft Dynamics 365 Business Central AL tests  maintainable with test patterns. Use when creating or updating AL test codeunits, organizing App vs Test project files, adding coverage for business logic, building test data setup, or reviewing AL tests for reliability and readability.
---

# AL Testing

Apply the role and project boundaries in `al-conventions`. Use the sections for
your assigned operation: scenario design, test implementation, read-only review,
or executable validation. Loading this skill does not assign all four operations
to one agent.

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

8. Execute required validation in the assigned validation role.
- Use `references/run-tests.md` as the single procedure for affected-project
  selection, dependency order, SaaS/container execution, and named test results.
- Use `al-language-server` for build/publication wrapper options, tool resolution,
  and the MCP boundary. Follow the project's required gates; do not infer
  mandatory publication merely from the presence of a launch configuration.

9. Report outcome clearly.
- Follow the caller's output contract. Include evidence relevant to your role:
  design maps scenarios to coverage, implementation identifies changed test files
  and self-review, review identifies concrete coverage gaps, and execution reports
  named test results and blockers. Do not claim checks that another role has not run.

## References

- Read `references/test-checklist.md` for review-time quality checks.
- Read `references/test-templates.md` for baseline test codeunit patterns.
- Read `references/run-tests.md` for required headless validation in the execution role.
