<!-- blint-managed v4 -->
Generate or refine codebase design documentation: $ARGUMENTS

## Instructions

**Determine the mode** based on `$ARGUMENTS`:

- If `$ARGUMENTS` starts with `--refine` followed by a file path, read that doc file. If the file body is empty (only frontmatter or blank), treat it as a **new doc** — use the filename and any frontmatter `name` field as context for what the user wants documented. If the file has content, treat it as **refining existing documentation**.
- If `$ARGUMENTS` is empty, ask the user what aspect of the codebase they want documented. Wait for their response before proceeding.
- Otherwise, treat `$ARGUMENTS` as the user's description of what to document.

## New documentation (empty file or description provided)

1. Ask the user to describe what they want documented. Use the file's `name` frontmatter (if present) as a starting point — e.g. "I see this doc is called 'Authentication Flow'. Can you describe what aspects of authentication you want captured?" Wait for their response.

2. Explore the relevant code — read the key files, understand the architecture, entities, relationships, data flow, and design decisions.

3. Write the documentation content **into the file specified by `--refine`** (or create a new file in the project's docs directory if no file was specified). Update the YAML frontmatter:

```yaml
---
name: <Title of the Documentation>
description: <One-line summary of what this covers>
version: 1
match: <Natural language description of which files this doc covers>
matchCriteria:
  globs:
    - "<glob pattern matching the files this doc covers>"
---
```

4. Follow the documentation writing principles defined in the project's `CLAUDE.md` under the "Writing Documentation" section. In short: open with a preamble, focus on concepts and design intent, include implementation details only where they are load-bearing, avoid inventories and code dumps, prefer conventions over instructions, and keep it concise. If `CLAUDE.md` has no such section, fall back to these principles directly.

5. After writing the doc, verify it reads well and covers the key design concepts without being overly verbose.

## Refining existing documentation (file has content)

1. Read the documentation file and present a brief summary of the current doc (title, description, what it covers) to the user.
2. Ask the user what they want to change — additions, corrections, restructuring, scope changes, etc.
3. Update the doc file in place. Increment the `version` number in frontmatter. Preserve all other frontmatter fields unless the user explicitly asks to change them.
4. Show the user what changed.
