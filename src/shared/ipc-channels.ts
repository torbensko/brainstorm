export const IPC_CHANNELS = {
  // Gemini
  GEMINI_GENERATE: "gemini:generate",
  GEMINI_CANCEL: "gemini:cancel",
  GEMINI_IMAGE_RESULT: "gemini:image-result",
  GEMINI_GENERATION_ERROR: "gemini:generation-error",
  GEMINI_GENERATION_COMPLETE: "gemini:generation-complete",

  GEMINI_LIST_MODELS: "gemini:list-models",

  // Settings
  SETTINGS_GET: "settings:get",
  SETTINGS_SET: "settings:set",

  // Conversations
  CONVERSATION_LIST: "conversation:list",
  CONVERSATION_GET: "conversation:get",
  CONVERSATION_CREATE: "conversation:create",
  CONVERSATION_DELETE: "conversation:delete",
  CONVERSATION_UPDATE_TITLE: "conversation:update-title",

  // Images
  IMAGE_SAVE: "image:save",
  IMAGE_SAVE_ALL: "image:save-all",
} as const;

export type IpcChannel = (typeof IPC_CHANNELS)[keyof typeof IPC_CHANNELS];
