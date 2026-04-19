---
name: GitHub actions
type: feature
commencedAt: 2026-04-19T00:00:00.000Z
sessionId: 70a3965e-14df-4b08-943a-1da658f2776b
environment: original
---
Set up GitHub actions so the app can be built on GitHub. See @.blint/patterns/electron-release-pipeline for the details. The action secrets will be added.

We can just keep this to the macos build with signing. There is no need currently for:

- Windows version
- automatic updating

We can release this as the first version. Before doing so:

- create a concise README. Stick to the usual documentation guidelines
- add the images to the README and add to the repo
- bump the version and tag to test the flow
