# Building, publishing, and running AL unit tests headless

## Validation scope and ownership

This procedure is for the assigned validation owner, or a standalone agent
authorized to execute tests. Designers, implementers, and read-only reviewers use
their applicable skill sections without executing this procedure in the shared
orchestration workflow. The project prompt determines required gates; this
reference determines the technical selection and order of operations.

Resolve the actual application/test folders from project configuration, not an
assumed `App/` layout. Inspect the applicable manifests and launch configurations.
Validate only affected projects and focused tests that verify changed behavior:

- **App source, version, or dependencies changed:** build App; when publication
  and tests are required, publish App before publishing/running its dependent Test
  app. Refresh Test's cached App artifact from that build before building Test.
- **Only Test changed:** build/publish Test and run focused tests; reuse the
  current App build/publication evidence rather than rebuilding or republishing it.
- **Test's cached App artifact is missing or stale:** reuse a verified current
  artifact if available, otherwise build App. Refresh the cache and ensure the
  matching App is published before dependent tests. Do not republish an identical
  verified artifact unnecessarily.
- **Build-only gate:** compile the affected project and needed dependencies,
  without adding publication or test execution to the contract.

For an App cache refresh, use the helper from `al-language-server` as its own call:

```powershell
& "<al-language-server skill root>\scripts\Sync-AlAppDependency.ps1" -AppProjectDir "<absolute AppDir>" -TestProjectDir "<absolute TestDir>"
```

It validates package identity and the Test dependency, skips identical contents,
and preserves other versions. Build App first when the available artifact has not
already been verified; synchronization itself is not build/publication evidence.

Do not repeat successful operations unless later edits invalidate them. Broaden
test execution only for a project requirement, new failures, or unresolved
regression concerns. Read direct operation results and exit status; report named
test-method outcomes and useful failure details, not only aggregate success.

## Wrapper usage

Use the documented interfaces below for `Invoke-AlSaaSTests.ps1`,
`Invoke-AlTests.ps1` and the container publication helper `Publish-AlTestApp.ps1`.
For build, SaaS publication and package synchronization, follow the wrapper
interfaces and usage policy in `al-language-server/SKILL.md`.
Do not reread script implementations or helper modules before routine calls, or
reconstruct their operations with inline shell commands.

Read script code only when a relevant change requires checking the documented
contract, an option or behavior remains unclear after consulting the documentation,
or an error requires implementation-level diagnosis. Start with the direct result
and compact failure details; inspect the operation log when those are insufficient,
then only the relevant parameters/functions if code inspection is needed.
Skipping repeated implementation reads does not permit skipping result/exit-status
checks, named test outcomes or required validation gates.

## Standalone operation calls

Invoke each build, publish, and test script as its own tool call. Do not chain
commands, pipe/redirect their output, or prefix them with `cd`; select the working
directory through the tool. Permission allowlists match command strings/prefixes,
so command wrappers can trigger unnecessary prompts. Read direct output and any
operation log provided by the script.

## SaaS path

Use the build/publication wrappers documented in `al-language-server/SKILL.md`
for the projects selected above. That skill owns wrapper options, tooling/runtime
resolution, build/publication output, and the MCP boundary.

After the selected build/publication operations, invoke the SaaS test wrapper:

```powershell
& "<al-testing skill root>\scripts\Invoke-AlSaaSTests.ps1" -TestDir "<absolute TestDir>" -CodeunitId <id> -Quiet
```

Use `-TestMethods <name>` to focus a method and `-LaunchConfiguration <name>` when
needed. The wrapper reads the test project's local launch configuration. Pass
`-Quiet` unless full console output is requested or needed for investigation;
it retains complete output under the test project's `.altool-logs` and returns
an actionable summary, including the failed method's error and up to five AL stack
frames. It redacts common bearer/JWT/secret forms in the summary (the full local
log remains sensitive). Named tests are counted separately from unnamed runner
records and runner aggregates; never treat an empty `PASS` as an extra test.
Report the log path and named results. Inspect the full log only when the compact
failure details are insufficient or the runner fails outside a named test.

## Non-SaaS container path

For required container validation, apply the affected-project rules above, then
build/publish the selected test app and run the focused tests. Works for any AL project that has the
`jamespearson.al-test-runner` VS Code extension, a test project with `app.json` +
`.vscode/launch.json`, and a running BC container referenced by that launch config.

The mechanics live in two parameterized scripts under this skill's `scripts/` folder — call
them with the right values; do not paste inline command blocks. Both derive everything else
from the project (Test Runner module resolved by wildcard; `ExtensionId`/`ExtensionName` from
`app.json`; launch config from the first `.vscode/launch.json` configuration, parsed as JSONC
because Windows PowerShell 5.1 rejects comments/trailing commas).

### 1. Build the test app

Compile with the `al-language-server` skill's build wrapper, using an absolute path:

```
& "<al-language-server skill root>\scripts\Build-AlApp.ps1" -ProjectDir "<abs TestDir>" -Quiet
```

For build-wrapper options and output handling, follow `al-language-server/SKILL.md`.

### 2. Publish the test app (the runner does NOT republish)

`Invoke-ALTestRunner` only *runs* tests against the app **already published** in the
container. If you skip this, the run silently shows only the previously published codeunits.

```
& "<al-testing skill root>\scripts\Publish-AlTestApp.ps1" -ContainerName <container> -AppFile "<abs path to built .app>" -Quiet
```

Always pass **`-Quiet`**: it silences the BcContainerHelper banner + permission warnings +
progress, leaving just `PUBLISHED OK` (a real failure still throws). Drop it only when
diagnosing a publish problem.

- The script publishes via the **development endpoint** (`-useDevEndpoint`, same as VS Code
  F5). This is deliberate: a plain `Publish-BcContainerApp` recompiles the app in-container
  whenever the app's `platform` version (from `app.json`, often a placeholder like
  `1.0.0.0`) is lower than the container's, and that recompile fails to resolve the
  app-under-test's symbols (`AL1024` + cascading `AL0791`/`AL0185`). The script also avoids
  `-replaceDependencies` for the same reason.
- **Credentials — Windows Credential Manager, auto-provisioned:** the script resolves a
  credential in this order: explicit `-Credential` → Credential Manager entry whose **Target
  name == the container name** → a one-time interactive prompt that it then **saves** to the
  vault. It also installs the `CredentialManager` module (and NuGet provider) on first use, so
  there are no manual setup steps. Consequence: the **first** publish for a given container
  needs the password typed once — have the user run that single publish via the session `!`
  prefix. **Every run after that is non-interactive**, so you run the full
  build → publish → run cycle yourself. After a container password change, re-prime with
  `-ResetCredential`. The vault entry (DPAPI, per user+machine) is the supported store — do
  not invent other credential-caching workarounds.
- The built `.app` is normally gitignored — leave it in place; it's the published artifact.

### 3. Run focused tests

```
& "<al-testing skill root>\scripts\Invoke-AlTests.ps1" -TestDir "<abs path to test project>"
```

Use a single-test selection when it covers the affected behavior. Use a broader
suite only under the selection rules above. `-SelectionStart` is the line of (or
inside) the `[Test]` procedure:

```
& "<al-testing skill root>\scripts\Invoke-AlTests.ps1" -TestDir "<abs TestDir>" -FileName "<abs path to *.Codeunit.al>" -SelectionStart <line of the test procedure>
```

`Invoke-AlTests.ps1` has **no `-Quiet`**: `Invoke-ALTestRunner` writes results through a channel
that stream-redirection (`6>&1`) does not capture, so a filter wrapper only scrambles order —
tried and reverted. Reduce its output by scope (single test) and frequency, not by filtering.
The fixed BcContainerHelper banner (~9 lines/run) cannot be trimmed from the wrapper.

### Known non-fatal noise (tests already ran — trust the console output)

- **Do NOT add `-GetCodeCoverage` / `-GetPerformanceProfile`** to the runner. They fire an
  `Invoke-WebRequest` that prompts for input; in non-interactive PowerShell this throws
  `NonInteractive mode...` *after* the tests have already executed.
- A trailing `Copy-FileFromBcContainer: Access to the path is denied` (copying the result XML
  into `.altestrunner`) is a `C:\ProgramData\BcContainerHelper` permissions warning, not a
  test failure. Fixable with admin + `Check-BcContainerHelperPermissions -Fix`, but
  unnecessary — the per-codeunit results printed to the console are authoritative.
- `WARNING: TaskScheduler is running in the container` is benign.

## Reporting

Report the per-codeunit and per-function `Success`/`Failure` lines. Example:

```
Codeunit 50141 AMC Smoke Test ......... Success
Codeunit 50146 AMC Blob Helper Tests .. Success (5/5)
```
