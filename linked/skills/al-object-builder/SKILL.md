---
name: al-object-builder
description: Build Microsoft Dynamics 365 Business Central AL objects with consistent structure and naming. Use when creating new AL tables, pages, codeunits, enums, interfaces, table extensions, page extensions, API objects, or upgrade codeunits, including file placement, object IDs, and baseline procedure/event scaffolding.
---

# AL Object Builder

Follow this sequence.

1. Apply baseline conventions first.
- Use `$al-conventions` as baseline for naming, formatting, and review output.

2. Confirm AL scope and workspace shape.
- Continue only if the repo contains `app.json`, `.al` files, or AL launch configuration.
- Read the nearest `app.json` and capture `idRanges`.

3. Gather object intent before coding.
- Identify object type, business feature, and target folder.
- Identify whether object is application code or test code.
- If test code is not explicitly requested, do not generate test objects.

4. Select file and object naming.
- Use PascalCase object names and meaningful terms.
- Keep names concise and use `<ObjectName>.<ObjectType>.al` filenames.
- Place files in feature folders (`src/<feature>/...`) rather than object-type folders.
- Use table/page extension objects instead of direct modifications to standard objects.

5. Allocate IDs safely.
- Use an ID in project `idRanges`.
- Avoid reusing IDs already present in existing object files.
- Keep related object IDs grouped when adding multiple files in one feature.

6. Scaffold by object type.
- Use `references/object-templates.md` for baseline structures.
- For codeunits, create small focused procedures and prefer positive event-driven extension points.
- For pages and codeunits, keep triggers as one-line delegators when they perform workflow logic; put the workflow in a purpose-named local procedure.
- For pages, keep only field backing variables and genuinely shared state global. Put codeunit variables, records, temporary values, and labels in local procedure `var` sections when used by one procedure.
- For setup, wizard, and NavigatePage objects, keep detection state separate from user action state. Use explicit variables for facts (`...Exists`), intended actions (`Create...`, `Update...`), and UI state (`...Enabled`, `...Visible`) instead of relying on inverted Booleans.
- In setup wizards, preserve the policy difference between mandatory creation and optional update. Missing required setup can be forced/create-only, while existing setup should remain a user choice when the workflow requires it.
- For codeunits, keep public entry points first and place the helper chain immediately below the entry point that uses it. Keep read/default helper groups and write-flow helper groups contiguous; do not interleave show/open actions inside insert/update helper chains.
- Qualify global variables, labels, and current-object procedure calls with `this.`. Do not qualify locals, parameters, `Rec`, `CurrPage`, or record fields.
- Do not scaffold generic `OnBefore...IsHandled` events. Prefer interface-based replacement for alternate implementations and purpose-named events for additive extension points.
- For pages and page extensions, include only relevant fields/actions and avoid unused layout blocks.
- For upgrade codeunits, read `references/upgrade-object-rules.md` before writing logic.
- Hand off to `$al-upgrades` when the request is primarily upgrade logic.

7. Apply correctness and maintainability checks.
- Use 2-space indentation.
- Use labels instead of hardcoded user-facing error text.
- Filter early and use `SetLoadFields` before data reads when relevant.
- Keep read operations safe in upgrade logic (`if Get/Find* then`).

8. Produce output and verification.
- Summarize created files and chosen IDs.
- List assumptions or unresolved design decisions.
- Recommend next manual checks (build, publish, functional test) if execution is not performed.

## References

- Use `references/object-templates.md` for starter templates per AL object type.
- Use `references/upgrade-object-rules.md` for upgrade-specific safety rules.


