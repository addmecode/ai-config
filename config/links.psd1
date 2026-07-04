@{
    # Reusable base directories, expanded at runtime ('~' resolves to $HOME).
    Roots = @{
        Claude = '~/.claude'
        Codex  = '~/.codex'
    }

    # One entry per model. Add a model = add a block here (no script changes).
    #   Source : repo-relative path (source of truth)
    #   Target : destination, may use {RootName} tokens from Roots above
    #   Type   : 'children' link each child individually | 'dir' | 'file'
    Models = @{

        codex  = @{
            Enabled = $true
            Links   = @(
                @{ Source = 'linked/skills';           Target = '{Codex}/skills';    Type = 'children' }
                @{ Source = 'linked/memory/MEMORY.md'; Target = '{Codex}/AGENTS.md'; Type = 'file' }
            )
        }

        claude = @{
            Enabled = $true
            Links   = @(
                @{ Source = 'linked/skills';           Target = '{Claude}/skills';    Type = 'children' }
                @{ Source = 'linked/memory/MEMORY.md'; Target = '{Claude}/CLAUDE.md'; Type = 'file' }
            )
        }
    }
}
