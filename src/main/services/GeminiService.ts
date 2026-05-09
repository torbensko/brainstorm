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
  TitleGeneratedEvent,
  GeminiModelInfo,
  Message,
} from "@/shared/types";
import { NANO_BANANA_MODELS } from "@/shared/types";
import { getSettings } from "./SettingsService";
import {
  addMessage,
  updateMessage,
  updateConversationTitle,
  getConversation,
} from "./ConversationService";

const activeGenerations = new Map<string, AbortController>();

export function listImageModels(): GeminiModelInfo[] {
  return [...NANO_BANANA_MODELS];
}

export async function requestImages(
  request: GenerateRequest,
  window: BrowserWindow
): Promise<string> {
  const settings = await getSettings();
  if (!settings.geminiApiKey) {
    throw new Error(
      "Gemini API key not configured. Please set it in Settings."
    );
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
    aspectRatio: request.aspectRatio,
    imageResolution: request.imageResolution,
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
    aspectRatio: request.aspectRatio,
    imageResolution: request.imageResolution,
    requestedCount: request.count,
    timestamp: new Date().toISOString(),
    errors: [],
    complete: false,
  };
  await addMessage(request.conversationId, assistantMessage);

  // Fire N parallel generateContent requests
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

type ContentPart =
  | { text: string }
  | {
      inlineData: { data: string; mimeType: string };
      thoughtSignature?: string;
    };

interface Content {
  role: "user" | "model";
  parts: ContentPart[];
}

/**
 * Builds a multi-turn contents array from conversation history.
 *
 * Walks all messages *before* the current request's user+assistant pair
 * (which are the last two messages). User messages become user turns with
 * their prompt and attached images. Assistant messages become model turns,
 * but only include a generated image if the user explicitly selected it
 * as context (it would appear as an attachedImage on a subsequent user message).
 */
async function buildMultiTurnContents(
  conversationId: string,
  request: GenerateRequest,
  variationSuffix: string,
): Promise<Content[]> {
  const conversation = await getConversation(conversationId);
  if (!conversation) throw new Error("Conversation not found");

  const contents: Content[] = [];

  // The last two messages are the just-created user + assistant placeholders
  // for the current request — exclude them from history
  const priorMessages = conversation.messages.slice(0, -2);

  for (const msg of priorMessages) {
    if (msg.role === "user") {
      const parts: ContentPart[] = [];
      for (const img of msg.attachedImages) {
        parts.push({
          inlineData: { data: img.data, mimeType: img.mimeType },
        });
      }
      if (msg.prompt) {
        parts.push({ text: msg.prompt });
      }
      if (parts.length > 0) {
        contents.push({ role: "user", parts });
      }
    } else if (msg.role === "assistant" && msg.images.length > 0) {
      // Include the first generated image as the model's response so
      // Gemini knows what it produced. Only one image to control token usage.
      const firstImage = msg.images[0];
      contents.push({
        role: "model",
        parts: [
          {
            inlineData: {
              data: firstImage.data,
              mimeType: firstImage.mimeType,
            },
            ...(firstImage.thoughtSignature && {
              thoughtSignature: firstImage.thoughtSignature,
            }),
          },
        ],
      });
    }
  }

  // Current user turn
  const currentParts: ContentPart[] = [];
  for (const img of request.attachedImages) {
    currentParts.push({
      inlineData: { data: img.data, mimeType: img.mimeType },
    });
  }
  currentParts.push({ text: request.prompt + variationSuffix });
  contents.push({ role: "user", parts: currentParts });

  return contents;
}

/**
 * Generates a single image using the Nano Banana generateContent API.
 *
 * Per the Gemini docs, these models return images via part.inlineData
 * in the response candidates. The imageConfig controls aspect ratio
 * and resolution.
 *
 * Sends the full conversation history as multi-turn contents so Gemini
 * can maintain context across follow-up messages.
 */
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
    const variationSuffix =
      request.count > 1
        ? `\n\nVariation ${index + 1} of ${request.count}: Please create a unique interpretation.`
        : "";

    const contents = await buildMultiTurnContents(
      request.conversationId,
      request,
      variationSuffix,
    );

    const response = await ai.models.generateContent({
      model: request.model,
      contents,
      config: {
        responseModalities: ["TEXT", "IMAGE"],
        imageConfig: {
          aspectRatio: request.aspectRatio,
          imageSize: request.imageResolution,
        },
      },
    });

    if (abortController.signal.aborted) return;

    // Extract image from response parts
    const candidates = response.candidates;
    if (!candidates?.length) {
      throw new Error("No candidates in Gemini response");
    }

    const responseParts = candidates[0].content?.parts;
    if (!responseParts?.length) {
      throw new Error("No parts in Gemini response");
    }

    // Find the last non-thought image part (final rendered image)
    let imageData: string | null = null;
    let mimeType = "image/png";
    let thoughtSignature: string | undefined;

    for (const part of responseParts) {
      // Skip thought parts — they're interim images
      if ((part as { thought?: boolean }).thought) continue;

      if (part.inlineData?.data) {
        imageData = part.inlineData.data;
        mimeType = part.inlineData.mimeType ?? "image/png";
        thoughtSignature = (part as { thoughtSignature?: string })
          .thoughtSignature;
      }
    }

    if (!imageData) {
      const partKeys = responseParts.map((p) => Object.keys(p).join(","));
      throw new Error(
        `No image in response. Parts: [${partKeys.join(" | ")}]`
      );
    }

    const generatedImage: GeneratedImage = {
      id: randomUUID(),
      data: imageData,
      mimeType,
      index,
      ...(thoughtSignature && { thoughtSignature }),
    };

    // Persist and notify
    await updateMessage(request.conversationId, messageId, (msg) => ({
      ...msg,
      images: [...msg.images, generatedImage],
    }));

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

const TITLE_MODEL = "gemini-2.5-flash";

/**
 * Generates a short conversation title from the user's first prompt.
 * Runs as a fire-and-forget background task — updates the conversation
 * title in the store and pushes an event to the renderer when done.
 */
export async function generateConversationTitle(
  conversationId: string,
  prompt: string,
  window: BrowserWindow
): Promise<void> {
  const settings = await getSettings();
  if (!settings.geminiApiKey) return;

  const ai = new GoogleGenAI({ apiKey: settings.geminiApiKey });

  try {
    const response = await ai.models.generateContent({
      model: TITLE_MODEL,
      contents: [
        {
          text: `Generate a short title (3-6 words) for an image-generation conversation that starts with this prompt. Return ONLY the title, no quotes, no explanation.\n\nPrompt: ${prompt}`,
        },
      ],
    });

    const title = response.text?.trim();
    if (!title) return;

    await updateConversationTitle(conversationId, title);

    const event: TitleGeneratedEvent = { conversationId, title };
    if (!window.isDestroyed()) {
      window.webContents.send(IPC_CHANNELS.GEMINI_TITLE_GENERATED, event);
    }
  } catch (err) {
    // Title generation is best-effort — don't propagate errors
    console.error("Failed to generate conversation title:", err);
  }
}
