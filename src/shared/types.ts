export interface GeminiModelInfo {
  readonly id: string;
  readonly displayName: string;
  readonly description: string;
  readonly supportedActions: readonly string[];
}

export enum ImageSize {
  SMALL = "256x256",
  MEDIUM = "512x512",
  LARGE = "1024x1024",
}

export const IMAGE_SIZE_LABELS: Record<ImageSize, string> = {
  [ImageSize.SMALL]: "Small (256×256)",
  [ImageSize.MEDIUM]: "Medium (512×512)",
  [ImageSize.LARGE]: "Large (1024×1024)",
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
  readonly imageSize: ImageSize;
  readonly count: number;
}

export interface GeneratedImage {
  readonly id: string;
  readonly data: string; // base64
  readonly mimeType: string;
  readonly index: number;
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

export interface Message {
  readonly id: string;
  readonly role: "user" | "assistant";
  readonly prompt: string;
  readonly attachedImages: readonly AttachedImage[];
  readonly images: GeneratedImage[];
  readonly model: string;
  readonly imageSize: ImageSize;
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
  defaultImageSize: ImageSize;
  defaultCount: number;
}

export const DEFAULT_SETTINGS: AppSettings = {
  geminiApiKey: "",
  defaultModel: "gemini-2.0-flash-preview-image-generation",
  defaultImageSize: ImageSize.MEDIUM,
  defaultCount: 4,
};
