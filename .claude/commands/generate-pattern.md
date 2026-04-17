<!-- blint-managed v1 -->
Generate a Blint pattern by examining existing code in the codebase: $ARGUMENTS

## Instructions

1. Read the user's description above to understand what codebase convention or practice they want captured as a pattern.

2. Explore the relevant code thoroughly — read the key files, trace the implementation, understand the approach, conventions, and design decisions actually in use. Look at multiple examples if they exist to identify the consistent parts vs incidental details.

3. Identify the **category** that best fits this pattern from the project's `activeCategories` in `.blint/project.json`. Use the `group:name` format (e.g. `quality:ci-cd`, `ops:environment`).

4. Create a pattern file in `.blint/patterns/`. The filename should be kebab-case matching the pattern name (e.g. `github-actions-build.md`). The file should be markdown with YAML frontmatter:

```yaml
---
name: <Pattern Name>
description: <One-line summary>
version: 1
category: <group:name from activeCategories>
match: <Natural language description of what files this pattern applies to>
matchCriteria:
  globs:
    - "<glob pattern>"
  contentMatch:          # optional — include only if specific strings reliably identify relevant files
    - "<string to match>"
---
```

5. Follow these writing principles for the pattern body:

   - **Describe the convention, not the implementation.** The reader should understand *what to do and why*, not be walked through the current code line by line.
   - **Extract the rules.** Identify the consistent, intentional choices — these are the pattern. Ignore incidental details that happen to be in the code but aren't part of the convention.
   - **Be prescriptive.** Patterns are rules, not documentation. Use "must", "should", "never" language. Each rule should be clearly actionable.
   - **Include the rationale.** For each major rule, briefly explain *why* — this helps developers apply the spirit of the pattern in edge cases.
   - **Use structure.** Group related rules under headings. Use bullet points for individual rules.
   - **No source code** unless a short snippet is genuinely essential to understanding the rule. Patterns that mirror code go stale.
   - **No hardcoded values.** Don't embed specific versions, URLs, or thresholds that will change. Describe the concept instead.
   - **Keep it concise.** Every sentence should earn its place. This is consumed by AI coding agents as well as humans.

6. After creating the pattern, show the user the file path and a brief summary of the key rules captured.
