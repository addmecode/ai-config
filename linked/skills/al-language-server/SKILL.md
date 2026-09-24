---
name: al-language-server
description: Use when working in Microsoft Dynamics 365 Business Central AL projects and the user asks to modify, refactor, review, navigate, or explain .al code. Locate the AL Language extension tooling such as alc.exe, altool, almcp, or the AL language server, use available AL Language Server Protocol or AL MCP/code-intelligence tools before code edits, and always perform a short code review after AL code modifications.
---

# AL Language Server

## Tool resolution and boundaries

Use AL MCP/LSP only for code intelligence: definitions, references, symbols, and diagnostics.
Do **not** use MCP for compilation, publishing, or test execution.

Use the wrappers in this skill instead of fixed tool paths. They resolve the newest installed
`ms-dynamics-smb.al-*` VS Code extension dynamically. `Build-AlApp.ps1` accepts both current
flat `bin\alc.exe` and legacy `bin\win32\alc.exe`; SaaS wrappers likewise resolve flat or
platform-specific `altool.exe`. SaaS wrappers select the newest x64 ASP.NET Core runtime supplied
by the VS Code .NET Runtime extension, set `DOTNET_ROOT` and process `PATH`, and never install a
runtime. `altool` uses cached AAD authentication unless `-NoCache` is requested for publishing.

## Build and publish wrappers

Compile an absolute project path with:

```powershell
& "<skill root>\scripts\Build-AlApp.ps1" -ProjectDir "<absolute project folder>"
```

`Build-AlApp.ps1` defaults the package cache to `<ProjectDir>\.alpackages` and derives
`<Publisher>_<Name>_<Version>.app` from `app.json`. It accepts `-OutputFile`,
`-PackageCachePath`, and `-AdditionalArgs`, and returns the compiler exit code.

Publish an already-built SaaS artifact with:

```powershell
& "<skill root>\scripts\Publish-AlApp.ps1" -ProjectDir "<absolute project folder>"
```

`Publish-AlApp.ps1` derives the artifact from `app.json` unless `-AppFile` is supplied. It reads
the project `.vscode\launch.json`, selects the named `-LaunchConfiguration` (or its only
configuration), validates an AAD Sandbox/Production target, and passes its environment, tenant,
authentication, and schema update values to `altool publishapp`. Use `-SchemaUpdateMode`,
`-ForceUpgrade`, or `-NoCache` only when needed. Read its direct output and exit status; only the
explicit server response that the identical package is already published is reported as skipped.

## Editing workflow

1. Confirm the workspace is an AL project and read nearby objects and dependencies.
2. Use MCP/LSP intelligence for symbols and diagnostics; use text search as a complement.
3. Make the smallest change consistent with AL conventions.
4. Compile with `Build-AlApp.ps1`; for a configured SaaS project, publish with
   `Publish-AlApp.ps1`. Do not substitute MCP for either operation.
5. Review changed AL code for behavior and local style, then report validation or its blocker.
