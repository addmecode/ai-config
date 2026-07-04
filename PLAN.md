# Plan: Generic AI Config Repo with Symlink Sync

Turn this repository from a Codex-only skill pack into the **single source of
truth for all AI tool configuration** (Claude Code, OpenAI Codex, and future
models), and install it everywhere via **symbolic links** driven by a
declarative manifest and one idempotent sync script.

## 1. Goals

- One repo, one source of truth. Edit a file once; every tool sees the change
  instantly because destinations are symlinks into this repo.
- Declarative config: adding a model or a new link = editing a data file, not
  the script.
- One command to install/update all links, per-model or all-at-once, with a
  dry-run and idempotent re-runs.
- Safe migration from the current copies, with backups and rollback.

## 2. Current State (verified)

| Thing | State |
| --- | --- |
| Repo content | Only `skills/` (8 AL skills), each with `SKILL.md`, `references/`, `scripts/`, `agents/openai.yaml`. |
| `~/.codex/skills/<name>` | Real **copies** (not links). |
| `~/.claude/skills/<name>` | Symlinks chained to the Codex copies. |
| Repo → tools | Nothing links back to this repo yet. |
| Example script | `Add-SymbolicLinkForSettingsJson.ps1` — hardcoded paths, depends on a `Modules/Shared` (Git/File) module that is **not present** at the referenced path. |
| Symlink source of truth direction | To be inverted: **destinations must point into the repo.** |

## 3. Target Repository Layout

All tracked content is model-agnostic and shared. Skills stay self-contained
(a skill dir includes its own `agents/openai.yaml`; tools ignore what they
don't use).

Top-level folders are grouped by role: `linked/` (synced payload), `config/`
(settings), `tools/` (scripts).

```text
ai-config/
  linked/                      # SYNCED — everything here is symlinked into tools
    skills/                    # shared, model-agnostic skill content
      al-conventions/ ...      # SKILL.md + references/ + scripts/ + agents/
    memory/
      MEMORY.md                # THE single shared memory / global instructions
  config/                      # SETTINGS
    links.psd1                 # THE declarative mapping (see section 4)
  tools/                       # SCRIPTS — never linked out
    Sync-AiConfig.ps1          # the one entry point (see section 5)
    lib/
      Symlink.psm1             # New/Test/Remove link helpers, admin check
  README.md
  PLAN.md
```

Only two things are synced to every tool: **skills** and the **shared memory
file** (both under `linked/`). No per-model config directory exists —
tool-specific settings, agents, commands, and rules are left machine-local and
are not tracked here.

**Shared memory file:** `linked/memory/MEMORY.md` is the one source of truth for
global instructions/memory. Each tool reads its memory from a different
*filename* but the same *content*, so the manifest links that one file to each
tool's expected name — `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` both
resolve to `linked/memory/MEMORY.md`. Edit it once, every model sees it. A
future model just adds
one more link to the same file. (This covers the human-readable instructions
memory; Claude's structured per-project `memory/` fact-store is a separate,
Claude-specific format and is out of scope.)

Migration note: existing `agents/openai.yaml` files stay inside each skill dir —
no move needed.

## 4. Declarative Link Manifest (the "easy to config" part)

A single PowerShell data file `config/links.psd1`. Adding a model or link is a
one-entry edit. Targets use `~` / env-var tokens expanded at runtime so the file
stays machine-independent.

```powershell
@{
  # Reusable base dirs, expanded at runtime.
  Roots = @{
    Claude = '~/.claude'
    Codex  = '~/.codex'
  }

  Models = @{

    codex = @{
      Enabled = $true
      Links = @(
        # source (repo-relative) -> target (absolute/tokenized), Type children|dir|file
        @{ Source = 'linked/skills';           Target = '{Codex}/skills';    Type = 'children' }
        @{ Source = 'linked/memory/MEMORY.md'; Target = '{Codex}/AGENTS.md'; Type = 'file' }  # shared memory
      )
    }

    claude = @{
      Enabled = $true
      Links = @(
        @{ Source = 'linked/skills';           Target = '{Claude}/skills';    Type = 'children' }
        @{ Source = 'linked/memory/MEMORY.md'; Target = '{Claude}/CLAUDE.md'; Type = 'file' }  # shared memory
      )
    }
  }
}
```

### Link `Type` semantics

- `file` — symlink a single file (target parent dir auto-created).
- `dir` — symlink a whole directory as one link.
- `children` — do **not** link the parent; iterate each child of `Source` and
  create one link per child inside `Target` (e.g. link every skill folder
  individually into `~/.codex/skills`). **This is the chosen mode for skills:**
  it matches the current per-skill layout and lets each tool keep extra local
  or marketplace-installed skills alongside the linked ones without polluting
  the repo.

## 5. Sync Script Design (`tools/Sync-AiConfig.ps1`)

Single entry point. Idempotent. No hardcoded paths.

**Parameters**
- `-Model <name[]>` — subset of the enabled models to sync; default = all
  `Enabled` models. A disabled model named here is skipped with a warning.
  Whether a model can be linked is controlled solely by `Enabled` in the manifest.
- `-WhatIf` — dry run: print every action, change nothing (built-in
  `SupportsShouldProcess`).
- `-Force` — replace any conflicting target (wrong link or real file/dir)
  without prompting.
- `-Unlink` — remove the managed symlinks (uninstall). Real files are never
  touched.

**Flow**
1. Resolve repo root from `$PSScriptRoot`; load `config/links.psd1`.
2. Preflight: verify symlink capability — **Developer Mode on** or **elevated
   session** (see section 7). Fail early with a clear message if neither.
3. Expand `{Root}` tokens and `~` in every target.
4. For each selected model → each link, resolve to concrete (source, target)
   pairs (`children` fans out to N pairs).
5. For each pair, decide state and act:
   - Missing → create link.
   - Correct link already (right target) → skip (idempotent no-op).
   - Wrong link (points elsewhere) → **prompt for confirmation** before
     replacing, unless `-Force`. Replaced link-only (no backup needed).
   - Real file/dir exists (not a link) → **back up** to
     `backups/<timestamp>/` then replace, unless `-WhatIf`; prompt unless
     `-Force`. Never silently delete real content.
6. Verify each created link resolves to the intended source; report a summary
   table (Created / Updated / Skipped / Backed-up / Failed).

**`lib/Symlink.psm1`** holds: `Test-SymlinkCapability`, `New-ConfigLink`
(dir vs file), `Test-LinkPointsTo`, `Backup-ExistingTarget`,
`Remove-LinkOnly`. Self-contained — no dependency on the external
`Modules/Shared` the example script used.

## 6. Per-Model Destination Reference

Only the first two columns are linked (skills + shared memory). The rest are
listed for reference and are **deliberately not linked** — see note below.

| Tool | Skills dir (linked) | Memory file (linked → `linked/memory/MEMORY.md`) | Settings (NOT linked) |
| --- | --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>/` | `~/.claude/CLAUDE.md` | `~/.claude/settings.json` |
| OpenAI Codex | `~/.codex/skills/<name>/` | `~/.codex/AGENTS.md` | `~/.codex/config.toml` |

**Why settings/config are excluded:** they hold machine-specific absolute paths
(`C:\Users\adrri\...` in permissions, statusline, MCP binaries) and
tool-managed, self-rewriting state (Codex's trusted-project list, plugin
enablement, cached marketplace paths). Linking them into the repo would produce
constant git churn from the tools' own writes and would not port to another
machine. They stay machine-local; only skills and instruction files are linked.

## 7. Windows Symlink Prerequisite

Symlinks on Windows need one of:
- **Developer Mode ON** (Settings → For developers) — lets a normal user create
  symlinks. Recommended; no elevation per run.
- **Elevated / admin** PowerShell session.

The script detects capability up front and stops with guidance if neither is
available. Document both options in the README.

## 8. Migration Steps (from current copies to links)

1. **Move source into the repo:** the authoritative skill content already lives
   here in `linked/skills/`. Create `linked/memory/MEMORY.md` as the single shared memory —
   seed it by merging the useful content from your current `~/.claude/CLAUDE.md`
   and `~/.codex/AGENTS.md`.
2. **Back up live copies:** `~/.codex/skills/*` are real copies — the script's
   backup step preserves them, but do a manual zip once for safety.
3. **Run dry:** `./tools/Sync-AiConfig.ps1 -WhatIf` and read the plan.
4. **Apply Codex:** `./tools/Sync-AiConfig.ps1 -Model codex` — replaces the
   copies with links into the repo (chained Claude links now dangle).
5. **Apply Claude:** `./tools/Sync-AiConfig.ps1 -Model claude` — repoints the
   chained Claude links directly at the repo.
6. **Verify:** both tools list all 8 skills; edit one `SKILL.md` in the repo and
   confirm both tools see the edit.

## 9. Uninstall / Rollback

- `-Unlink` plus a manifest edit removes managed links.
- `backups/<timestamp>/` holds any real content the script replaced; restore by
  copying back.
- Removing a link never touches repo content (links are removed link-only, never
  recursively into the target).

## 10. Adding a New Model Later (the payoff)

1. Add a `Models.<tool>` block to `config/links.psd1` with two links: a
   `skills` (children) link, and a memory link pointing at the shared
   `linked/memory/MEMORY.md` under that tool's expected filename.
2. `./tools/Sync-AiConfig.ps1 -Model <tool> -WhatIf`, then without `-WhatIf`.

The new model automatically shares the same memory as Claude and Codex.

No script code changes — configuration only.

## 11. Work Breakdown

1. Restructure repo: add `linked/`, `config/`, `tools/lib/`.
   Create `linked/memory/MEMORY.md` by merging current `CLAUDE.md` + `AGENTS.md`.
2. Write `config/links.psd1` for `codex` + `claude`, both memory links
   pointing at `linked/memory/MEMORY.md`.
3. Implement `lib/Symlink.psm1` helpers + capability check.
4. Implement `Sync-AiConfig.ps1` (params, expansion, state machine, summary).
5. Seed `linked/memory/MEMORY.md`; dry-run; apply codex then claude; verify.
6. Update `README.md`: repo is now multi-model; document prerequisites and the
   sync command. Retire the hardcoded `Add-SymbolicLinkForSettingsJson.ps1`
   (or keep as a thin example).
```

## Decisions Made

- **Skill linking:** per-skill (`children`) — each skill is its own link so
  tools can keep extra local/marketplace skills without touching the repo.
- **settings.json / config.toml:** NOT tracked and NOT linked — machine-local,
  self-rewriting, non-portable. Only skills + instruction files are synced.
- **Platform:** Windows / PowerShell only. No bash twin, no macOS/Linux path
  handling — targets and helpers assume Windows and NTFS symlinks.
- **Shared memory:** one file `linked/memory/MEMORY.md` is linked to every tool's
  memory filename (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and future
  models). One edit updates all models. Per-tool instruction files are dropped.
