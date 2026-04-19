<!-- blint:documentation -->
## Writing Documentation

Documentation in this project is consumed by AI coding agents as much as by humans. Its job is to preserve *design intent* so future work stays faithful to the original idea behind a feature — not to serve as a comprehensive technical specification.

- **Start with a YAML frontmatter block.** Every doc opens with a `name`, `version`, and `description` so Blint and downstream tools can index it. The `description` should be a one-line summary of what the doc covers. Leave `match` / `matchCriteria` out — Blint adds those. Example:

  ```yaml
  ---
  name: AI Target Generation
  version: 1
  description: >-
    How the system generates personalised weight and rep targets during active workouts
  ---
  ```

- **Focus on concepts and design.** Describe the shape of the system — entities, lifecycles (e.g. how an object flows from frontend to backend), data flow, decision points. Enough for an agent to build new parts in the same spirit.
- **Implementation details only where they are load-bearing for the design.** A doc explaining how theming is applied across the app *should* be implementation-specific — applying the convention is the point. A doc on "how auth works" should not enumerate every function.
- **No inventories, no code dumps.** Don't list every file, function, or endpoint — those rot immediately. Describe the pattern so someone can find and follow it.
- **Conventions over instructions.** Say what the convention is and why, not step-by-step how-tos.
- **No hardcoded values** (thresholds, frequencies, counts) unless they are genuine invariants. These drift out of sync with code.
- **Concise.** Every sentence should earn its place.
<!-- /blint:documentation -->

<!-- blint:conventions -->
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

<!-- blint:context -->
## Context

- Commit after each block of work. We want to see the history of how it was developed.
<!-- /blint:context -->

<!-- blint:patterns -->
## Patterns

- When working on files matching `src/renderer/**/*.tsx`, read `.blint/patterns/a-general-purpose-async-loading-component-for-react-query.md`
- When working on files matching `electron/**/*`, `src/main/**/*`, `src/renderer/**/*`, `src/shared/**/*`, `vite.*.config.mjs`, `forge.config.ts`, read `.blint/patterns/electron-app-architecture.md`
- When working on files matching `.github/workflows/*`, `forge.config.ts`, `**/*.plist`, read `.blint/patterns/electron-release-pipeline.md`
<!-- /blint:patterns -->
