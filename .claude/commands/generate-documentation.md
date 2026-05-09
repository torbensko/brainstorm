<!-- blint-managed v5 -->
Generate or refine codebase design documentation: $ARGUMENTS

**Frontmatter reference:** see `CLAUDE.md` → **Authoring Blint Files** → Documentation. Fill in every applicable field, including `match`. Bump `version` on every body change.

**Writing style:** see `CLAUDE.md` → **Writing Documentation** for the body principles (concepts over inventories, design intent, conventions over instructions, etc.). If that section is missing, fall back to: focus on concepts and design intent, include implementation details only where they are load-bearing, avoid inventories and code dumps, prefer conventions over instructions, keep it concise.

## Instructions

**Determine the mode** based on `$ARGUMENTS`:

- If `$ARGUMENTS` starts with `--refine` followed by a file path, read that doc file. If the file body is empty (only frontmatter or blank), treat it as a **new doc** — use the filename and any frontmatter `name` field as context for what the user wants documented. If the file has content, treat it as **refining existing documentation**.
- If `$ARGUMENTS` is empty, ask the user what aspect of the codebase they want documented. Wait for their response before proceeding.
- Otherwise, treat `$ARGUMENTS` as the user's description of what to document.

## New documentation (empty file or description provided)

1. Ask the user to describe what they want documented. Use the file's `name` frontmatter (if present) as a starting point — e.g. "I see this doc is called 'Authentication Flow'. Can you describe what aspects of authentication you want captured?" Wait for their response.

2. Explore the relevant code — read the key files, understand the architecture, entities, relationships, data flow, and design decisions.

3. Write the doc into the file specified by `--refine`, or create a new file in the project's docs directory if no file was specified. Author the frontmatter per the **Authoring Blint Files** reference in `CLAUDE.md`, and the body per the **Writing Documentation** guidance.

4. After writing the doc, verify it reads well and covers the key design concepts without being overly verbose.

## Refining existing documentation (file has content)

1. Read the documentation file and present a brief summary of the current doc (title, description, what it covers) to the user.
2. Ask the user what they want to change — additions, corrections, restructuring, scope changes, etc.
3. Update the doc file in place. Increment the `version` number in frontmatter. Preserve all other frontmatter fields unless the user explicitly asks to change them.
4. Show the user what changed.
