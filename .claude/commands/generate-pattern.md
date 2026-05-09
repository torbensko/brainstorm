<!-- blint-managed v4 -->
Generate or refine a Blint pattern: $ARGUMENTS

**Frontmatter reference:** see `CLAUDE.md` → **Authoring Blint Files** → Patterns. Fill in every applicable field, including `match`. Bump `version` on every body change.

## Instructions

**Determine the mode** based on `$ARGUMENTS`:

- If `$ARGUMENTS` starts with `--refine` followed by a file path, read that pattern file. If the file body is empty (only frontmatter or blank), treat it as a **new pattern** — use the filename and any frontmatter `name` field as context for what the user wants to capture. If the file has content, treat it as **refining an existing pattern**.
- If `$ARGUMENTS` is empty, ask the user what codebase convention they want captured. Wait for their response before proceeding.
- Otherwise, treat `$ARGUMENTS` as the user's description of the convention to capture.

## New pattern (empty file or description provided)

1. Ask the user to describe the codebase convention or practice they want captured. Use the file's `name` frontmatter (if present) as a starting point — e.g. "I see this pattern is called 'Error Handling Convention'. Can you describe what this convention looks like in your codebase?" Wait for their response.

2. Once you understand the convention, explore the relevant code thoroughly — read the key files, trace the implementation, understand the approach, conventions, and design decisions actually in use. Look at multiple examples if they exist to identify the consistent parts vs incidental details.

3. Pick one or more `categories` (array) from `activeCategories` in `.blint/project.json` (`group:name` format).

4. Write the pattern into the file specified by `--refine`, or create a new file in `.blint/patterns/` if no file was specified. Author the frontmatter per the **Authoring Blint Files** reference in `CLAUDE.md`.

5. Follow these writing principles for the pattern body:

   - **Describe the convention, not the implementation.** The reader should understand *what to do and why*, not be walked through the current code line by line.
   - **Extract the rules.** Identify the consistent, intentional choices — these are the pattern. Ignore incidental details that happen to be in the code but aren't part of the convention.
   - **Be prescriptive.** Patterns are rules, not documentation. Use "must", "should", "never" language. Each rule should be clearly actionable.
   - **Include the rationale.** For each major rule, briefly explain *why* — this helps developers apply the spirit of the pattern in edge cases.
   - **Use structure.** Group related rules under headings. Use bullet points for individual rules.
   - **No source code** unless a short snippet is genuinely essential to understanding the rule. Patterns that mirror code go stale.
   - **No hardcoded values.** Don't embed specific versions, URLs, or thresholds that will change. Describe the concept instead.
   - **Keep it concise.** Every sentence should earn its place. This is consumed by AI coding agents as well as humans.

6. After writing the pattern, show the user a brief summary of the key rules captured.

## Refining an existing pattern (file has content)

1. Read the pattern file and present a brief summary of the current pattern (name, description, key rules) to the user.
2. Ask the user what they want to change — new rules, rewording, scope changes, etc.
3. Update the pattern file in place. Increment the `version` number in frontmatter. Preserve all other frontmatter fields unless the user explicitly asks to change them.
4. Show the user what changed.
