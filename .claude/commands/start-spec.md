<!-- blint-managed v7 -->
**Determine which spec to run:**

If `$ARGUMENTS` is provided, use it as the spec name.

If `$ARGUMENTS` is empty, infer the spec from the current git branch:
1. Run `git branch --show-current` to get the branch name.
2. Read `.blint/project.json` to check for a custom `branchPrefix` (default: `"spec"`).
3. If the branch matches `<prefix>/<spec-name>` (e.g. `spec/add-auth`), use `<spec-name>` as the spec name.
4. If the branch doesn't match or there's no branch, tell the user: "Could not infer spec from branch name. Usage: `/start-spec <spec-name>`" and stop.

Read the spec file at `specs/<spec-name>.md` and execute it.

First, read the spec file and understand the task described in it. The file is markdown with YAML frontmatter containing metadata (name, type, and lifecycle timestamps: `commencedAt`, `patternCheckedAt`, `implementedAt`, `mergedAt`).

**Before doing anything else:** Update the spec file's YAML frontmatter to set `commencedAt` to the current ISO timestamp (e.g. `2026-03-20T10:30:00.000Z`). This signals to Blint that work has begun. Do NOT remove or change any other frontmatter fields.

**Lifecycle timestamps are managed by Blint — do not set them yourself.** `commencedAt` is the ONLY timestamp you set in this command. Never set, modify, or remove `patternCheckedAt`, `implementedAt`, or `mergedAt` — those belong to `/check-patterns`, `/complete-spec`, and Blint's auto-detection respectively. Even if you finish all the implementation work in this session, leave the spec frontmatter alone (apart from `commencedAt`) and let the user mark the spec complete via Blint's UI or by explicitly running `/complete-spec`.

**Pattern references:** The spec may contain `@.blint/patterns/...` references (e.g. `@.blint/patterns/async-loading`). For each such reference, read the referenced pattern file and use its content as additional context and constraints for the implementation. The pattern body describes rules that the implementation must follow.

**Documentation check:** Before planning or implementing, scan `docs/` for any documentation files whose `matchCriteria.globs` overlap with files you expect to create or modify. Read any matching docs — they describe design principles, conventions, and architectural intent that your implementation should follow. If your changes would warrant updating the documentation, note this in your plan/summary.

If the spec type is "feature":
1. Create a plan for implementing the feature based on the spec content
2. Present the plan and ask for confirmation before proceeding
3. Implement the plan step by step

If the spec type is "refinement":
1. Execute the change described in the spec directly
2. Verify the change works as expected

After completing the work, summarize what was done.
