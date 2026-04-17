<!-- blint-managed v2 -->
Check all Blint patterns against recently changed files using a two-phase approach.

1. Read all pattern files from `.blint/patterns/`. Each file is markdown with YAML frontmatter. Relevant frontmatter fields:
   - `match`: a natural language description of what files the pattern applies to (e.g. "database files including migrations, typeorm entities, seeds")
   - `matchCriteria`: computed matching rules with `globs` (array of file patterns) and optionally `contentMatch` (array of strings to match in file contents)
   - The pattern body contains the rules to check against.

2. Run `git diff --name-only HEAD` to find changed files. If there are no changes, check `git diff --name-only HEAD~1` instead.

3. **Phase 1 — Determine applicability.** For each changed file, determine which patterns apply:
   - If the pattern has `matchCriteria.globs`, check if the file path matches any of the globs.
   - If the pattern has `matchCriteria.contentMatch`, check if the file contains any of the specified strings.
   - If the pattern only has a `match` description (no computed criteria), use your judgement based on the description to decide if the pattern is relevant to this file. Err on the side of inclusion.

4. **Phase 2 — Check compliance.** For each applicable pattern, read the changed file and verify it complies with the pattern rules described in the pattern body.

5. Report results:
   - Which files were checked
   - Which patterns were applied to each file (and why — glob match, content match, or judgement from match description)
   - Any compliance issues found
   - Suggestions for fixing non-compliant code
