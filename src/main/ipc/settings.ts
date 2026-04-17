import { ipcMain, dialog, BrowserWindow } from "electron";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type { AppSettings } from "@/shared/types";
import { getSettings, setSettings } from "../services/SettingsService";

export function registerSettingsIpc(): void {
  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET, async () => {
    return getSettings();
  });

  ipcMain.handle(
    IPC_CHANNELS.SETTINGS_SET,
    async (_event, updates: Partial<AppSettings>) => {
      return setSettings(updates);
    }
  );

  ipcMain.handle(IPC_CHANNELS.SETTINGS_PICK_FOLDER, async (event) => {
    const window = BrowserWindow.fromWebContents(event.sender);
    if (!window) throw new Error("No window found for event");

    const result = await dialog.showOpenDialog(window, {
      properties: ["openDirectory", "createDirectory"],
      title: "Select download folder",
    });

    if (result.canceled || !result.filePaths.length) return null;
    return result.filePaths[0];
  });
}
