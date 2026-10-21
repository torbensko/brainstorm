---
name: Native Brainstorm architecture
description: Concepts, image revisions, provider boundaries, and durable local generation.
version: 9
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

The interface presents concepts as conversations. A native sidebar list provides navigation within a standard macOS split window. The system window title and toolbar occupy the detail column while the sidebar extends behind its window controls for the full window height. A compose icon sits beside the sidebar toggle and remains available when the sidebar closes. A small AppKit placement adapter moves that toolbar item ahead of the native tracking separator; AppKit retains ownership of the toolbar and sidebar transitions. Toolbar search filters conversations and reveals the sidebar when needed, with Settings beside it. Account status remains at the bottom of the sidebar. Creating a conversation clears the search filter and focuses its composer.

The detail column keeps its primary scroll view at the root, with the composer in a bottom safe-area inset, so content scrolls beneath the system toolbar. A hard scroll-edge effect keeps the title legible over images. Do not force a window-wide toolbar background or replace native sidebar transitions with custom chrome. The composer stays at the bottom for both new and existing conversations, with a centered logo and opening prompt in the empty state. Sent messages show their text and reference images above each set of generated results. An accepted send clears the composer and saves the empty draft; a rejected send preserves the draft and attachments. Native button-style menus give model, shape, quality, and image count a consistent treatment and wrap when space is limited. Supported systems use Liquid Glass for toolbar controls and primary actions; earlier systems use bordered controls. Subscription mode omits quality because Codex manages it.

File selection, image drops, and image paste share the same reference import path. The workspace accepts file URLs and image data; the native prompt editor intercepts attachments before AppKit can insert a file path into the text. The editor measures proposed sizes separately from its live text layout so wrapping always follows the actual composer width. A drag item with both representations attaches only once. Imports preserve order, lock conversation navigation until complete, and surface unreadable images as errors. Local editing and attachments become available when the library opens, independently of the provider connection check.

SQLite stores normalized metadata and explicit foreign keys. Image bytes are ordinary files, with smaller previews for the grid. Imports copy images into the library, orient and normalize them to PNG, and strip incidental metadata. References are ordered: the selected image comes first, supplementary attachments follow. A library lock prevents two app processes from recovering or scheduling the same work simultaneously.

The queue claims jobs before dispatch, bounds concurrent calls, and persists each success independently. Only short rate limits receive bounded automatic retries; ambiguous network/server failures and quota exhaustion stay visible for manual retry. Cancellation reaches URLSession and late results are discarded. After a restart, incomplete jobs become interrupted; they never silently regenerate. Draft saves are debounced during editing and flushed on normal quit. Automatic conversation titles follow the draft until the first message is sent, then remain anchored to that message. Explicitly renamed titles are persisted separately from automatic titles and are never replaced by draft saves.

ChatGPT subscription access is the default, through the locally installed Codex app-server and its native OpenAI provider. This is the same integration used by Blint, not the separate token-sharing Responses API route. Codex owns authentication and token renewal. Brainstorm strips API-key environment variables and checks `account/read` for ChatGPT authentication before each turn. Subscription and API credentials are separate enum cases; no fallback can convert a subscription request into an API request.

Each image job gets an independent ephemeral Codex thread and a private folder of ordered reference copies. Typed notifications capture image bytes and turn completion. Cancellation interrupts the corresponding turn, connection failures fail pending jobs, and timeouts never retry automatically. Temporary request copies are removed after completion. Shape is a prompt instruction; Codex manages its own image model and quality. Prompt refinement uses a separate text-only turn.

OpenAI API remains an explicit alternative. Its Images API handles both generation and explicit-reference editing; its Responses API handles prompt rewriting without image generation. Gemini implements the same protocol with standalone user turns containing the selected image and accumulated design instructions. No synthetic model history or thought-signature reconstruction is needed. Each provider owns request/response types and setting translation. Adding another provider means extending the typed catalog, credential identity, and registry implementation; UI and job scheduling remain shared.

Model IDs live in the provider catalog. Validate additions against official documentation and add response/request fixtures. Historical batches preserve their original settings. Unknown/retired models should produce an actionable error rather than quietly changing the requested model. API keys are stored only in Keychain, never in library rows or preference files. Existing API batches preserve their billing route; switching the composer to ChatGPT creates new subscription batches rather than rewriting history.

The demo flag replaces providers and credentials with local implementations and uses a separate library. It exercises the real persistence, queue, refinement, and attachment paths without network calls. Sample artwork is deliberately labeled. CI runs offline contract and recovery tests and builds an ad-hoc signed bundle. Packaging explicitly links and verifies the active SDK version separately from the minimum supported macOS version: stamping the deployment target as the SDK opts the app out of modern AppKit appearance even when newer APIs compile successfully. Distribution signing and notarization are explicit build options.

The old Electron code remains recoverable in Git history. Its data folder is separate from the native library and is never rewritten. The earlier specs and Blint Electron patterns describe the historical implementation.
