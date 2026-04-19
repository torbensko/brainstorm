---
name: Auto-title the conversations
type: feature
commencedAt: 2026-04-17T00:00:00.000Z
implementedAt: 2026-04-18T00:00:00.000Z
sessionId: 5d475509-76e4-4ab7-8091-bf498ac5e88c
environment: original
---
After submitting the first message in a conversation, can we ask gemini (using the same key we already have) to provide a simple title. Adjusting the flow to something more like the gemini web UI will make this easier:

- clicking new opens a conversation prompt without yet creating a new conversation. This can be a dialog
- user enters the prompt and any related images (should use the same input as the conversation input)
- clicking begin creates the conversation and then renames it once we hear back from gemini - this should be separate request so we don't need to wait for the images to return.

If easy enough, rather than a dialog, we could have the main panel show the prompt entry in the middle, before transitioning to the bottom of the screen.
