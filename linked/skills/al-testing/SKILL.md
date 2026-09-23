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

8. Build and run tests after every change.
- First inspect the applicable test project's `.vscode/launch.json`.
- When it targets Business Central SaaS (for example, `"environmentType": "Sandbox"`),
  run tests through the Microsoft AL MCP tools, which use the same Business Central
  `TestRunnerHub` service as the official VS Code Test Explorer.
- If AL MCP tools are unavailable because the server is not running, start it before
  falling back to another runner. Use the .NET runtime supplied by the VS Code .NET
  Runtime extension rather than installing a runtime:

  ```powershell
  $env:DOTNET_ROOT = "C:\Users\adrri\AppData\Roaming\Code\User\globalStorage\ms-dotnettools.vscode-dotnet-runtime\.dotnet\10.0.12~x64~aspnetcore"
  $env:PATH = "$env:DOTNET_ROOT;$env:PATH"
  & "<AL extension>\bin\altool.exe" launchmcpserver "<absolute App project path>" "<absolute Test project path>" --transport http --port 5000 --disableTelemetry
  ```

  Use the installed `ms-dynamics-smb.al-*` extension's `altool.exe`; keep the MCP
  process running while using its AL tools. Do not install a separate .NET runtime.
- For SaaS, use this sequence:
  1. Call `al_addproject` with the absolute test-project folder if it is not already loaded
     by the AL MCP server.
  2. Call `al_build` for the test project. Build any app dependencies first when the project
     layout requires it.
  3. Call `al_publish` with `skipBuild=true`, `environmentType`, `environmentName`, `tenant`,
     `authentication='AAD'`, and the `schemaUpdateMode` from `launch.json`.
  4. Call `al_run_tests` with the codeunit ID, optional test method names, and the test-project
     folder. It reads connection settings from `launch.json` when explicit values are omitted.
- For an already-published SaaS package, call `al_run_tests` directly
- `al_run_tests` returning `succeeded=false` means a test or test run failed. Report the returned
  method result, assertion/error output, call stack, and pass/fail/skip counts; do not treat the
  tool failure as an infrastructure failure by default.
- The tool may return a duplicate empty-method summary record. Base the human-readable result on
  named test methods and explain this artifact when it affects aggregate counts.
- For non-interactive SaaS/CI execution, provide a pre-acquired Entra token through
  `BC_ACCESS_TOKEN`. For local interactive use, allow the tool to authenticate through AAD.
- For non-SaaS targets, run the suite and confirm it is green. Use
  `references/run-tests.md` for the headless `ALTestRunner` command (derives ids, names,
  and launch config from the project; works across AL projects).
- Trust the console Success/Failure lines; ignore the documented non-fatal noise.

9. Report outcome clearly.
- List created or updated test files.
- Report the per-codeunit Success/Failure results from the run, including the named SaaS test
  method result and useful error output when it fails.
- Map tests to the scenarios they cover.
- Note residual gaps and next tests to add.

## References

- Read `references/test-checklist.md` for review-time quality checks.
- Read `references/test-templates.md` for baseline test codeunit patterns.
- Read `references/run-tests.md` to run the suite headless after changes.
