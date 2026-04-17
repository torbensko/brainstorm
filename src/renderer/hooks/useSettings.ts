import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type { AppSettings } from "@/shared/types";

export function useSettings() {
  return useQuery<AppSettings>({
    queryKey: ["settings"],
    queryFn: () =>
      window.electronAPI.invoke(IPC_CHANNELS.SETTINGS_GET) as Promise<AppSettings>,
  });
}

export function useUpdateSettings() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (updates: Partial<AppSettings>) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.SETTINGS_SET,
        updates
      ) as Promise<AppSettings>,
    onSuccess: (data) => {
      queryClient.setQueryData(["settings"], data);
    },
  });
}

export function usePickFolder() {
  return useMutation({
    mutationFn: () =>
      window.electronAPI.invoke(
        IPC_CHANNELS.SETTINGS_PICK_FOLDER
      ) as Promise<string | null>,
  });
}
