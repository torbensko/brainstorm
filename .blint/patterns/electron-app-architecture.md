---
name: Electron App Architecture
version: 1
description: >-
  Architectural conventions for building an Electron app with Vite, React,
  Tailwind, shadcn/ui, and typed IPC
match: >-
  Electron main process entry, preload scripts, Vite configs for
  main/preload/renderer, IPC handler registrations, window creation helpers,
  React app root, and build configuration
matchCriteria:
  globs:
    - "electron/**/*"
    - "src/main/**/*"
    - "src/renderer/**/*"
    - "src/shared/**/*"
    - "vite.*.config.mjs"
    - "forge.config.ts"
visibility: public
registryId: electron-app-architecture
registryVersion: 1
---
# Electron App Architecture

## Three-Build Vite Configuration

The app uses Electron Forge with the Vite plugin to produce three separate builds:

1. **Main process** — CommonJS output, SSR mode, sourcemaps enabled. Entry point lives in `electron/main.ts`.
2. **Preload script** — CommonJS output, minification disabled. Entry point at `electron/preload.ts`.
3. **Renderer** — Standard Vite React build (ESM). Entry point is `index.html` mounting a React root.

Each build has its own `vite.*.config.mjs` file. The main and preload configs target Node.js (CJS); the renderer targets the browser (ESM). All three share a TypeScript path alias (`@/*` → `src/*`).

In development, the renderer runs on a Vite dev server. The main process polls for the dev server's readiness before loading the URL. In production, the main process loads the built HTML from disk.

## Security: Context Isolation and Preload Bridge

The preload script exposes a minimal `window.electronAPI` object via `contextBridge.exposeInMainWorld`. This bridge provides:

- `invoke(channel, ...args)` — wraps `ipcRenderer.invoke`
- `on(channel, callback)` — wraps `ipcRenderer.on` with a cleanup function
- `getVersion()` — convenience for the app version

No raw Electron APIs are exposed to the renderer. Node integration is disabled, context isolation is enabled, and the sandbox is on. The renderer communicates with the main process exclusively through this bridge.

## IPC Communication

### Channel definition

All IPC channels are defined as constants in a single enum/object (`IPC_CHANNELS`). Channel names follow the pattern `"domain:action"` (e.g. `"pattern:list"`, `"session:start"`, `"git:status"`). This provides a single source of truth for all channel names used by both main and renderer.

### Handler registration

IPC handlers are organised into one file per domain under `src/main/ipc/` (e.g. `patterns.ts`, `specs.ts`, `session.ts`). Each file exports a `register*Ipc()` function that binds handlers via `ipcMain.handle()`. All registration functions are called sequentially in the main process entry point on app-ready.

### Service injection by window context

A helper (`requireServicesForEvent`) extracts the `BrowserWindow` ID from an IPC event and returns the service instances scoped to that window's project. This means each window can operate on a different project without cross-contamination.

### Renderer-side consumption

React hooks wrap IPC calls using React Query (`useQuery` / `useMutation`). Query keys are scoped per project path to prevent cache collisions across projects:

```
queryKey: [projectPath, "patterns"]
queryFn: () => window.electronAPI.invoke("pattern:list")
```

### Main → Renderer events

For push-style communication (e.g. file-change notifications), the main process sends events via the window's `webContents.send()`. The renderer subscribes via `window.electronAPI.on()` and invalidates relevant React Query caches.

## Window Management

A `WindowManager` service in the main process tracks all open windows by ID, associating each with a project path and optional context (spec ID, chat ID, etc.). It supports:

- **Multi-window, multi-project** — multiple windows can be open simultaneously, each on a different project.
- **Window reuse** — before opening a new window for a specific context (e.g. a spec), the manager checks if one already exists and focuses it.
- **State persistence** — window bounds are saved before quit and restored on next launch.
- **Dev/prod URL loading** — a shared `createAppWindow` helper handles both modes, accepting dimensions, route, and configuration.

Windows are frameless (`frame: false`) with a hidden title bar (`titleBarStyle: "hidden"`). The renderer provides a draggable region (`.app-draggable` CSS class) for window movement.

## Renderer Architecture

### Providers and root layout

The React root wraps the app in:

1. `QueryClientProvider` — React Query cache
2. `ThemeProvider` — light/dark mode via a CSS class on the document root
3. `ProjectProvider` — current project path and recent projects list
4. `ErrorBoundary` — global error fallback

A `ProjectGate` component prevents access to the main UI until a project is selected.

### View routing

Navigation uses a view-state enum rather than a URL router. The main `AppShell` layout provides a sidebar for switching between views and a header with project context. Views are rendered conditionally based on the current view state.

### State management

- **Server state** (patterns, specs, docs, coverage): React Query, with IPC as the data source.
- **Global UI state** (current project, theme): React Context.
- **Local UI state** (form inputs, modals, selections): component-level `useState`.

No additional state management library is used.

## Styling: Tailwind 4 + shadcn/ui

Tailwind 4 is integrated via the `@tailwindcss/vite` plugin in the renderer Vite config. Design tokens are defined using `@theme` in `index.css` with OKLch colour values. The token set includes semantic colours (`--background`, `--foreground`, `--primary`, `--secondary`, `--accent`, `--destructive`, `--muted`), a radius scale, and sidebar-specific variants.

Dark mode uses a `.dark` class on the root element, toggled by `ThemeContext`.

UI components come from shadcn/ui, built on Radix UI primitives and styled with Tailwind utility classes. Component variants use `class-variance-authority`. Class merging uses `clsx` + `tailwind-merge`. Icons use `lucide-react`.

## Type Sharing

Types shared between main and renderer live in a dedicated shared package (e.g. `packages/shared/`), imported via a workspace alias. This package contains domain models, input types for mutations, enums, and pure utility functions. IPC-specific types (channel names, message shapes) remain in the renderer's `types/` directory since the main process defines handlers imperatively.

## Main Process Services

Business logic lives in service classes under `src/main/services/`, one per concern. Services are instantiated lazily per project context — not at app startup. The IPC layer is thin: handlers extract the window context, call the appropriate service method, and return the result.

## Store

Local settings and persistent state use `electron-store`, wrapped in a simple async-initialised accessor. The store is lazily loaded (dynamic import) to avoid blocking app startup. It holds window state, recent projects, user preferences, and session mappings.
