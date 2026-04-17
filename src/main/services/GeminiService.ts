import { GoogleGenAI } from "@google/genai";
import { BrowserWindow } from "electron";
import { randomUUID } from "crypto";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type {
  GenerateRequest,
  GeneratedImage,
  ImageResultEvent,
  GenerationErrorEvent,
  GenerationCompleteEvent,
  Message,
} from "@/shared/types";
import { GeminiModel } from "@/shared/types";
import { getSettings } from "./SettingsService";
import { addMessage, updateMessage } from "./ConversationService";

const activeGenerations = new Map<string, AbortController>();

export async function generateImages(
  request: GenerateRequest,
  window: BrowserWindow
): Promise<string> {
  const settings = await getSettings();
  if (!settings.geminiApiKey) {
    throw new Error("Gemini API key not configured. Please set it in Settings.");
  }

  const ai = new GoogleGenAI({ apiKey: settings.geminiApiKey });
  const messageId = randomUUID();
  const abortController = new AbortController();
  const generationKey = `${request.conversationId}:${messageId}`;
  activeGenerations.set(generationKey, abortController);

  // Create the user message
  const userMessage: Message = {
    id: randomUUID(),
    role: "user",
    prompt: request.prompt,
    attachedImages: request.attachedImages,
    images: [],
    model: request.model,
    imageSize: request.imageSize,
    requestedCount: request.count,
    timestamp: new Date().toISOString(),
    errors: [],
    complete: true,
  };
  await addMessage(request.conversationId, userMessage);

  // Create the assistant message placeholder
  const assistantMessage: Message = {
    id: messageId,
    role: "assistant",
    prompt: "",
    attachedImages: [],
    images: [],
    model: request.model,
    imageSize: request.imageSize,
    requestedCount: request.count,
    timestamp: new Date().toISOString(),
    errors: [],
    complete: false,
  };
  await addMessage(request.conversationId, assistantMessage);

  // Fire N parallel requests
  const promises = Array.from({ length: request.count }, (_, index) =>
    generateSingleImage(ai, request, messageId, index, window, abortController)
  );

  // Wait for all to settle, then mark complete
  Promise.allSettled(promises).then(async () => {
    activeGenerations.delete(generationKey);
    await updateMessage(request.conversationId, messageId, (msg) => ({
      ...msg,
      complete: true,
    }));
    const completeEvent: GenerationCompleteEvent = {
      conversationId: request.conversationId,
      messageId,
    };
    if (!window.isDestroyed()) {
      window.webContents.send(
        IPC_CHANNELS.GEMINI_GENERATION_COMPLETE,
        completeEvent
      );
    }
  });

  return messageId;
}

async function generateSingleImage(
  ai: GoogleGenAI,
  request: GenerateRequest,
  messageId: string,
  index: number,
  window: BrowserWindow,
  abortController: AbortController
): Promise<void> {
  if (abortController.signal.aborted) return;

  try {
    const contents: Array<
      | { text: string }
      | { inlineData: { data: string; mimeType: string } }
    > = [];

    // Add attached images
    for (const img of request.attachedImages) {
      contents.push({
        inlineData: { data: img.data, mimeType: img.mimeType },
      });
    }

    // Add prompt text
    const sizeInstruction = `Generate the image at ${request.imageSize} resolution.`;
    contents.push({
      text: `${request.prompt}\n\n${sizeInstruction}\n\nVariation ${index + 1} of ${request.count}: Please create a unique interpretation.`,
    });

    const response = await ai.models.generateContent({
      model: request.model,
      contents: [{ role: "user", parts: contents }],
      config:
        request.model === GeminiModel.GEMINI_2_FLASH
          ? {
              responseModalities: ["TEXT", "IMAGE"],
            }
          : undefined,
    });

    if (abortController.signal.aborted) return;

    // Extract image from response
    const candidates = response.candidates;
    if (!candidates?.length) {
      throw new Error("No response from Gemini");
    }

    const parts = candidates[0].content?.parts;
    if (!parts) {
      throw new Error("No content in Gemini response");
    }

    let imageData: string | null = null;
    let mimeType = "image/png";

    for (const part of parts) {
      if (part.inlineData) {
        imageData = part.inlineData.data!;
        mimeType = part.inlineData.mimeType ?? "image/png";
        break;
      }
    }

    if (!imageData) {
      throw new Error("No image in Gemini response");
    }

    const generatedImage: GeneratedImage = {
      id: randomUUID(),
      data: imageData,
      mimeType,
      index,
    };

    // Persist image to message
    await updateMessage(request.conversationId, messageId, (msg) => ({
      ...msg,
      images: [...msg.images, generatedImage],
    }));

    // Notify renderer
    const event: ImageResultEvent = {
      conversationId: request.conversationId,
      messageId,
      image: generatedImage,
    };
    if (!window.isDestroyed()) {
      window.webContents.send(IPC_CHANNELS.GEMINI_IMAGE_RESULT, event);
    }
  } catch (err) {
    if (abortController.signal.aborted) return;
    const errorMessage = err instanceof Error ? err.message : String(err);

    await updateMessage(request.conversationId, messageId, (msg) => ({
      ...msg,
      errors: [...msg.errors, `Image ${index + 1}: ${errorMessage}`],
    }));

    const errorEvent: GenerationErrorEvent = {
      conversationId: request.conversationId,
      messageId,
      index,
      error: errorMessage,
    };
    if (!window.isDestroyed()) {
      window.webContents.send(
        IPC_CHANNELS.GEMINI_GENERATION_ERROR,
        errorEvent
      );
    }
  }
}

export function cancelGeneration(
  conversationId: string,
  messageId: string
): void {
  const key = `${conversationId}:${messageId}`;
  const controller = activeGenerations.get(key);
  if (controller) {
    controller.abort();
    activeGenerations.delete(key);
  }
}
