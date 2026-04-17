---
name: Gemini Batch Image Generation Desktop App
type: feature
commencedAt: 2026-04-17T00:00:00.000Z
sessionId: e4ccce1e-9fb7-474c-bba6-65d689b854e6
environment: original
---
This project should provide a standalone Electron app to help someone brainstorm an idea using services like Gemini. The initial focus should be entirely the Gemini image generation.

When using the Gemini web interface, it can be very slow to produce multiple images for a given prompt. However, Gemini it can be very beneficial to see multiple different approaches to a given prompt. For the first version of this app I want to be able to do the following:

- provide a prompt with optional images attached
- set the model I want to use (typically Nano Banana Pro, i.e. Genmini 3 pro)
- set the image quality/size - typically smaller during the early phases as we can ask Gemini to upscale later 
- set the number of ideas/images I want generated
- see the results appear one by one
- allow a given image to be saved to disk. For a given image group, we should provide a save all

We can later focus on ideas like allowing a given image to be refined, upscaled, etc.

The app should use a layout similar to web Gemini experience, with:
- sidebar listing conversations
- main panel with the conversation

It should provide a settings panel where a Gemini API key can be set. The @.blint/patterns/electron-app-architecture should provide guidance on the general structure of the app.
