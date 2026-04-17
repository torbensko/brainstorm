---
name: Electron Release Pipeline
version: 1
description: >-
  GitHub Actions CI/CD for building, signing, distributing, and auto-updating an
  Electron app via S3/CloudFront
match: >-
  GitHub Actions workflow files for releasing the Electron app, Electron Forge
  config, UpdateService, update IPC handlers, update provider components,
  Squirrel lifecycle handling, and entitlements plists
visibility: public
registryId: electron-release-pipeline
registryVersion: 2
---
# Electron Release Pipeline

End-to-end pattern for building, signing, distributing, and auto-updating an Electron app using GitHub Actions, S3, and CloudFront.

## Version Gating

- The app's `package.json` version is the **single source of truth** for releases. The workflow must extract the version from this file — never from tags, branches, or environment variables.
- Use a **two-workflow architecture** to avoid wasting CI minutes on non-version changes to `package.json` (e.g. dependency updates):
  1. **Tag workflow** (lightweight) — triggers on pushes to `main` that modify the app's `package.json`. Reads the version and creates a `v*` git tag only if it doesn't already exist. This job runs in seconds and costs virtually nothing.
  2. **Build & Release workflow** — triggers on `v*` tag pushes (plus manual dispatch for re-runs). Performs the full build, sign, deploy pipeline. Because it only triggers on tags, it never runs unless the version actually changed.
- This separation ensures that dependency bumps, script changes, or other non-version edits to `package.json` do not trigger expensive macOS and Windows builds.

## Build Jobs

- macOS and Windows builds must run in **parallel** on their respective runner OS types (`macos-latest`, `windows-latest`). Never cross-compile.
- Each platform job should produce both an **installer** (DMG/EXE) for first-time users and a **ZIP** for the auto-updater. These serve different purposes and both are required.
- Windows builds must use Squirrel to produce `.nupkg` delta packages and a `RELEASES` index file alongside the installer and ZIP. These enable differential updates.

## macOS Code Signing & Notarization

- The CI must import a P12 certificate into a **temporary keychain** created for the build — never the system keychain. The keychain should be cleaned up after use.
- The certificate must be stored as a base64-encoded GitHub secret and decoded at build time.
- All binaries must be signed with **hardened runtime** enabled and an entitlements plist that grants JIT, unsigned executable memory, and dyld environment variables (required by Electron).
- After signing, the app must be notarized using `notarytool` with Apple ID credentials. The build should fail if notarization fails — never ship an unnotarized macOS app.

## S3 Distribution Structure

- Artifacts must be uploaded to **two locations** in S3:
  - **Versioned path** (`/releases/v{VERSION}/`) — immutable archive of every release. Never overwrite these.
  - **Latest path** (`/latest/`) — version-agnostic filenames that always point to the newest release. These get overwritten on each deploy.
- The versioned path is the source of truth for downloads. The latest path is a convenience for direct download links on the website.

## Update Manifests

- The deploy step must generate YAML manifest files that `electron-updater` consumes:
  - `latest-mac.yml` for macOS
  - `latest.yml` for Windows
- Each manifest must include: `version`, `files` array with `url`, `sha512` (base64-encoded), and `size`, plus top-level `path`, `sha512`, and `releaseDate`.
- The Windows manifest should additionally include an `installerUrl` pointing to the `.exe` for users who need a fresh install rather than an update.
- SHA512 hashes must be computed during the deploy step from the actual uploaded artifacts — never hardcoded or copied from a previous build.
- Manifests must be uploaded to the S3 bucket root (not inside `/releases/` or `/latest/`) so `electron-updater` can find them at the feed URL root.

## CloudFront Cache Invalidation

- After uploading to S3, the workflow must invalidate CloudFront caches for all paths that were modified: `/latest/*`, `/latest.yml`, `/latest-mac.yml`, and `/releases/*`.
- Without invalidation, users may receive stale manifests and never see the update. This step is not optional.

## UpdateService (Main Process)

- Configure `electron-updater` with a **generic provider** pointing to the CloudFront CDN URL. Do not use the GitHub provider — it couples releases to GitHub's availability and rate limits.
- The CDN URL must come from an environment variable, not be hardcoded. This allows testing against staging feeds.
- **Never auto-download updates.** Check for updates automatically, but require the user to opt in before downloading. Auto-install on quit is acceptable.
- The service must gate update checks behind `app.isPackaged` to prevent update prompts during development.
- Provide a **version override** mechanism (stored in `electron-store`) that allows testing the update flow in dev mode by spoofing an older version.

## Windows Squirrel Lifecycle

- The Electron main process must handle Squirrel lifecycle events (`--squirrel-install`, `--squirrel-updated`, `--squirrel-uninstall`, `--squirrel-obsolete`) **before any other app initialisation**.
- On install/update: create desktop and start menu shortcuts via `Update.exe --createShortcut`.
- On uninstall: remove shortcuts via `Update.exe --removeShortcut`.
- On any Squirrel event: quit the app immediately after handling. The app must not show a window during these lifecycle steps.
- The UpdateService should detect whether Squirrel's `Update.exe` exists and fall back to generic ZIP-based updates if it doesn't.

## IPC & Renderer Integration

- Expose update operations to the renderer via dedicated IPC channels: check, download, install, get version, get available update info, and check if updates are enabled.
- Use `ipcMain.handle` / `ipcRenderer.invoke` (promise-based) for request/response operations. Use `webContents.send` / `ipcRenderer.on` for push notifications (e.g., "update available").
- Wrap update state in a **React context provider** that listens for push events from main, exposes a hook (`useUpdate`), and manages UI state (checking, available, dialog visibility).
- The provider should query for already-available updates on mount — the main process may have detected an update before the renderer was ready.

## GitHub Release

- After successful builds, create a **GitHub Release** attached to the existing tag with all platform artifacts.
- The git tag already exists at this point (created by the tag workflow). The release workflow should not create or push tags — it only consumes them.
- The GitHub Release is secondary to the S3 distribution — it serves as an archive and changelog, not as the update feed.
- The release should be created in a separate job that depends on both platform builds succeeding.

## Secrets & Credentials

The pipeline requires the following secrets, stored as GitHub Actions secrets (or equivalent CI secret store):

### macOS Code Signing

- **P12 certificate** (e.g. `CERTIFICATE_P12`) — A Developer ID Application certificate exported as `.p12`, then base64-encoded for storage as a CI secret. To obtain: create a Certificate Signing Request in Keychain Access, submit it in the Apple Developer portal under Certificates > Developer ID Application, download the certificate, export it from Keychain Access as `.p12` with a password, then base64-encode the file.
- **Certificate password** (e.g. `CERTIFICATE_PASSWORD`) — The password set when exporting the `.p12` file.

At build time, the workflow must:
1. Decode the base64 secret back to a `.p12` file.
2. Create a temporary keychain with a random password.
3. Import the `.p12` into that keychain using `security import`.
4. Set the keychain's partition list to allow `codesign` access without UI prompts.
5. Detect the signing identity from the keychain (e.g. via `security find-identity`).
6. Pass the identity to the build tool (Electron Forge reads it from an environment variable like `CODESIGN_IDENTITY`).
7. Clean up the temporary keychain after the build.

### macOS Notarization

- **Apple ID** (e.g. `APPLE_ID`) — The Apple ID email associated with the developer account.
- **App-specific password** (e.g. `APPLE_ID_PASSWORD`) — Generated at appleid.apple.com under Sign-In and Security > App-Specific Passwords. This is required because the Apple ID likely has 2FA enabled.
- **Apple Team ID** (e.g. `APPLE_TEAM_ID`) — The 10-character team identifier from the Apple Developer portal membership page.

Notarization is performed after signing using `xcrun notarytool submit` with `--wait` to block until Apple's servers complete the scan. The build must fail if notarization is rejected.

### AWS (S3 Deployment)

- **AWS Access Key ID** (e.g. `AWS_ACCESS_KEY_ID`) — IAM credentials with `s3:PutObject`, `s3:GetObject`, and `s3:ListBucket` permissions on the releases bucket, plus `cloudfront:CreateInvalidation` on the distribution.
- **AWS Secret Access Key** (e.g. `AWS_SECRET_ACCESS_KEY`) — The corresponding secret key.

### General Rules

- Never log, echo, or expose secret values in workflow output. Use the CI platform's secret masking.
- Scope secrets to the jobs that need them — code signing secrets should only be accessible to build jobs, AWS secrets only to deploy jobs.
- Store the CloudFront distribution ID and S3 bucket name as workflow-level environment variables (not secrets) since they are not sensitive.
