<!-- blint-managed v2 -->
Generate codebase design documentation based on the user's description: $ARGUMENTS

## Instructions

1. Read the user's description above to understand what aspect of the codebase they want documented.

2. Explore the relevant code — read the key files, understand the architecture, entities, relationships, data flow, and design decisions.

3. Create a documentation file in the project's docs directory (default: `docs/`). The file should be markdown with YAML frontmatter:

```yaml
---
name: <Title of the Documentation>
description: <One-line summary of what this covers>
version: 1
match: <Natural language description of which files this doc covers>
matchCriteria:
  globs:
    - "<glob pattern matching the files this doc covers>"
---
```

4. Follow the documentation writing principles defined in the project's `CLAUDE.md` under the "Writing Documentation" section. In short: open with a preamble, focus on concepts and design intent, include implementation details only where they are load-bearing, avoid inventories and code dumps, prefer conventions over instructions, and keep it concise. If `CLAUDE.md` has no such section, fall back to these principles directly.

5. After creating the doc, verify it reads well and covers the key design concepts without being overly verbose.
