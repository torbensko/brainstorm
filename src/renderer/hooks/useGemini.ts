import { useEffect, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { IPC_CHANNELS } from "@/shared/ipc-channels";
import type {
  GenerateRequest,
  GeminiModelInfo,
  ImageResultEvent,
  GenerationErrorEvent,
  GenerationCompleteEvent,
} from "@/shared/types";

export function useImageModels() {
  return useQuery<GeminiModelInfo[]>({
    queryKey: ["gemini-models"],
    queryFn: () =>
      window.electronAPI.invoke(
        IPC_CHANNELS.GEMINI_LIST_MODELS
      ) as Promise<GeminiModelInfo[]>,
    staleTime: 5 * 60 * 1000, // cache for 5 minutes
  });
}

export function useGenerate() {
  return useMutation({
    mutationFn: (request: GenerateRequest) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.GEMINI_GENERATE,
        request
      ) as Promise<string>,
  });
}

export function useGeminiEvents(conversationId: string | null) {
  const queryClient = useQueryClient();

  const invalidateConversation = useCallback(() => {
    if (conversationId) {
      queryClient.invalidateQueries({
        queryKey: ["conversation", conversationId],
      });
    }
  }, [queryClient, conversationId]);

  useEffect(() => {
    const cleanups: (() => void)[] = [];

    cleanups.push(
      window.electronAPI.on(
        IPC_CHANNELS.GEMINI_IMAGE_RESULT,
        (_event: unknown) => {
          const event = _event as ImageResultEvent;
          if (event.conversationId === conversationId) {
            invalidateConversation();
          }
        }
      )
    );

    cleanups.push(
      window.electronAPI.on(
        IPC_CHANNELS.GEMINI_GENERATION_ERROR,
        (_event: unknown) => {
          const event = _event as GenerationErrorEvent;
          if (event.conversationId === conversationId) {
            invalidateConversation();
          }
        }
      )
    );

    cleanups.push(
      window.electronAPI.on(
        IPC_CHANNELS.GEMINI_GENERATION_COMPLETE,
        (_event: unknown) => {
          const event = _event as GenerationCompleteEvent;
          if (event.conversationId === conversationId) {
            invalidateConversation();
            queryClient.invalidateQueries({ queryKey: ["conversations"] });
          }
        }
      )
    );

    return () => cleanups.forEach((fn) => fn());
  }, [conversationId, invalidateConversation, queryClient]);
}

export function useSaveImage() {
  return useMutation({
    mutationFn: (image: {
      data: string;
      mimeType: string;
      id: string;
      index: number;
    }) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.IMAGE_SAVE,
        image
      ) as Promise<string | null>,
  });
}

export function useSaveAllImages() {
  return useMutation({
    mutationFn: (
      images: Array<{
        data: string;
        mimeType: string;
        id: string;
        index: number;
      }>
    ) =>
      window.electronAPI.invoke(
        IPC_CHANNELS.IMAGE_SAVE_ALL,
        images
      ) as Promise<string | null>,
  });
}
