# Building, publishing, and running AL unit tests headless

After every code change: rebuild the test app, publish it, run the suite, and report the
per-codeunit Success/Failure lines from the console. Works for any AL project that has the
`jamespearson.al-test-runner` VS Code extension, a test project with `app.json` +
`.vscode/launch.json`, and a running BC container referenced by that launch config.

The mechanics live in two parameterized scripts under this skill's `scripts/` folder — call
them with the right values; do not paste inline command blocks. Both derive everything else
from the project (Test Runner module resolved by wildcard; `ExtensionId`/`ExtensionName` from
`app.json`; launch config from the first `.vscode/launch.json` configuration, parsed as JSONC
because Windows PowerShell 5.1 rejects comments/trailing commas).

## 1. Build the test app

Compile with the `al-language-server` skill's build wrapper — it resolves `alc.exe`, defaults
the package cache to `<TestDir>\.alpackages`, and writes `<Publisher>_<Name>_<Version>.app`
(from `app.json`) into the test project folder. Use an absolute project path:

```
& "C:\Users\adrri\.claude\skills\al-language-server\scripts\Build-AlApp.ps1" -ProjectDir "<abs TestDir>"
```

## 2. Publish the test app (the runner does NOT republish)

`Invoke-ALTestRunner` only *runs* tests against the app **already published** in the
container. If you skip this, the run silently shows only the previously published codeunits.

```
scripts/Publish-AlTestApp.ps1 -ContainerName <container> -AppFile "<abs path to built .app>"
```

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

## 3. Run the suite

```
scripts/Invoke-AlTests.ps1 -TestDir "<abs path to test project>"
```

Run a single test instead of the whole suite:

```
scripts/Invoke-AlTests.ps1 -TestDir "<abs TestDir>" -FileName "<abs path to *.Codeunit.al>" -SelectionStart <line of the test procedure>
```

## Known non-fatal noise (tests already ran — trust the console output)

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
