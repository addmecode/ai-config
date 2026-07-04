---
name: al-language-server
description: Use when working in Microsoft Dynamics 365 Business Central AL projects and the user asks to modify, refactor, review, navigate, or explain .al code. Locate the AL Language extension tooling such as alc.exe, altool, almcp, or the AL language server, use available AL Language Server Protocol or AL MCP/code-intelligence tools before code edits, and always perform a short code review after AL code modifications.
---

# AL Language Server

## Purpose

Use the AL Language extension tooling to improve code understanding before editing Business Central AL projects. Prefer language-server or AL MCP/code-intelligence results over plain text search when the task involves symbols, references, diagnostics, or cross-object behavior.

## Locate AL Tooling

**Known good path (verified 2026-06-25)** — use this directly, do NOT run the discovery script when it still exists:

```
C:\Users\adrri\.vscode\extensions\ms-dynamics-smb.al-17.0.2273547\bin\win32\alc.exe
```

The sibling tools live in the same `bin\win32\` folder: `altool.exe`, `almcp.exe`, `Microsoft.Dynamics.Nav.EditorServices.Host.exe`.

**For compilation you do not need to locate `alc.exe` yourself** — use `scripts/Build-AlApp.ps1`, which checks the known-good default path first and otherwise scans the VS Code / Cursor / Windsurf extension folders for the newest installed AL Language extension. See "Compiling".

If you need a sibling tool (`altool`, `almcp`) directly, check `Test-Path` on the path above first; if it no longer exists (the extension was updated/uninstalled, changing the version segment), the `bin\<platform>\` folder for the newest `ms-dynamics-smb.al-<version>` extension under `%USERPROFILE%\.vscode\extensions\` holds the same tools. Verify supported commands with `/?` or `--help` because Microsoft may change CLI switches between extension versions.

## Compiling

Build an AL project with the wrapper script — it resolves the compiler, defaults the package cache to `<ProjectDir>\.alpackages`, and names the output `<Publisher>_<Name>_<Version>.app` from `app.json`:

```powershell
& "C:\Users\adrri\.claude\skills\al-language-server\scripts\Build-AlApp.ps1" -ProjectDir "<abs project folder>"
```

Override defaults with `-OutputFile`, `-PackageCachePath`, or pass extra `alc.exe` switches via `-AdditionalArgs`. The script exits non-zero on a failed build.

## Before Editing AL Code

1. Confirm the workspace is an AL project by checking for `app.json` and `.al` files.
2. Discover available language intelligence:
   - Use any exposed LSP, MCP, or code-intelligence tool for definitions, references, diagnostics, document symbols, and workspace symbols.
   - If no direct LSP client tool is available, use AL extension CLI support where possible. Check `alc.exe /?`, `altool --help`, `altool workspace --help`, and `altool launchmcpserver --help`.
   - If AL MCP server support is available, prefer it for project-aware symbol and diagnostic queries. The extension may also expose `almcp.exe`.
3. Use plain `rg` search as a fallback or complement, not as the only source for symbol relationships when language tooling is available.
4. Read nearby objects and dependencies before editing shared objects, events, interfaces, permissions, table/page extensions, or integration code.

## Editing Workflow

When the user asks for code changes in an open AL project:

1. Build with `scripts/Build-AlApp.ps1` (see "Compiling"); it resolves `alc.exe` for you. Sibling tools live in the same `bin\<platform>\` folder.
2. Use language-server, MCP, or compiler diagnostics to understand the requested object and related symbols.
3. Before follow-up edits in an active conversation, reread the current files from disk and inspect the current diff. Do not rely on remembered code after the user may have edited files or after previous tool calls changed them.
4. Make the smallest change that fits the existing project structure and AL conventions. For rename/reorder refactors, preserve behavior and explicitly check affected truth tables, captions, action enabled states, and save conditions.
5. Compile or run the narrowest available validation after edits:
   - Prefer the repo's existing build/test task.
   - Otherwise compile with `scripts/Build-AlApp.ps1 -ProjectDir <project-root>` when package cache and dependencies are available.
   - If compilation cannot run because symbols, credentials, containers, or package cache are missing, state that clearly.
6. Perform a short code review of the modified files before responding.
7. During the post-edit review, explicitly check the modified AL objects for local style regressions: trigger bodies should delegate to local procedures, single-use variables and labels should be local, current-object globals/procedures should use `this.`, procedures should read top-down from entry point to helper chain, and refactors should not have changed user-visible behavior accidentally.

## Required Post-Edit Review

After every code modification, include a concise review in the final response:

- What changed and where.
- Any ambiguity in the user's request.
- Assumptions made that the user did not explicitly specify.
- Validation performed, including compiler/test results or why validation could not run.
- Any remaining risk or follow-up needed.

Keep the review short and focused on actionable risks, not a full narrative.

