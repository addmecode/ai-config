# Business Central Codex Skills

Reusable Codex skills for Microsoft Dynamics 365 Business Central AL development.

This repository is a skill pack, not a Business Central extension. It contains
specialized `SKILL.md` workflows, review checklists, implementation patterns, and
small helper scripts that guide Codex when working on AL projects.

## What Is Included

| Skill | Purpose |
| --- | --- |
| `al-conventions` | Baseline AL style, structure, extension-safety, review format, and general implementation rules. |
| `al-language-server` | AL project navigation, compiler/tooling discovery, build workflow, diagnostics, and post-edit review. |
| `al-solution-architect` | Architecture planning for Business Central extensions, including object maps, event/interface contracts, upgrades, integrations, and testing impact. |
| `al-object-builder` | Creation and scaffolding of AL tables, pages, codeunits, enums, interfaces, extensions, API objects, and upgrade objects. |
| `al-testing` | AL test planning, test codeunit structure, test project layout, helper scripts, and test execution guidance. |
| `al-integration` | HTTP, REST, OData, API page, webhook, pagination, authentication, retry, idempotency, and error-handling patterns. |
| `al-performance` | AL performance reviews and refactors for filters, keys, `SetLoadFields`, set-based operations, temporary tables, dictionaries, and migration throughput. |
| `al-upgrades` | Safe upgrade codeunit design using upgrade tags, guarded reads, `DataTransfer`, idempotent routines, and review checklists. |

## Repository Layout

```text
skills/
  al-conventions/
    SKILL.md
    references/
    agents/
  al-language-server/
    SKILL.md
    scripts/
    agents/
  al-object-builder/
    SKILL.md
    references/
    agents/
  al-testing/
    SKILL.md
    references/
    scripts/
    agents/
  ...
```

Each skill directory follows the same basic shape:

- `SKILL.md` contains the trigger description and workflow instructions.
- `references/` contains checklists, templates, and implementation patterns used
  only when relevant.
- `scripts/` contains helper automation for build or test workflows.
- `agents/openai.yaml` provides display metadata and default prompts for OpenAI
  Codex-compatible environments.

## Installation

Clone the repository:

```powershell
git clone https://github.com/<owner>/<repo>.git
cd <repo>
```

Copy the skills into your Codex skills directory.

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex\skills" | Out-Null
Copy-Item -Recurse -Force .\skills\* "$env:USERPROFILE\.codex\skills\"
```

Restart Codex after installation so the new skills are discovered.

## Usage

Reference a skill explicitly in a Codex prompt:

```text
Use $al-object-builder to create a setup table and card page for this feature.
```

```text
Use $al-testing to add tests for the posting validation behavior.
```

```text
Use $al-performance to review this report for avoidable database reads.
```

The skills are designed to work together. For example, `al-object-builder`
applies `al-conventions` first, and architecture work can hand off to object
creation, integration, performance, upgrade, or testing skills as the task
narrows.

## Requirements

- A Codex environment that supports local skills.
- A Business Central AL project when using the AL-specific workflows.
- The Microsoft AL Language extension when using compiler, diagnostics, or
  language-server-assisted workflows.
- A configured Business Central test environment when running AL test scripts.

The helper scripts are intentionally small and local. Review them before use in
your own environment, especially if your AL toolchain, container setup, or
authentication model differs.

## Design Principles

These skills encode a few consistent preferences:

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