<!-- blint:documentation v2 -->
## Writing Documentation

Documentation in this project is consumed by AI coding agents as much as by humans. Its job is to preserve *design intent* so future work stays faithful to the original idea behind a feature — not to serve as a comprehensive technical specification.

For frontmatter fields (`name`, `description`, `version`, `match`, `matchCriteria`), see the **Authoring Blint Files** section above. `match` is mandatory on every doc.

- **Focus on concepts and design.** Describe the shape of the system — entities, lifecycles (e.g. how an object flows from frontend to backend), data flow, decision points. Enough for an agent to build new parts in the same spirit.
- **Implementation details only where they are load-bearing for the design.** A doc explaining how theming is applied across the app *should* be implementation-specific — applying the convention is the point. A doc on "how auth works" should not enumerate every function.
- **No inventories, no code dumps.** Don't list every file, function, or endpoint — those rot immediately. Describe the pattern so someone can find and follow it.
- **Conventions over instructions.** Say what the convention is and why, not step-by-step how-tos.
- **No hardcoded values** (thresholds, frequencies, counts) unless they are genuine invariants. These drift out of sync with code.
- **Concise.** Every sentence should earn its place.
<!-- /blint:documentation -->

<!-- blint:conventions v1 -->
## Conventions

- **DRY**: Don't Repeat Yourself. Extract shared logic into reusable functions or modules rather than duplicating code.
- **KISS**: Keep It Simple. Prefer the simplest solution that works. Avoid unnecessary complexity, abstractions, or indirection.
- **YAGNI**: You Aren't Gonna Need It. Do not build features, abstractions, or flexibility for hypothetical future requirements.
- **Single Responsibility**: Each module, class, or function should have one reason to change. Split code that serves multiple concerns.
- **Separation of Concerns**: Keep distinct concerns (UI, business logic, data access) in separate layers. Do not mix responsibilities.
- **Strict Schemas**: Use strict, typed schemas for all data structures. No loose JSON fields or untyped dictionaries in database columns or APIs.
- **Explicit Relationships**: Use explicit foreign keys and typed associations. Avoid polymorphic associations or generic reference columns.
- **Validate at Boundaries**: Validate data at system boundaries (user input, external APIs, deserialization). Trust validated data within the system.
- **Enums for Finite Sets**: Use enums or union types for finite sets of values (statuses, roles, categories). Never use raw strings for these.
- **Immutability by Default**: Prefer immutable data structures. Use const, readonly, and Object.freeze. Only mutate when there is a clear performance reason.
- **Fail Fast**: Validate preconditions and invariants early. Throw or return errors immediately on invalid state rather than continuing.
- **No Silent Failures**: Never swallow errors silently. Every catch block must log, rethrow, or return a meaningful error. No empty catch blocks.
- **No Fallbacks**: Do not use fallback values to mask misconfiguration or missing data. If something is required, fail loudly when it is absent.
- **Colocation**: Keep related code together. Place tests, styles, and utilities next to the code they relate to, not in distant directories.
- **Dependency Inversion**: Depend on abstractions, not concretions. High-level modules should not import from low-level implementation details directly.
- **Explicit over Implicit**: Make behaviour visible and traceable. Avoid magic strings, hidden conventions, or implicit side effects. Name things clearly.
<!-- /blint:conventions -->

<!-- blint:context v1 -->
## Context

- Commit after each block of work. We want to see the history of how it was developed.
<!-- /blint:context -->

<!-- blint:patterns v2 -->
## Patterns

### A General-Purpose Async Loading Component for React Query
One way to centralise loading, error, and retry UI for React Query without leaking query state into every component.
*Applies to:* React components that render async data, pages or views with loading/error states, and any component that calls useQuery or useMutation
*Files matching:* `src/renderer/**/*.tsx`
*Reference:* `.blint/patterns/a-general-purpose-async-loading-component-for-react-query.md`

### Electron App Architecture
Architectural conventions for building an Electron app with Vite, React, Tailwind, shadcn/ui, and typed IPC
*Applies to:* Electron main process entry, preload scripts, Vite configs for main/preload/renderer, IPC handler registrations, window creation helpers, React app root, and build configuration
*Files matching:* `electron/**/*`, `src/main/**/*`, `src/renderer/**/*`, `src/shared/**/*`, `vite.*.config.mjs`, `forge.config.ts`
*Reference:* `.blint/patterns/electron-app-architecture.md`

### Electron Release Pipeline
GitHub Actions CI/CD for building, signing, distributing, and auto-updating an Electron app via S3/CloudFront
*Applies to:* GitHub Actions workflow files for releasing the Electron app, Electron Forge config, UpdateService, update IPC handlers, update provider components, Squirrel lifecycle handling, and entitlements plists
*Files matching:* `.github/workflows/*`, `forge.config.ts`, `**/*.plist`
*Reference:* `.blint/patterns/electron-release-pipeline.md`
<!-- /blint:patterns -->

<!-- blint:about v1 -->
## About Blint

This project is managed by Blint, a codebase governance tool. When working in this repo:

- **Patterns** in `.blint/patterns/` are reusable design rules with file-matching criteria. If you edit a file that matches a pattern, your changes must comply with it.
- **Documentation** in `docs/` describes design intent for specific parts of the codebase. Read the relevant docs before making non-trivial changes.
- **Specs** in `specs/` are scoped work items. If one is active, follow the `/start-spec` workflow.

Before editing a file, scan the Patterns and Documentation sections below for anything relevant. Use both the worded "Applies to" description and the file globs — the words catch conceptual matches the globs miss.
<!-- /blint:about -->

<!-- blint:authoring v2 -->
## Authoring Blint Files

Patterns, documentation, and specs are all markdown files with YAML frontmatter. **This section is the source of truth for those frontmatter fields.** When you create or edit any of these files (whether directly or via `/generate-pattern`, `/generate-documentation`, `/generate-spec`), populate every applicable field listed here. Missing fields silently degrade governance — Blint cannot match files, surface relevant context, or track lifecycle if they are absent.

When updating an existing file, never delete or reorder frontmatter you didn't intentionally change.

### Patterns — `.blint/patterns/<slug>.md`

A pattern captures a reusable rule and the files it applies to.

```yaml
---
name: <Human-readable title>
description: <One-line summary>
version: 1
categories:
  - <group:name from .blint/project.json activeCategories>
match: <Natural-language description of which files this pattern applies to>
matchCriteria:
  globs:
    - "<glob>"
  contentMatch:                   # optional
    - "<string in file body>"
visibility: public                # optional; "public" (default) or "private"
---
```

| Field | Required | When to set |
| --- | --- | --- |
| `name` | yes | On create. |
| `description` | yes | On create. Surfaced in pattern lists and CLAUDE.md. |
| `version` | yes | Start at `1`. **Bump by 1 on every body change.** |
| `categories` | recommended | On create. One or more entries from `activeCategories` in `.blint/project.json`. |
| `match` | **yes** | On create. **Always fill this in.** This natural-language description is what lets Blint judge relevance for files the globs miss. The body of the pattern is rules; `match` is scope. |
| `matchCriteria.globs` | recommended | On create. Globs that capture the same scope as `match`. `/update-coverage` can recompute these later, but author them up front when the scope is obvious. |
| `matchCriteria.contentMatch` | optional | Only when location-agnostic — strings whose presence in a file means the pattern applies (e.g. `"<Dialog"`). Use globs OR contentMatch, rarely both. |
| `visibility` | optional | On publish to the registry. |
| `registryId`, `registryVersion` | system | Populated by registry sync. **Do not set by hand.** |

### Documentation — `docs/**/*.md`

A doc captures design intent for a slice of the codebase.

```yaml
---
name: <Title>
description: <One-line summary>
version: 1
match: <Natural-language description of which files this doc covers>
matchCriteria:
  globs:
    - "<glob>"
---
```

| Field | Required | When to set |
| --- | --- | --- |
| `name` | yes | On create. |
| `description` | yes | On create. One-line summary used in the Documentation index. |
| `version` | yes | Start at `1`. **Bump by 1 on every body change.** |
| `match` | **yes** | On create. **Always fill this in.** Same role as for patterns. |
| `matchCriteria.globs` | recommended | On create. Author up front when the scope is obvious; `/update-coverage` can recompute later. |

Docs do **not** use `contentMatch`.

### Specs — `specs/<slug>.md`

Spec frontmatter has two layers. The author sets the **authoring fields**; Blint and the lifecycle commands manage the **lifecycle fields**.

```yaml
---
name: <Spec title>
type: feature                     # or "refinement"
priority: 1                       # optional; 1 = high, omit/0 = normal
# --- everything below is set by Blint, do not author by hand ---
environment: worktree             # original | worktree | copy
environmentPath: ../proj-add-auth
environmentBranch: spec/add-auth
commencedAt: 2026-04-30T10:30:00.000Z
reviewedAt: 2026-04-30T11:15:00.000Z
implementedAt: 2026-04-30T12:00:00.000Z
mergedAt: 2026-04-30T13:00:00.000Z
sessionId: <agent-sdk-session-id>
---
```

**Authoring fields** — set when a spec is created or refined:

| Field | Required | When to set |
| --- | --- | --- |
| `name` | yes | On create. |
| `type` | yes | On create. `feature` for new work, `refinement` for smaller changes. |
| `priority` | optional | Only when raising priority above normal. |

**Lifecycle fields** — populated automatically as the spec progresses. **Never invent a value here.** If the action the field represents has not happened, the field stays absent.

| Field | Set by | When |
| --- | --- | --- |
| `environment` | Blint UI / `/start-spec` | When the spec becomes active. One of `original`, `worktree`, `copy`. |
| `environmentPath` | Blint UI / `/start-spec` | Worktree or copy directory. Absent for `original`. |
| `environmentBranch` | Blint UI / `/start-spec` | Git branch name. Absent for `original`. |
| `commencedAt` | `/start-spec` | First action of the spec session — the only timestamp `/start-spec` ever sets. |
| `reviewedAt` | `/check-patterns` | When the implementation has been reviewed against patterns and documentation. |
| `implementedAt` | `/complete-spec` | When implementation is signed off. For `worktree`/`copy`, this means "ready to merge"; for `original`, this means complete. |
| `mergedAt` | Blint auto-detect | When the branch lands on main. Never set this manually. |
| `sessionId` | Blint | Persisted Agent SDK session id. Never set this manually. |

**Rules of thumb**

- The lifecycle fields above are owned by their respective commands. If you are not running the named command, do not touch the field.
- Do not bump a spec's frontmatter when refining the body — specs do not have a `version` field.
- Patterns and docs **do** have a `version` — bump it on every content change.
<!-- /blint:authoring -->

<!-- blint:docs v1 -->
<!-- /blint:docs -->
