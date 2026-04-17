<!-- blint-managed v6 -->
Look through the current conversation to find which spec was run via `/start-spec`. The spec file will be at `specs/<name>.md`.

Read that spec file, then update its YAML frontmatter to set `implementedAt` to the current ISO timestamp (e.g. `2026-03-20T10:30:00.000Z`). Do NOT remove or change any other frontmatter fields — leave `environment`, `environmentPath`, `environmentBranch`, `commencedAt`, and all other timestamps exactly as they are.

**Environment-aware completion:**
- If the spec's `environment` is `original` (working directly in the project), setting `implementedAt` marks the spec as complete. Tell the user the spec is done.
- If the spec's `environment` is `worktree` or `copy`, setting `implementedAt` means the implementation is done but the branch still needs to be merged. Tell the user to create a PR and merge the branch, then Blint will auto-detect the merge and mark it complete.

If the `--skip-review` flag is passed, skip the pattern check reminder and proceed directly with setting `implementedAt`.

If the `--skip-review` flag is NOT passed and the spec does not already have a `patternCheckedAt` timestamp, remind the user to run `/check-patterns` before marking the spec as complete, to verify the implementation matches project patterns. If they confirm they want to skip the check, proceed with setting `implementedAt` anyway.

If no spec was run in this conversation, tell the user that no active spec was found.
