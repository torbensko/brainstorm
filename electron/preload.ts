import { contextBridge, ipcRenderer, type IpcRendererEvent } from "electron";

export interface ElectronAPI {
  invoke(channel: string, ...args: unknown[]): Promise<unknown>;
  on(
    channel: string,
    callback: (...args: unknown[]) => void
  ): () => void;
  getVersion(): Promise<string>;
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

  getVersion: () => ipcRenderer.invoke("app:get-version"),
} satisfies ElectronAPI);
