import { ipcMain, BrowserWindow } from "electron";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type { GenerateRequest } from "@/shared/types";
import {
  requestImages,
  cancelGeneration,
  listImageModels,
  generateConversationTitle,
} from "../services/GeminiService";

export function registerGeminiIpc(): void {
  ipcMain.handle(IPC_CHANNELS.GEMINI_LIST_MODELS, async () => {
    return listImageModels();
  });

  ipcMain.handle(
    IPC_CHANNELS.GEMINI_GENERATE,
    async (event, request: GenerateRequest) => {
      const window = BrowserWindow.fromWebContents(event.sender);
      if (!window) throw new Error("No window found for event");
      return requestImages(request, window);
    }
  );

  ipcMain.handle(
    IPC_CHANNELS.GEMINI_CANCEL,
    async (_event, conversationId: string, messageId: string) => {
      cancelGeneration(conversationId, messageId);
    }
  );

  ipcMain.handle(
    IPC_CHANNELS.GEMINI_GENERATE_TITLE,
    async (event, conversationId: string, prompt: string) => {
      const window = BrowserWindow.fromWebContents(event.sender);
      if (!window) throw new Error("No window found for event");
      // Fire-and-forget: don't await so the renderer isn't blocked
      generateConversationTitle(conversationId, prompt, window);
    }
  );
}
