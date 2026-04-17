import { ipcMain } from "electron";
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
}
