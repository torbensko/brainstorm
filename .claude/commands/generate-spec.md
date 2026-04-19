<!-- blint-managed v1 -->
Generate or refine a spec: $ARGUMENTS

## Instructions

**Determine the mode** based on `$ARGUMENTS`:

- If `$ARGUMENTS` starts with `--refine` followed by a file path, read that spec file. If the file body is empty (only frontmatter or blank), treat it as a **new spec** — use the filename and any frontmatter `name` field as context. If the file has content, treat it as **refining an existing spec**.
- If `$ARGUMENTS` is empty, ask the user what they want to build. Wait for their response before proceeding.
- Otherwise, treat `$ARGUMENTS` as the user's description of what to build.

## New spec (empty file or description provided)

1. Ask the user to describe what they want to build or change. Use the file's `name` frontmatter (if present) as a starting point — e.g. "I see this spec is called 'Add User Authentication'. Can you describe what this feature should do?" Wait for their response.

2. Through conversation, help the user clarify:
   - What the feature/change does and why
   - Key requirements and constraints
   - Which parts of the codebase are involved
   - Any patterns or documentation that should be referenced (use `@.blint/patterns/<name>` syntax for pattern references)

3. Once the scope is clear, write the spec content **into the file specified by `--refine`** (or create a new file in `specs/` if no file was specified). Update the YAML frontmatter:

```yaml
---
name: <Spec Title>
type: feature  # or "refinement" for smaller changes
---
```

4. The spec body should be concise and actionable — describe what to build, not how to build it step by step. Include:
   - A clear statement of what the feature/change is
   - Key requirements (what must be true when done)
   - Any constraints or non-goals
   - Pattern references where relevant (`@.blint/patterns/<name>`)

5. After writing the spec, show the user a summary and ask if anything needs adjusting.

## Refining an existing spec (file has content)

1. Read the spec file and present a brief summary of the current spec (title, type, key requirements) to the user.
2. Ask the user what they want to change — scope adjustments, new requirements, clarifications, etc.
3. Update the spec file in place. Preserve all frontmatter fields (especially lifecycle timestamps) unless the user explicitly asks to change them.
4. Show the user what changed.
