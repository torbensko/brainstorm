<!-- blint-managed v2 -->
Audit ALL files in the project against a specific Blint pattern.

Usage: /pattern-audit <pattern-name>

Unlike /check-patterns (which only checks recently changed files), this command checks every file in the project. This is useful when adopting a new pattern or verifying full compliance.

1. Read the pattern file from `.blint/patterns/$ARGUMENTS.md`. If the pattern is not found, list available patterns and ask the user to choose one.

2. Determine which files to check using the two-phase approach:
   - If the pattern has `matchCriteria.globs`, find all files matching those globs.
   - If the pattern has `matchCriteria.contentMatch`, also include files containing those strings.
   - If the pattern only has a `match` description (no computed criteria), use your judgement based on the description to identify relevant files. Scan the project structure and include files that semantically match the description.

3. For each matching file, read its content and verify it complies with the pattern rules described in the pattern body.

4. Report results:
   - Total number of files matched (and how: glob, content match, or judgement)
   - Number of compliant vs non-compliant files
   - For each non-compliant file: what rule was violated and a suggested fix
   - A summary of the most common violations

5. If the user agrees, offer to fix non-compliant files one by one or in batches.
