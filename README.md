# Brainstorm

A native macOS studio for exploring several image designs at once. Built with SwiftUI and Swift 6. OpenAI is the default provider; Google Gemini is also supported.

## Use it

Requires macOS 14 or later. Build with Xcode 16 or later and the selected Xcode command-line tools:

```sh
make run
```

This creates `dist/Brainstorm.app` and opens it. Open Settings (⌘,) and save an OpenAI or Gemini API key. Keys stay in macOS Keychain. API image generation uses separate API billing, not your ChatGPT subscription.

- **Explore:** write a brief, choose a model, shape, quality, and image count. Images appear independently as they finish.
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

Open `Package.swift` in Xcode to work on the app. No external Swift package dependencies are required; SQLite is supplied by macOS. The build script uses the host architecture. Set `CONFIGURATION=debug` for a debug bundle.

Builds are ad-hoc signed for local use. For distribution, provide `CODE_SIGN_IDENTITY` with an installed Developer ID identity and optionally `NOTARY_PROFILE` with an existing notarytool Keychain profile:

```sh
CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-notary-profile' ./scripts/build-app.sh
```

The script fails if requested signing or notarization fails. CI runs tests and uploads a local-use ZIP; it does not publish releases.

## Local data

The native library lives at `~/Library/Application Support/Brainstorm Native/`. It contains `library.sqlite` and an `Images/` folder. Back up the entire folder while the app is closed. Demo mode uses `Brainstorm Native Demo/` instead. Credentials remain in Keychain.

This is the native replacement for the earlier Electron app. The old implementation is available in Git history; its saved data is left untouched. Automatic import of the old conversation store is not included. Existing exported images can be attached to new concepts.

See [architecture](docs/native-architecture.md) for the data model and extension points. Provider request formats were checked against the [OpenAI image guide](https://developers.openai.com/api/docs/guides/image-generation), [image edits reference](https://developers.openai.com/api/reference/resources/images/methods/edit), and [Gemini image guide](https://ai.google.dev/gemini-api/docs/generate-content/image-generation). Offline tests verify payloads and lifecycle behavior; live provider access and model availability depend on your API account.

## License

ISC
