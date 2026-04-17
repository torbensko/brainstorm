import { contextBridge, ipcRenderer, type IpcRendererEvent } from "electron";

export interface ElectronAPI {
  invoke(channel: string, ...args: unknown[]): Promise<unknown>;
  on(
    channel: string,
    callback: (...args: unknown[]) => void
  ): () => void;
  getVersion(): string;
}

contextBridge.exposeInMainWorld("electronAPI", {
  invoke: (channel: string, ...args: unknown[]) =>
    ipcRenderer.invoke(channel, ...args),

  on: (channel: string, callback: (...args: unknown[]) => void) => {
    const listener = (_event: IpcRendererEvent, ...args: unknown[]) =>
      callback(...args);
    ipcRenderer.on(channel, listener);
    return () => {
      ipcRenderer.removeListener(channel, listener);
    };
  },

  getVersion: () => process.env.npm_package_version ?? "0.0.0",
} satisfies ElectronAPI);
