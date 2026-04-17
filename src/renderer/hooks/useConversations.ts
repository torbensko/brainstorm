import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type { Conversation, ConversationSummary } from "@/shared/types";

export function useConversationList() {
  return useQuery<ConversationSummary[]>({
    queryKey: ["conversations"],
    queryFn: () =>
      window.electronAPI.invoke(
        IPC_CHANNELS.CONVERSATION_LIST
      ) as Promise<ConversationSummary[]>,
  });
}

export function useConversation(id: string | null) {
  return useQuery<Conversation | null>({
    queryKey: ["conversation", id],
    queryFn: () =>
      id
        ? (window.electronAPI.invoke(
            IPC_CHANNELS.CONVERSATION_GET,
            id
          ) as Promise<Conversation | null>)
        : Promise.resolve(null),
    enabled: !!id,
  });
}

export function useCreateConversation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (title: string) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.CONVERSATION_CREATE,
        title
      ) as Promise<Conversation>,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    },
  });
}

export function useDeleteConversation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.CONVERSATION_DELETE,
        id
      ) as Promise<void>,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    },
  });
}

export function useUpdateConversationTitle() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, title }: { id: string; title: string }) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.CONVERSATION_UPDATE_TITLE,
        id,
        title
      ) as Promise<Conversation>,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    },
  });
}
