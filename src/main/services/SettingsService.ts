import type { AppSettings } from "@/shared/types";
import { DEFAULT_SETTINGS } from "@/shared/types";

let storeInstance: import("electron-store").default | null = null;

async function getStore(): Promise<import("electron-store").default> {
  if (storeInstance) return storeInstance;
  const { default: Store } = await import("electron-store");
  storeInstance = new Store({
    name: "settings",
    defaults: { settings: DEFAULT_SETTINGS },
  });
  return storeInstance;
}

export async function getSettings(): Promise<AppSettings> {
  const store = await getStore();
  return store.get("settings", DEFAULT_SETTINGS) as AppSettings;
}

export async function setSettings(
  updates: Partial<AppSettings>
): Promise<AppSettings> {
  const store = await getStore();
  const current = store.get("settings", DEFAULT_SETTINGS) as AppSettings;
  const merged = { ...current, ...updates };
  store.set("settings", merged);
  return merged;
}
