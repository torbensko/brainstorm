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
  GeminiModelInfo,
  Message,
} from "@/shared/types";
import { getSettings } from "./SettingsService";
import { addMessage, updateMessage } from "./ConversationService";

const activeGenerations = new Map<string, AbortController>();

/** Cache of model info so we know which API to call */
let modelCache: GeminiModelInfo[] = [];

export async function listImageModels(): Promise<GeminiModelInfo[]> {
  const settings = await getSettings();
  if (!settings.geminiApiKey) {
    throw new Error(
      "Gemini API key not configured. Please set it in Settings."
    );
  }

  const ai = new GoogleGenAI({ apiKey: settings.geminiApiKey });
  const models: GeminiModelInfo[] = [];

  const pager = await ai.models.list({
    config: { pageSize: 100, queryBase: true },
  });
  for await (const model of pager) {
    const actions = model.supportedActions ?? [];
    const canGenerateImages = actions.includes("generateImages");
    const canGenerateContent = actions.includes("generateContent");

    // Only include models that can produce images
    if (!canGenerateImages && !canGenerateContent) continue;

    const id = (model.name ?? "").replace(/^models\//, "");
    models.push({
      id,
      displayName: model.displayName ?? id,
      description: model.description ?? "",
      supportedActions: actions,
    });
  }

  // Sort: dedicated image models first, then alphabetically
  models.sort((a, b) => {
    const aImg = a.supportedActions.includes("generateImages") ? 0 : 1;
    const bImg = b.supportedActions.includes("generateImages") ? 0 : 1;
    if (aImg !== bImg) return aImg - bImg;
    return a.displayName.localeCompare(b.displayName);
  });

  modelCache = models;
  return models;
}

function getModelInfo(modelId: string): GeminiModelInfo | undefined {
  return modelCache.find((m) => m.id === modelId);
}

function usesGenerateImagesApi(modelId: string): boolean {
  const info = getModelInfo(modelId);
  if (info) {
    return info.supportedActions.includes("generateImages");
  }
  // Heuristic: imagen models use the dedicated API
  return modelId.startsWith("imagen");
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

  // Choose API based on model capabilities
  const useImagenApi = usesGenerateImagesApi(request.model);

  let promises: Promise<void>[];
  if (useImagenApi) {
    // Imagen models: fire N parallel generateImages calls, each requesting 1 image
    promises = Array.from({ length: request.count }, (_, index) =>
      generateViaImagenApi(
        ai,
        request,
        messageId,
        index,
        window,
        abortController
      )
    );
  } else {
    // Gemini content models: fire N parallel generateContent calls
    promises = Array.from({ length: request.count }, (_, index) =>
      generateViaContentApi(
        ai,
        request,
        messageId,
        index,
        window,
        abortController
      )
    );
  }

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

/**
 * Uses the dedicated generateImages API (for Imagen-family models).
 * Returns images via generatedImages[].image.imageBytes.
 */
async function generateViaImagenApi(
  ai: GoogleGenAI,
  request: GenerateRequest,
  messageId: string,
  index: number,
  window: BrowserWindow,
  abortController: AbortController
): Promise<void> {
  if (abortController.signal.aborted) return;

  try {
    const prompt = `${request.prompt}\n\nVariation ${index + 1} of ${request.count}: Please create a unique interpretation.`;

    const response = await ai.models.generateImages({
      model: request.model,
      prompt,
      config: {
        numberOfImages: 1,
      },
    });

    if (abortController.signal.aborted) return;

    const generated = response.generatedImages;
    if (!generated?.length || !generated[0].image?.imageBytes) {
      throw new Error("No image returned from Imagen API");
    }

    const img = generated[0].image;
    const generatedImage: GeneratedImage = {
      id: randomUUID(),
      data: img.imageBytes!,
      mimeType: img.mimeType ?? "image/png",
      index,
    };

    await persistAndNotify(
      request.conversationId,
      messageId,
      generatedImage,
      window
    );
  } catch (err) {
    if (abortController.signal.aborted) return;
    await handleGenerationError(
      err,
      request.conversationId,
      messageId,
      index,
      window
    );
  }
}

/**
 * Uses generateContent with responseModalities: ["IMAGE"] (for Gemini Flash models).
 * Returns images via part.inlineData.
 */
async function generateViaContentApi(
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
    contents.push({
      text: `${request.prompt}\n\nVariation ${index + 1} of ${request.count}: Please create a unique interpretation of this as an image.`,
    });

    const response = await ai.models.generateContent({
      model: request.model,
      contents: [{ role: "user", parts: contents }],
      config: {
        responseModalities: ["IMAGE"],
      },
    });

    if (abortController.signal.aborted) return;

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
      if (part.inlineData?.data) {
        imageData = part.inlineData.data;
        mimeType = part.inlineData.mimeType ?? "image/png";
        break;
      }
    }

    if (!imageData) {
      // Log the actual response structure for debugging
      const partSummary = parts.map((p) => Object.keys(p)).join(", ");
      throw new Error(
        `No image data in response. Parts contained: [${partSummary}]`
      );
    }

    const generatedImage: GeneratedImage = {
      id: randomUUID(),
      data: imageData,
      mimeType,
      index,
    };

    await persistAndNotify(
      request.conversationId,
      messageId,
      generatedImage,
      window
    );
  } catch (err) {
    if (abortController.signal.aborted) return;
    await handleGenerationError(
      err,
      request.conversationId,
      messageId,
      index,
      window
    );
  }
}

async function persistAndNotify(
  conversationId: string,
  messageId: string,
  generatedImage: GeneratedImage,
  window: BrowserWindow
): Promise<void> {
  await updateMessage(conversationId, messageId, (msg) => ({
    ...msg,
    images: [...msg.images, generatedImage],
  }));

  const event: ImageResultEvent = {
    conversationId,
    messageId,
    image: generatedImage,
  };
  if (!window.isDestroyed()) {
    window.webContents.send(IPC_CHANNELS.GEMINI_IMAGE_RESULT, event);
  }
}

async function handleGenerationError(
  err: unknown,
  conversationId: string,
  messageId: string,
  index: number,
  window: BrowserWindow
): Promise<void> {
  const errorMessage = err instanceof Error ? err.message : String(err);

  await updateMessage(conversationId, messageId, (msg) => ({
    ...msg,
    errors: [...msg.errors, `Image ${index + 1}: ${errorMessage}`],
  }));

  const errorEvent: GenerationErrorEvent = {
    conversationId,
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
