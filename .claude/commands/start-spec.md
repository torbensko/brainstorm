<!-- blint-managed v11 -->
See `CLAUDE.md` → **Authoring Blint Files** for the full spec frontmatter reference, including which timestamps each command owns. This command sets `commencedAt` and nothing else.

**Determine which spec to run:**

If `$ARGUMENTS` is provided, use it as the spec name.

If `$ARGUMENTS` is empty, infer the spec from the current git branch:
1. Run `git branch --show-current` to get the branch name.
2. Read `.blint/project.json` to check for a custom `branchPrefix` (default: `"spec"`).
3. If the branch matches `<prefix>/<spec-name>` (e.g. `spec/add-auth`), use `<spec-name>` as the spec name.
4. If the branch doesn't match or there's no branch, tell the user: "Could not infer spec from branch name. Usage: `/start-spec <spec-name>`" and stop.

Read the spec file at `specs/<spec-name>.md` and understand the task.

**Before doing anything else:** set `commencedAt` in the spec's frontmatter to the current ISO timestamp (e.g. `2026-03-20T10:30:00.000Z`). This signals to Blint that work has begun. Leave every other frontmatter field exactly as it is — `reviewedAt`, `implementedAt`, `mergedAt`, and the environment fields belong to other commands and to Blint's auto-detection. Even if you finish all the implementation work in this session, do not set `implementedAt` here.

**Pattern references:** The spec may contain `@.blint/patterns/...` references (e.g. `@.blint/patterns/async-loading`). For each such reference, read the referenced pattern file and use its content as additional context and constraints for the implementation. The pattern body describes rules that the implementation must follow.

**Attachments:** The spec may contain image references like `![description](./attachments/filename.png)`. These are images stored in `specs/attachments/` (e.g. wireframes, screenshots, diagrams). Read any referenced image files to understand the visual context — they are part of the spec. When running via the Blint app, these images are automatically included as image blocks in the initial message.

**Relevant patterns and documentation check:** Before planning or implementing, skim all patterns and docs to find any that are relevant to this spec — not just the ones explicitly referenced with `@` syntax.

1. List all files in `.blint/patterns/` and read only the YAML frontmatter of each. Each pattern has a `description` (one-line summary of the rule) and `match`/`matchCriteria` (which files it targets). Use these to quickly judge relevance — if a pattern's description or target files overlap with what this spec will touch, read the full pattern.
2. List all files in `docs/` and read only the YAML frontmatter of each. Each doc has a `description` (one-line summary) and `matchCriteria.globs` (which files it covers). If a doc's description or target globs overlap with files you expect to create or modify, read the full doc.
3. For every pattern or doc you read in full, treat its content as additional context and constraints for the implementation. Patterns describe rules the code must follow; docs describe design principles, conventions, and architectural intent.
4. If your changes would warrant updating any documentation, note this in your plan/summary.

If the spec type is "feature":
1. Create a plan for implementing the feature based on the spec content
2. Present the plan and ask for confirmation before proceeding
3. Implement the plan step by step

If the spec type is "refinement":
1. Execute the change described in the spec directly
2. Verify the change works as expected

After completing the work, summarize what was done.
