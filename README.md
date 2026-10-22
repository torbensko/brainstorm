# Brainstorm

A native macOS studio for exploring several image designs at once. Built with SwiftUI and Swift 6. Your ChatGPT subscription is the default connection. OpenAI API and Google Gemini API access are also available as explicit alternatives.

## Use it

Download the signed, notarised Apple Silicon app from the [latest release](https://github.com/torbensko/brainstorm/releases/latest), open the DMG, and drag Brainstorm into Applications. Requires macOS 14 or later. The native release is **2.1.0 (build 4)**; Settings shows its version, source revision, and build date, and the app menu includes **About Brainstorm**.

Sparkle checks for updates automatically and downloads them to install when you quit. Use **Brainstorm → Check for Updates…** to check and install immediately, or change automatic update preferences in Settings. Install version 2.1 manually once if you are upgrading from 2.0 or the old Electron app; subsequent releases update the installed copy in place.

To build from source, use Xcode 26 or later and the selected Xcode command-line tools:

```sh
make run
```

This creates `dist/Brainstorm.app` and opens it. Open Settings (⌘,) to connect ChatGPT. Brainstorm uses the locally installed ChatGPT/Codex runtime and its existing ChatGPT sign-in, following the same app-server integration as Blint. If you are already signed in, the connection is automatic. Otherwise choose **Sign in with ChatGPT** and finish in your browser. No API key is needed.

Subscription mode uses your ChatGPT plan allowance and any applicable ChatGPT credits, never OpenAI API credits. Account limits still apply. Brainstorm removes API-key environment variables and verifies ChatGPT authentication before every request; it never falls back to API billing. OpenAI API and Gemini are separate, optional selections with separately billed API keys stored in macOS Keychain.

Install the ChatGPT desktop app or Codex CLI first. For a custom installation, set `BRAINSTORM_CODEX_BINARY` to its executable path.

- **Explore:** write a brief, choose a service, shape, and image count. API services additionally expose model and quality choices. Subscription mode uses Codex’s built-in image generation; shape is supplied as a design instruction, while the runtime manages the image model and quality. Images appear independently as they finish.
- **Attach:** choose images, drop files into the window, or paste an image with ⇧⌘V. Files are copied into the library. Formats readable by macOS ImageIO are normalized to PNG; animated formats use the first frame. Imports are limited to 30 MB and 64 megapixels, and normalized references must be under 14 MB.
- **Refine:** select an image’s Refine action, describe a change, and generate a new set. The selected image is the first reference. Originals remain available.
- **Refine wording:** edit the prompt yourself or request a rewrite, then create a fresh concept with copies of its references. No image requests are made until you choose Explore.
- **Export:** save an individual image or an entire set. Full-resolution viewing, copying, and revision navigation are available from the image viewer.

Each set contains 1–16 separate image jobs. Settings controls concurrency (default 3). Failed slots can be retried without repeating successful images. Quitting during generation leaves unfinished slots available for manual retry on the next launch. A cancelled request may already have been processed or billed by its provider.

## Development

```sh
make build     # compile
make test      # offline provider, storage, and recovery tests
make demo      # separate demo library, local artwork, no API calls
make app       # release app bundle and ZIP
```

Open `Package.swift` in Xcode to work on the app. Sparkle is pinned through Swift Package Manager; SQLite is supplied by macOS. The build script embeds Sparkle and signs its helpers before signing Brainstorm. It uses the host architecture. Set `CONFIGURATION=debug` for a debug bundle.

Builds are ad-hoc signed for local use without hardened runtime library validation, which requires a Team ID. For distribution, provide `CODE_SIGN_IDENTITY` with an installed Developer ID identity to enable hardened runtime, and optionally `NOTARY_PROFILE` with an existing notarytool Keychain profile:

```sh
CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-notary-profile' ./scripts/build-app.sh
```

The script fails if requested signing or notarization fails. Branch CI runs tests and uploads a local-use ZIP. Version tags run the release workflow with the repository's existing distribution certificate and notarisation credentials, publishing a signed, notarised DMG and ZIP plus checksums only after verification. The tag must match the app version, and release notes live in `releases/`.

Every release also publishes `appcast.xml`; installed apps use the stable GitHub `releases/latest/download/appcast.xml` URL. Sparkle generates and signs the feed, embedded release notes, and update archive using the repository's `SPARKLE_PRIVATE_KEY` secret. The public key is in the bundle plist; the private key is backed up in the maintainer's login Keychain under account `app.brainstorm.native`. It must be retained across releases. Increment both the marketing version and the numeric build number for each release; Sparkle compares build numbers. Feed generation and validation must succeed before publication.

## Local data

The native library lives at `~/Library/Application Support/Brainstorm Native/`. It contains `library.sqlite` and an `Images/` folder. Back up the entire folder while the app is closed. Demo mode uses `Brainstorm Native Demo/` instead. API credentials remain in Keychain. ChatGPT authentication remains managed by Codex; Brainstorm does not copy or read OAuth tokens. Temporary reference copies in `Requests/` are removed after each turn.

This is the native replacement for the earlier Electron app. The old implementation is available in Git history; its saved data is left untouched. Automatic import of the old conversation store is not included. Existing exported images can be attached to new concepts.

See [architecture](docs/native-architecture.md) for the data model and extension points. Provider request formats were checked against the [OpenAI image guide](https://developers.openai.com/api/docs/guides/image-generation), [image edits reference](https://developers.openai.com/api/reference/resources/images/methods/edit), and [Gemini image guide](https://ai.google.dev/gemini-api/docs/generate-content/image-generation). Offline tests verify payloads, subscription authentication boundaries, concurrent turns, cancellation, lifecycle behavior, and recovery. Live subscription generation, reference-image editing, and prompt rewriting were also tested against the installed Codex runtime. API service availability depends on your API account.

The opt-in `liveSubscriptionImageEditAndPromptRefinement` test uses subscription allowance. Enable it with `BRAINSTORM_LIVE_SUBSCRIPTION_TEST=1` and set `BRAINSTORM_LIVE_REFERENCE` to an image file; normal tests and CI never generate paid or subscription images.

## License

ISC
