# Business Central AI Config

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows-0078D6?logo=windows&logoColor=white" alt="Platform: Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white" alt="PowerShell 5.1+">
  <img src="https://img.shields.io/badge/Dynamics_365-Business_Central_(AL)-0078D4" alt="Dynamics 365 Business Central (AL)">
  <img src="https://img.shields.io/badge/Claude_Code-supported-D97757" alt="Claude Code supported">
  <img src="https://img.shields.io/badge/OpenAI_Codex-supported-412991?logo=openai&logoColor=white" alt="OpenAI Codex supported">
</p>

AI assistant configuration for **Microsoft Dynamics 365 Business Central (AL)**
development, shared across multiple AI coding tools (Claude Code, OpenAI Codex,
and more).

This repository is the single source of truth. The included PowerShell script
installs its content into each tool's configuration location as **symbolic
links**, so one edit here reaches every tool.

It syncs two things to every tool:

- **Skills** — reusable `SKILL.md` workflows, checklists, and patterns for
  Business Central AL development, plus small helper scripts.
- **Shared memory** — one `linked/memory/MEMORY.md`, linked to each tool's
  memory file (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`), so every tool
  shares the same global instructions.

## Repository Layout

Top-level folders are grouped by role:

```text
linked/                    # SYNCED — everything here is symlinked into the tools
  skills/                  # model-agnostic skill content (source of truth)
    al-conventions/
      SKILL.md
      references/          # checklists, templates, patterns
      scripts/             # skill-owned helpers (synced with the skill)
      agents/openai.yaml   # Codex display metadata (ignored by tools that don't use it)
    ...
  memory/
    MEMORY.md              # single shared memory / global instructions

config/                    # SETTINGS — what links where (no code)
  links.psd1               # declarative source -> target link mapping

tools/                     # SCRIPTS — the sync tooling (never linked out)
  Sync-AiConfig.ps1        # installs/updates the links
  lib/
    Symlink.psm1           # symlink helpers
```

## Included Skills

Eight Business Central AL skills. Each is a folder with a `SKILL.md` workflow
plus bundled material the workflow pulls in on demand — `references/`
(checklists, patterns, templates) and, for three of them, `scripts/`
(PowerShell helpers, documented in [Helper Scripts](#helper-scripts) below).
`al-conventions` is the baseline companion; the others reference it and add a
specialized workflow on top.

| Skill | Purpose | Bundled files |
| --- | --- | --- |
| `al-conventions` | Baseline AL style, structure, extension-safety, review format, and general implementation rules. Loaded as the default companion for all AL work. | `core-checklist`, `upgrade-checklist` |
| `al-language-server` | AL project navigation, compiler/tooling discovery, build workflow, diagnostics, and post-edit review. Prefers language-server / AL MCP results over plain text search. | `Build-AlApp.ps1` |
| `al-solution-architect` | Architecture planning for Business Central extensions: object maps, event/interface contracts, upgrades, integrations, testing impact. | `architecture-checklist`, `architecture-patterns` |
| `al-object-builder` | Creation and scaffolding of AL tables, pages, codeunits, enums, interfaces, extensions, API objects, and upgrade objects — with file placement and object IDs. | `object-templates`, `upgrade-object-rules` |
| `al-testing` | AL test planning, test codeunit structure, App-vs-Test project layout, and test execution. | `run-tests`, `test-checklist`, `test-templates`, `Invoke-AlTests.ps1`, `Publish-AlTestApp.ps1` |
| `al-integration` | HTTP, REST, OData, API page, webhook, pagination, authentication, retry, idempotency, and error-handling patterns. | `integration-checklist`, `integration-patterns` |
| `al-performance` | AL performance reviews and refactors: filters, keys, `SetLoadFields`, set-based operations, temporary tables, dictionaries, migration throughput. | `performance-checklist`, `performance-patterns` |
| `al-upgrades` | Safe upgrade codeunit design using upgrade tags, guarded reads, `DataTransfer`, idempotent routines, and review checklists. | `upgrade-patterns`, `upgrade-review-checklist` |

## Helper Scripts

Three skills ship PowerShell helpers that automate the AL build → publish →
test loop against a local Business Central container. They are self-contained
(no shared module) and take Windows/PowerShell paths. Each derives what it can
from the project's own `app.json` / `launch.json` so there is little to pass by
hand.

Run them in this order for a full test cycle:

```powershell
# 1. Compile the app  (al-language-server)
linked/skills/al-language-server/scripts/Build-AlApp.ps1 -ProjectDir C:\proj\Test

# 2. Publish the built .app to the container  (al-testing)
linked/skills/al-testing/scripts/Publish-AlTestApp.ps1 `
    -ContainerName my-bc-container -AppFile C:\proj\Test\Publisher_Name_1.0.0.0.app

# 3. Run the tests headless  (al-testing)
linked/skills/al-testing/scripts/Invoke-AlTests.ps1 -TestDir C:\proj\Test
```

### `Build-AlApp.ps1` — compile an AL app (`al-language-server`)

Compiles an AL project with `alc.exe`. Locates the compiler automatically: it
tries a known-good default path first, then scans the VS Code extensions folder
and picks the **newest** installed `ms-dynamics-smb.al-*` extension. The output
name defaults to `<Publisher>_<Name>_<Version>.app` read from `app.json`, and
the symbol cache defaults to `<ProjectDir>\.alpackages`. Exits with `alc`'s own
exit code so it composes in a build pipeline.

| Parameter | |
| --- | --- |
| `-ProjectDir` *(required)* | AL project folder (must contain `app.json`). |
| `-OutputFile` | Override the output `.app` path. |
| `-PackageCachePath` | Override the symbol/package cache. |
| `-AdditionalArgs` | Extra args passed through to `alc.exe` (e.g. `/ruleset:…`, `/analyzer:…`). |
| `-Quiet` | Print only `BUILD OK`, or just the compiler error diagnostics on failure. |

### `Publish-AlTestApp.ps1` — publish to a BC container (`al-testing`)

Publishes a prebuilt `.app` to a Business Central container through the
**development endpoint** — the same mechanism as VS Code's F5 — so it deploys
the app as-is and deliberately avoids the in-container recompile that would
fail when the app's platform version is lower than the container's. Credentials
resolve in order: an explicit `-Credential`, then a Windows Credential Manager
entry named after the container, then a one-time interactive prompt whose result
is saved for later runs. The `CredentialManager` module (and NuGet provider) are
installed on first use — no manual setup.

| Parameter | |
| --- | --- |
| `-ContainerName` *(required)* | BC container name; also the Credential Manager target for lookup/storage. |
| `-AppFile` *(required)* | Path to the built `.app` to publish. |
| `-Credential` | `PSCredential` for UserPassword auth; otherwise resolved from the vault or prompt. |
| `-ResetCredential` | Force a fresh prompt and overwrite the stored entry (use after a password change). |
| `-Quiet` | Suppress the helper's banner; print only `PUBLISHED OK` (failures still throw). |

### `Invoke-AlTests.ps1` — run AL tests headless (`al-testing`)

Runs AL unit tests against a container using the `jamespearson.al-test-runner`
extension, deriving every value from the test project itself: it resolves
`ALTestRunner.psm1` by wildcard (version-agnostic), reads the ExtensionId/Name
from `app.json`, and takes the first configuration from `launch.json` — both
parsed as JSONC because PowerShell 5.1 rejects comments and trailing commas. The
per-codeunit `Success | Failure` lines printed to the console are authoritative.
Note: it executes against the app **already published** in the container — build
and publish first.

| Parameter | |
| --- | --- |
| `-TestDir` *(required)* | Test project folder (its `app.json` has the Test Runner / Library Assert deps and a `.vscode\launch.json`). |
| `-FileName` | Run a single `*.Codeunit.al` instead of the whole suite (requires `-SelectionStart`). |
| `-SelectionStart` | Line number of the test procedure to run when `-FileName` is given. |
| `-ResultsPath` | Where to write results. Defaults to `<TestDir>\.altestrunner`. |

## Requirements

- Windows with PowerShell. The sync tooling is Windows/PowerShell only.
- **Symlink capability**, one of:
  - **Developer Mode ON** (Settings → System → For developers → Developer Mode) —
    recommended; lets a normal user create symlinks without elevation.
  - An **elevated (Administrator)** PowerShell session.

`Sync-AiConfig.ps1` checks this up front and stops with guidance if neither is
available.

## Installation

Clone the repository:

```powershell
git clone https://github.com/addmecode/ai-config.git
cd ai-config
```

Preview what would change (no changes made):

```powershell
./tools/Sync-AiConfig.ps1 -WhatIf
```

Apply the links:

```powershell
./tools/Sync-AiConfig.ps1
```

This links, for every enabled model:

- each skill folder into the tool's skills directory (per-skill links, so the
  tool can keep its own local skills alongside), and
- `linked/memory/MEMORY.md` to the tool's memory file.

Restart the tool after the first install so it rediscovers its skills.

### How existing files are handled

The script never silently deletes real content:

| Target state | Action |
| --- | --- |
| Missing | Create the link |
| Correct link already | Skip (idempotent) |
| Wrong link (points elsewhere) | Prompt, then replace the link only |
| Real file / directory | Prompt, back up to `backups/<timestamp>/`, then replace |

Use `-Force` to skip the confirmation prompts.

## Usage

```powershell
# Sync only one model (must be enabled in the manifest)
./tools/Sync-AiConfig.ps1 -Model codex

# Remove managed links (uninstall); real files are left untouched
./tools/Sync-AiConfig.ps1 -Unlink
```

Whether a model can be linked is controlled only by its `Enabled` flag in
`config/links.psd1`. `-Model` selects a subset of the **enabled** models; a
disabled model is skipped even if named explicitly.

Reference a skill explicitly in a prompt:

```text
Use $al-object-builder to create a setup table and card page for this feature.
Use $al-testing to add tests for the posting validation behavior.
Use $al-performance to review this report for avoidable database reads.
```

## Configuring Models

Everything is driven by [`config/links.psd1`](config/links.psd1). To add a
model, add one block — no script changes:

```powershell
Models = @{
    <tool> = @{
        Enabled = $true
        Links   = @(
            @{ Source = 'linked/skills';           Target = '{<Root>}/skills';   Type = 'children' }
            @{ Source = 'linked/memory/MEMORY.md'; Target = '{<Root>}/<memory>'; Type = 'file' }
        )
    }
}
```

- `Roots` defines reusable base directories (`~` expands to your home folder).
- `Type` is `children` (link each child individually), `dir`, or `file`.

Then preview and apply:

```powershell
./tools/Sync-AiConfig.ps1 -Model <tool> -WhatIf
./tools/Sync-AiConfig.ps1 -Model <tool>
```

The new model automatically shares the same `linked/memory/MEMORY.md` as every other
tool.

## Design Principles

The AL skills encode a few consistent preferences:

- Feature-based folder organization instead of object-type folders.
- Extension-safe customization through events, interfaces, and subscribers.
- Thin triggers that delegate workflow logic to purpose-named procedures.
- Positive, purpose-named events instead of broad `IsHandled` patterns by
  default.
- Safe upgrade routines guarded by upgrade tags.
- Performance-conscious AL patterns such as early filtering, `SetLoadFields`,
  set-based operations, temporary records, dictionaries, and lists.
- Tests that are isolated, deterministic, and structured around observable
  behavior.
