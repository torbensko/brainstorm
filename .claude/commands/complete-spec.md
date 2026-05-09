<!-- blint-managed v8 -->
See `CLAUDE.md` → **Authoring Blint Files** for the full spec frontmatter reference. This command sets `implementedAt` and nothing else.

Look through the current conversation to find which spec was run via `/start-spec`. The spec file will be at `specs/<name>.md`.

Read that spec file, then set `implementedAt` in the frontmatter to the current ISO timestamp (e.g. `2026-03-20T10:30:00.000Z`). Leave every other frontmatter field exactly as it is.

**Environment-aware completion:**
- If the spec's `environment` is `original` (working directly in the project), setting `implementedAt` marks the spec as complete. Tell the user the spec is done.
- If the spec's `environment` is `worktree` or `copy`, setting `implementedAt` means the implementation is done but the branch still needs to be merged. Tell the user to create a PR and merge the branch, then Blint will auto-detect the merge and mark it complete.

If the `--skip-review` flag is passed, skip the pattern check reminder and proceed directly with setting `implementedAt`.

If the `--skip-review` flag is NOT passed and the spec does not already have a `reviewedAt` timestamp, remind the user to run `/check-patterns` before marking the spec as complete, to verify the implementation matches project patterns and conventions. If they confirm they want to skip the review, proceed with setting `implementedAt` anyway.

If no spec was run in this conversation, tell the user that no active spec was found.
