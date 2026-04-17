import { ipcMain } from "electron";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import {
  listConversations,
  getConversation,
  createConversation,
  deleteConversation,
  updateConversationTitle,
} from "../services/ConversationService";

export function registerConversationsIpc(): void {
  ipcMain.handle(IPC_CHANNELS.CONVERSATION_LIST, async () => {
    return listConversations();
  });

  ipcMain.handle(
    IPC_CHANNELS.CONVERSATION_GET,
    async (_event, id: string) => {
      return getConversation(id);
    }
  );

  ipcMain.handle(
    IPC_CHANNELS.CONVERSATION_CREATE,
    async (_event, title: string) => {
      return createConversation(title);
    }
  );

  ipcMain.handle(
    IPC_CHANNELS.CONVERSATION_DELETE,
    async (_event, id: string) => {
      return deleteConversation(id);
    }
  );

  ipcMain.handle(
    IPC_CHANNELS.CONVERSATION_UPDATE_TITLE,
    async (_event, id: string, title: string) => {
      return updateConversationTitle(id, title);
    }
  );
}
