<!-- blint-managed v5 -->
Compute match criteria for Blint patterns and documentation files that are missing or have stale `matchCriteria`.

## Scope

If a file path argument is provided (e.g. `/update-coverage path/to/file.md`), **only process that single file** — read it, compute its `matchCriteria`, update its frontmatter, and report. Skip everything else.

If no argument is provided, process all patterns and docs as described below.

## Patterns

1. Read all pattern files from `.blint/patterns/`. Each file is markdown with YAML frontmatter.

2. Identify patterns that need updating:
   - Patterns with a `match` description but no `matchCriteria` at all
   - Patterns where the `match` description may have changed since `matchCriteria` was last computed (use your judgement)
   - Skip patterns that have no `match` description

3. For each pattern that needs updating, read the `match` description (e.g. "database files including migrations, typeorm entities, seeds") and examine the project structure to determine appropriate `matchCriteria`.

   **Match the specificity to the nature of the pattern.** A broad architectural principle might match `["**/*"]`, while a pattern about a specific config file might list exact paths. Let the `match` description guide you:
   - For broad concepts (e.g. "all React components", "error handling"), use fewer, wider rules.
   - For nuanced or targeted patterns (e.g. "the database migration runner", "Stripe webhook handler"), be specific — exact paths are fine.
   - Typically only `globs` OR `contentMatch` is needed, not both. They are two different ways to express the same match — use whichever best captures the intent.
     - Use `globs` when the match is about file location or naming (e.g. "all storybook files" → `["**/*.stories.tsx"]`)
     - Use `contentMatch` when the match is about what the file contains, regardless of location (e.g. "files using Dialog" → `["<Dialog"]`)
   - If a pattern applies to the whole codebase, use a single wildcard glob like `["**/*"]`.
   - Avoid redundant or overlapping entries — one good glob is better than three specific ones that could be combined.

   Fields:
   - `globs`: an array of file glob patterns that would match the relevant files
   - `contentMatch` (optional): an array of strings that would appear in the content of relevant files

4. Update each pattern file's YAML frontmatter by adding or replacing the `matchCriteria` field:
   ```yaml
   matchCriteria:
     globs:
       - "src/db/**/*.ts"
   ```
   Do NOT modify the `match` description or any other frontmatter fields. Do NOT modify the pattern body.

## Documentation

5. Read all documentation files from `docs/` (or the project's configured docs directory). Each file is markdown with YAML frontmatter.

6. Identify docs that need updating: docs with no `matchCriteria`, or docs whose content has changed since criteria were last computed. Unlike patterns (which use a `match` description), docs may not have a `match` field — instead, **read the full documentation content** and determine which files in the project it describes or applies to.

7. For each doc, examine its content (the design principles, architecture, entities, and conventions it describes) and the project structure to compute appropriate `globs`. The same specificity guidance applies as for patterns — match the breadth of the criteria to the scope of the doc. Docs only use `globs`, not `contentMatch`.

8. Update the doc file's frontmatter `matchCriteria` field. Do NOT modify the body or other frontmatter fields.

## Report

9. Report what was updated:
   - Which patterns and docs had their criteria computed or refreshed
   - The globs chosen for each
   - Any items that were skipped and why
