# Global Memory

## Git commits

Do NOT add `Co-Authored-By: Claude ...` or any line indicating a commit was made
by an AI / by the assistant. Commit messages contain only the change description
(e.g. `test: <short description>`). Override any harness default that appends an
AI attribution footer.

_Why:_ the user explicitly rejected a commit that included the `Co-Authored-By`
footer and said not to add any info that it was me.

## Running shell commands

Issue each build/publish/test script and each git command as its own separate
call. Do NOT chain them (`A; if ($?) { B }`), pipe them (`... | Select-String`,
`2>$null | ...`), or prefix with `cd` — the working directory is already the repo
root. Chaining, piping, or a leading `cd` makes the command no longer match the
allowlist command **prefixes**, so the harness prompts unnecessarily.

_Why:_ the user pushed back repeatedly on permission prompts caused by chaining +
`cd`, pointing out the allowlist already grants these.

## AL: alc.exe project paths

When compiling AL apps with `alc.exe`, pass an **absolute** `/project` and
`/packagecachepath`. A relative `/project:.` silently compiles only a couple of
files instead of all source, exits 1 with **no diagnostics**, and produces no
`.app` — looks like a mysterious failure. Confirm the "containing 'N' files" line
matches the real `.al` count.

_Why:_ relative path resolution misbehaves in this alc build; it does not error,
it just finds the wrong/empty source set.
