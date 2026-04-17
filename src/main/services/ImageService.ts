import { dialog, BrowserWindow, app } from "electron";
import { writeFile, mkdir } from "fs/promises";
import path from "path";
import type { GeneratedImage } from "@/shared/types";

/**
 * Resolve a download folder path, expanding ~ to the user's home directory.
 */
function resolveDownloadFolder(folder: string): string {
  if (folder.startsWith("~/")) {
    return path.join(app.getPath("home"), folder.slice(2));
  }
  return folder;
}

/**
 * Generate a timestamped filename to avoid collisions in the download folder.
 */
function generateFilename(image: GeneratedImage): string {
  const ext = mimeToExt(image.mimeType);
  const timestamp = Date.now();
  return `brainstorm-image-${image.index + 1}-${timestamp}.${ext}`;
}

export async function saveImage(
  image: GeneratedImage,
  window: BrowserWindow,
  downloadFolder?: string
): Promise<string | null> {
  if (downloadFolder) {
    const dir = resolveDownloadFolder(downloadFolder);
    await mkdir(dir, { recursive: true });
    const filePath = path.join(dir, generateFilename(image));
    const buffer = Buffer.from(image.data, "base64");
    await writeFile(filePath, buffer);
    return filePath;
  }

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
  window: BrowserWindow,
  downloadFolder?: string
): Promise<string | null> {
  let dir: string;

  if (downloadFolder) {
    dir = resolveDownloadFolder(downloadFolder);
  } else {
    const result = await dialog.showOpenDialog(window, {
      properties: ["openDirectory", "createDirectory"],
      title: "Select folder to save all images",
    });

    if (result.canceled || !result.filePaths.length) return null;
    dir = result.filePaths[0];
  }

  await mkdir(dir, { recursive: true });

  const timestamp = Date.now();
  await Promise.all(
    images.map(async (image) => {
      const ext = mimeToExt(image.mimeType);
      const filePath = path.join(dir, `brainstorm-image-${image.index + 1}-${timestamp}.${ext}`);
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
