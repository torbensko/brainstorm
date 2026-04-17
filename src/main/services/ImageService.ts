import { dialog, BrowserWindow } from "electron";
import { writeFile, mkdir } from "fs/promises";
import path from "path";
import type { GeneratedImage } from "@/shared/types";

export async function saveImage(
  image: GeneratedImage,
  window: BrowserWindow
): Promise<string | null> {
  const ext = mimeToExt(image.mimeType);
  const result = await dialog.showSaveDialog(window, {
    defaultPath: `brainstorm-image-${image.index + 1}.${ext}`,
    filters: [{ name: "Images", extensions: [ext] }],
  });

  if (result.canceled || !result.filePath) return null;

  const buffer = Buffer.from(image.data, "base64");
  await writeFile(result.filePath, buffer);
  return result.filePath;
}

export async function saveAllImages(
  images: readonly GeneratedImage[],
  window: BrowserWindow
): Promise<string | null> {
  const result = await dialog.showOpenDialog(window, {
    properties: ["openDirectory", "createDirectory"],
    title: "Select folder to save all images",
  });

  if (result.canceled || !result.filePaths.length) return null;

  const dir = result.filePaths[0];
  await mkdir(dir, { recursive: true });

  await Promise.all(
    images.map(async (image) => {
      const ext = mimeToExt(image.mimeType);
      const filePath = path.join(dir, `brainstorm-image-${image.index + 1}.${ext}`);
      const buffer = Buffer.from(image.data, "base64");
      await writeFile(filePath, buffer);
    })
  );

  return dir;
}

function mimeToExt(mimeType: string): string {
  switch (mimeType) {
    case "image/png":
      return "png";
    case "image/jpeg":
      return "jpg";
    case "image/webp":
      return "webp";
    default:
      return "png";
  }
}
