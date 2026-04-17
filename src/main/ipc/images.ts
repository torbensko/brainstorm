import { ipcMain, BrowserWindow } from "electron";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type { GeneratedImage } from "@/shared/types";
import { saveImage, saveAllImages } from "../services/ImageService";
import { getSettings } from "../services/SettingsService";

export function registerImagesIpc(): void {
  ipcMain.handle(
    IPC_CHANNELS.IMAGE_SAVE,
    async (event, image: GeneratedImage) => {
      const window = BrowserWindow.fromWebContents(event.sender);
      if (!window) throw new Error("No window found for event");
      const settings = await getSettings();
      return saveImage(image, window, settings.downloadFolder);
    }
  );

  ipcMain.handle(
    IPC_CHANNELS.IMAGE_SAVE_ALL,
    async (event, images: GeneratedImage[]) => {
      const window = BrowserWindow.fromWebContents(event.sender);
      if (!window) throw new Error("No window found for event");
      const settings = await getSettings();
      return saveAllImages(images, window, settings.downloadFolder);
    }
  );
}
