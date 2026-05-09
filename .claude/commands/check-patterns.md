<!-- blint-managed v5 -->
See `CLAUDE.md` → **Authoring Blint Files** for the full spec frontmatter reference. This command sets `reviewedAt` and nothing else.

Check Blint patterns AND documentation against recently changed files using a two-phase approach. Patterns describe explicit rules the code must follow; docs describe design principles, conventions, and architectural intent — both can produce compliance findings.

1. Read all pattern files from `.blint/patterns/` and all documentation files from `docs/`. Each file is markdown with YAML frontmatter. Relevant frontmatter fields:
   - `match`: a natural language description of what files the pattern or doc applies to (e.g. "database files including migrations, typeorm entities, seeds")
   - `matchCriteria`: computed matching rules with `globs` (array of file patterns) and optionally `contentMatch` (array of strings to match in file contents)
   - For patterns, the body contains explicit rules to check against. For docs, the body describes conventions and design intent — treat any prescriptive guidance ("must", "should", "never", or clearly stated conventions) as rules to check.

2. Run `git diff --name-only HEAD` to find changed files. If there are no changes, check `git diff --name-only HEAD~1` instead.

3. **Phase 1 — Determine applicability.** For each changed file, determine which patterns and docs apply:
   - If the pattern or doc has `matchCriteria.globs`, check if the file path matches any of the globs.
   - If the pattern or doc has `matchCriteria.contentMatch`, check if the file contains any of the specified strings.
   - If only a `match` description is present (no computed criteria), use your judgement based on the description to decide if the pattern or doc is relevant to this file. Err on the side of inclusion.

4. **Phase 2 — Check compliance.** For each applicable pattern or doc, read the changed file and verify it complies with the rules or conventions described in the body. For docs that don't read as explicit rules, check that the change respects the design intent and conventions described.

5. Report results:
   - Which files were checked
   - Which patterns and docs were applied to each file (and why — glob match, content match, or judgement from match description)
   - Any compliance issues found, distinguishing pattern violations (explicit rules) from convention violations (doc-described conventions)
   - Suggestions for fixing non-compliant code

6. **Record the review.** Identify the active spec by looking through the current conversation for the spec that was started via `/start-spec` (its file lives at `specs/<name>.md`). Set `reviewedAt` in that spec's frontmatter to the current ISO timestamp (e.g. `2026-03-20T10:30:00.000Z`). Leave every other frontmatter field exactly as it is. Set the timestamp regardless of whether compliance issues were found — the timestamp records that the review was performed, not that it passed. If the user later fixes issues and asks for another review, re-run this command and overwrite the timestamp.

   If no active spec can be identified from the conversation, report the review results without setting a timestamp and tell the user which spec to update manually if they want the review recorded.
