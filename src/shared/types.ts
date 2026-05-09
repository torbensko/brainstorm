export interface GeminiModelInfo {
  readonly id: string;
  readonly displayName: string;
  readonly description: string;
  readonly supportedActions: readonly string[];
}

/**
 * Known Nano Banana models that use generateContent with native image output.
 * These are hardcoded because the models.list API doesn't reliably indicate
 * which models support native image generation via generateContent.
 */
export const NANO_BANANA_MODELS: readonly GeminiModelInfo[] = [
  {
    id: "gemini-3.1-flash-image-preview",
    displayName: "Nano Banana 2 (3.1 Flash Image)",
    description: "Best all-around performance and speed",
    supportedActions: ["generateContent"],
  },
  {
    id: "gemini-3-pro-image-preview",
    displayName: "Nano Banana Pro (3 Pro Image)",
    description: "Professional asset production with thinking",
    supportedActions: ["generateContent"],
  },
  {
    id: "gemini-2.5-flash-image",
    displayName: "Nano Banana (2.5 Flash Image)",
    description: "High-volume, low-latency",
    supportedActions: ["generateContent"],
  },
];

export enum ImageResolution {
  HALF_K = "512",
  ONE_K = "1K",
  TWO_K = "2K",
  FOUR_K = "4K",
}

export const IMAGE_RESOLUTION_LABELS: Record<ImageResolution, string> = {
  [ImageResolution.HALF_K]: "0.5K (512)",
  [ImageResolution.ONE_K]: "1K",
  [ImageResolution.TWO_K]: "2K",
  [ImageResolution.FOUR_K]: "4K",
};

export enum AspectRatio {
  SQUARE = "1:1",
  PORTRAIT_2_3 = "2:3",
  LANDSCAPE_3_2 = "3:2",
  PORTRAIT_3_4 = "3:4",
  LANDSCAPE_4_3 = "4:3",
  PORTRAIT_9_16 = "9:16",
  LANDSCAPE_16_9 = "16:9",
  ULTRAWIDE_21_9 = "21:9",
}

export const ASPECT_RATIO_LABELS: Record<AspectRatio, string> = {
  [AspectRatio.SQUARE]: "1:1 Square",
  [AspectRatio.PORTRAIT_2_3]: "2:3 Portrait",
  [AspectRatio.LANDSCAPE_3_2]: "3:2 Landscape",
  [AspectRatio.PORTRAIT_3_4]: "3:4 Portrait",
  [AspectRatio.LANDSCAPE_4_3]: "4:3 Landscape",
  [AspectRatio.PORTRAIT_9_16]: "9:16 Tall",
  [AspectRatio.LANDSCAPE_16_9]: "16:9 Wide",
  [AspectRatio.ULTRAWIDE_21_9]: "21:9 Ultrawide",
};

export interface AttachedImage {
  readonly data: string; // base64
  readonly mimeType: string;
  readonly name: string;
}

export interface GenerateRequest {
  readonly conversationId: string;
  readonly prompt: string;
  readonly attachedImages: readonly AttachedImage[];
  readonly model: string;
  readonly aspectRatio: AspectRatio;
  readonly imageResolution: ImageResolution;
  readonly count: number;
}

export interface GeneratedImage {
  readonly id: string;
  readonly data: string; // base64
  readonly mimeType: string;
  readonly index: number;
  // Opaque signature returned by image-thinking models (e.g. Nano Banana Pro).
  // Must be echoed back on the same part in follow-up requests, or the API
  // rejects the turn with "Image part is missing a thought_signature".
  readonly thoughtSignature?: string;
}

export interface ImageResultEvent {
  readonly conversationId: string;
  readonly messageId: string;
  readonly image: GeneratedImage;
}

export interface GenerationErrorEvent {
  readonly conversationId: string;
  readonly messageId: string;
  readonly index: number;
  readonly error: string;
}

export interface GenerationCompleteEvent {
  readonly conversationId: string;
  readonly messageId: string;
}

export interface TitleGeneratedEvent {
  readonly conversationId: string;
  readonly title: string;
}

export interface Message {
  readonly id: string;
  readonly role: "user" | "assistant";
  readonly prompt: string;
  readonly attachedImages: readonly AttachedImage[];
  readonly images: GeneratedImage[];
  readonly model: string;
  readonly aspectRatio: AspectRatio;
  readonly imageResolution: ImageResolution;
  readonly requestedCount: number;
  readonly timestamp: string;
  readonly errors: string[];
  readonly complete: boolean;
}

export interface Conversation {
  readonly id: string;
  readonly title: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly messages: Message[];
}

export interface ConversationSummary {
  readonly id: string;
  readonly title: string;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface AppSettings {
  geminiApiKey: string;
  defaultModel: string;
  defaultAspectRatio: AspectRatio;
  defaultImageResolution: ImageResolution;
  defaultCount: number;
  downloadFolder: string;
}

export const DEFAULT_SETTINGS: AppSettings = {
  geminiApiKey: "",
  defaultModel: "gemini-3.1-flash-image-preview",
  defaultAspectRatio: AspectRatio.SQUARE,
  defaultImageResolution: ImageResolution.ONE_K,
  defaultCount: 4,
  downloadFolder: "~/Downloads",
};
