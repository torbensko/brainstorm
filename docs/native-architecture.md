---
name: Native Brainstorm architecture
description: Concepts, image revisions, provider boundaries, and durable local generation.
version: 1
match: Native macOS app state, storage, image generation, provider adapters, packaging, and tests.
matchCriteria:
  globs:
    - "Sources/**/*.swift"
    - "Tests/**/*.swift"
    - "Package.swift"
    - "scripts/build-app.sh"
---

# Native Brainstorm

A concept owns a draft and a sequence of generation sets. Each set captures its exact prompt, resolved edit instructions, provider settings, ordered image references, and independent jobs. A selected image is an explicit parent, not an implicit position in chat history. Earlier sets remain immutable. Reusing a brief creates new jobs; retrying a failed slot preserves the original request settings.

The SwiftUI app owns navigation and editable drafts. BrainstormCore owns persistence, files, credentials, provider calls, and generation scheduling. The app observes queue events and reloads metadata; previews load separately. Provider calls never depend on an active view or selected concept.

SQLite stores normalized metadata and explicit foreign keys. Image bytes are ordinary files, with smaller previews for the grid. Imports copy images into the library, orient and normalize them to PNG, and strip incidental metadata. References are ordered: the selected image comes first, supplementary attachments follow. A library lock prevents two app processes from recovering or scheduling the same work simultaneously.

The queue claims jobs before dispatch, bounds concurrent calls, and persists each success independently. Only short rate limits receive bounded automatic retries; ambiguous network/server failures and quota exhaustion stay visible for manual retry. Cancellation reaches URLSession and late results are discarded. After a restart, incomplete jobs become interrupted; they never silently regenerate. Draft saves are debounced during editing and flushed on normal quit.

OpenAI is the default. Its Images API handles both generation and explicit-reference editing; its Responses API handles prompt rewriting without image generation. Gemini implements the same protocol with standalone user turns containing the selected image and accumulated design instructions. No synthetic model history or thought-signature reconstruction is needed. Each provider owns request/response types and setting translation. Adding another provider means extending the typed catalog, credential identity, and registry implementation; UI and job scheduling remain shared.

Model IDs live in the provider catalog. Validate additions against official documentation and add response/request fixtures. Historical batches preserve their original settings. Unknown/retired models should produce an actionable error rather than quietly changing the requested model. API keys are stored only in Keychain, never in library rows or preference files.

The demo flag replaces providers and credentials with local implementations and uses a separate library. It exercises the real persistence, queue, refinement, and attachment paths without network calls. Sample artwork is deliberately labeled. CI runs offline contract and recovery tests and builds an ad-hoc signed bundle. Distribution signing and notarization are explicit build options.

The old Electron code remains recoverable in Git history. Its data folder is separate from the native library and is never rewritten. The earlier specs and Blint Electron patterns describe the historical implementation.
