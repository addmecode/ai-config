---
name: al-language-server
description: Use when working in Microsoft Dynamics 365 Business Central AL projects and the user asks to modify, refactor, review, navigate, or explain .al code. Locate the AL Language extension tooling such as alc.exe, altool, almcp, or the AL language server, use available AL Language Server Protocol or AL MCP/code-intelligence tools before code edits, and always perform a short code review after AL code modifications.
---

# AL Language Server

Apply the role and project boundaries in `al-conventions`. Intelligence procedures
are available to every AL role; executable validation belongs to the role assigned
by the agent workflow. Loading this skill does not require a read-only or writing
subagent to compile or publish.

## Tool resolution and boundaries

Use AL MCP/LSP only for code intelligence: definitions, references, symbols, and diagnostics.
Do **not** use MCP for compilation, publishing, or test execution.

## Dependency source authority

When implementation, investigation, or review needs the source of an object
from a dependency, use **only the current project's `.alpackages` cache** as
the source authority.

1. Identify the exact dependency package from the project's `app.json` and
   `.alpackages` (publisher, name, and version), then inspect its locally
   available source.
2. If the matching `.app` is present but its source has not been extracted,
   extract that local package into a local directory under `.alpackages` before
   reading it. Do not substitute a package from another project, a global cache,
   or a different version.
3. Use the extracted/local source to verify namespaces, signatures, trigger
   behavior, permissions, and implementation details. LSP symbol information
   may help locate an object, but does not replace inspection of its matching
   local package source when source-level behavior matters.
4. Never download, fetch, clone, or cite dependency source from external
   locations for this purpose.
5. If the required object or source is absent from `.alpackages`, cannot be
   extracted locally, or its package/version cannot be identified, stop that
   source-dependent work and report the missing dependency source to the user.
   Do not infer the implementation from memory or obtain it from an external
   source.

Use the wrappers in this skill instead of fixed tool paths. They resolve the newest installed
`ms-dynamics-smb.al-*` VS Code extension dynamically. `Build-AlApp.ps1` accepts both current
flat `bin\alc.exe` and legacy `bin\win32\alc.exe`; SaaS wrappers likewise resolve flat or
platform-specific `altool.exe`. SaaS wrappers select the newest x64 ASP.NET Core runtime supplied
by the VS Code .NET Runtime extension, set `DOTNET_ROOT` and process `PATH`, and never install a
runtime. `altool` uses cached AAD authentication unless `-NoCache` is requested for publishing.

### Wrapper output

Pass `-Quiet` to build and publish wrappers unless the user explicitly requests full console
output or an investigation requires it. The build wrapper retains the compiler's source
count and warning/error diagnostics even in quiet mode, and reports the artifact/exit
status; it does not save an operation log. The publish
wrapper retains complete output under `.altool-logs` in the target project and prints an
actionable summary. Report available log paths; on failure, inspect them and report useful
error details, excluding routine MSAL/AAD diagnostics.

## Build and publish wrappers

Compile an absolute project path with:

```powershell
& "<skill root>\scripts\Build-AlApp.ps1" -ProjectDir "<absolute project folder>" -UseCodeAnalyzers -Quiet
```

`Build-AlApp.ps1` defaults the package cache to `<ProjectDir>\.alpackages` and derives
`<Publisher>_<Name>_<Version>.app` from `app.json`. For local builds, use the
**VS Code build configuration, never AL-Go settings**.
Missing analyzers stop the build with an actionable error; never download/install
analyzers or change the VS Code extension installation automatically.

`-OutputFile`, `-PackageCachePath`, and other compiler options
through `-AdditionalArgs` remain available; `/analyzer:` and `/ruleset:` are rejected
in `-AdditionalArgs` to prevent bypassing this configuration policy.

Ruleset URLs are passed unchanged to `alc.exe`; the wrapper does not download,
materialize, or replace rulesets. `al.enableExternalRulesets = true` is not a
guarantee that standalone `alc.exe` supports external rulesets. Report `AL1033` as
a blocker, not as permission to substitute rules or use AL-Go settings.
Keep project and package-cache paths absolute, and verify the compiler's source
count matches the intended project.

Publish an already-built SaaS artifact with:

```powershell
& "<skill root>\scripts\Publish-AlApp.ps1" -ProjectDir "<absolute project folder>" -Quiet
```

`Publish-AlApp.ps1` derives the artifact from `app.json` unless `-AppFile` is supplied. It reads
the project `.vscode\launch.json`, selects the named `-LaunchConfiguration` (or its only
configuration), validates an AAD Sandbox/Production target, and passes its environment, tenant,
authentication, and schema update values to `altool publishapp`. Use `-SchemaUpdateMode`,
`-ForceUpgrade`, or `-NoCache` only when needed. Read its direct output and exit status; only the
explicit server response that the identical package is already published is reported as skipped.

## Role-specific procedures

- **Navigation and analysis:** confirm the AL project, inspect relevant objects and
  dependencies, and use MCP/LSP for definitions, references, symbols, and available
  diagnostics. Complement intelligence with scoped text search.
- **Implementation:** use AL intelligence before editing and make the smallest
  change consistent with `al-conventions`. Perform a short post-change self-review
  using its technical checklist and applicable specialized skills.
- **Executable validation:** the assigned validation owner checks diagnostics and
  compiles with the build wrapper. Publish an already-built artifact only when
  required by the project/user contract. For dependent App/Test validation and
  test execution, follow `al-testing/references/run-tests.md` rather than defining
  a second dependency-order procedure here.
- **Independent review:** inspect the assigned changes using applicable technical
  checklists and supplied validation evidence, without taking over execution.

For every performed operation, inspect its direct result/exit status and report
useful failures or blockers in the format required by the caller.
