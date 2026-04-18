import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Loader2 } from "lucide-react";
import type {
  Message,
  AttachedImage,
  GeneratedImage,
} from "@/shared/types";
import { AspectRatio, ImageResolution } from "@/shared/types";
import { useConversation } from "@/renderer/hooks/useConversations";
import { useGenerate, useGeminiEvents } from "@/renderer/hooks/useGemini";
import { ChatInput } from "./ChatInput";
import { ImageGrid } from "./ImageGrid";

interface ChatViewProps {
  readonly conversationId: string;
}

export function ChatView({ conversationId }: ChatViewProps) {
  const { data: conversation, isLoading } = useConversation(conversationId);
  const generate = useGenerate();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [contextImages, setContextImages] = useState<AttachedImage[]>([]);

  useGeminiEvents(conversationId);

  // Clear context images when switching conversations
  useEffect(() => {
    setContextImages([]);
  }, [conversationId]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [conversation?.messages]);

  const allImages = useMemo(
    () =>
      conversation?.messages.flatMap((m: Message) =>
        m.role === "assistant"
          ? m.images
              .slice()
              .sort(
                (a: GeneratedImage, b: GeneratedImage) => a.index - b.index,
              )
          : [],
      ) ?? [],
    [conversation?.messages],
  );

  const isGenerating =
    conversation?.messages.some(
      (m: Message) => m.role === "assistant" && !m.complete,
    ) ?? false;

  const contextSelectionDisabled = contextImages.length > 0;

  const handleSelectAsContext = useCallback((image: GeneratedImage) => {
    const asAttached: AttachedImage = {
      data: image.data,
      mimeType: image.mimeType,
      name: `Generated image ${image.index + 1}`,
    };
    setContextImages((prev) => [...prev, asAttached]);
  }, []);

  const handleRemoveContextImage = useCallback((index: number) => {
    setContextImages((prev) => prev.filter((_, i) => i !== index));
  }, []);

  const handleSubmit = (data: {
    prompt: string;
    attachedImages: AttachedImage[];
    model: string;
    aspectRatio: AspectRatio;
    imageResolution: ImageResolution;
    count: number;
  }) => {
    // Merge context images into attached images for the request
    const mergedAttachedImages = [...contextImages, ...data.attachedImages];
    generate.mutate({
      conversationId,
      ...data,
      attachedImages: mergedAttachedImages,
    });
    setContextImages([]);
  };

  const handleGenerateMore = useCallback(
    (assistantMessage: Message) => {
      if (!conversation || isGenerating) return;

      // Find the user message that preceded this assistant message
      const messages = conversation.messages;
      const assistantIndex = messages.findIndex(
        (m) => m.id === assistantMessage.id,
      );
      if (assistantIndex <= 0) return;

      const userMessage = messages[assistantIndex - 1];
      if (userMessage.role !== "user") return;

      generate.mutate({
        conversationId,
        prompt: userMessage.prompt,
        attachedImages: [...userMessage.attachedImages],
        model: userMessage.model,
        aspectRatio: userMessage.aspectRatio,
        imageResolution: userMessage.imageResolution,
        count: userMessage.requestedCount,
      });
    },
    [conversation, conversationId, generate, isGenerating],
  );

  if (isLoading) {
    return (
      <div className="flex h-full items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col">
      {/* Messages area */}
      <div className="flex-1 overflow-y-auto p-4">
        {conversation?.messages.length === 0 && (
          <div className="flex h-full items-center justify-center">
            <div className="text-center">
              <h2 className="mb-2 text-lg font-medium text-muted-foreground">
                Start brainstorming
              </h2>
              <p className="text-sm text-muted-foreground">
                Enter a prompt below to generate multiple image variations
              </p>
            </div>
          </div>
        )}

        <div className="mx-auto max-w-4xl space-y-6">
          {conversation?.messages.map((message: Message) => (
            <div key={message.id}>
              {message.role === "user" ? (
                <div className="flex justify-end">
                  <div className="max-w-[80%] space-y-2">
                    {message.attachedImages.length > 0 && (
                      <div className="flex flex-wrap justify-end gap-2">
                        {message.attachedImages.map(
                          (img: AttachedImage, i: number) => (
                            <img
                              key={i}
                              src={`data:${img.mimeType};base64,${img.data}`}
                              alt={img.name}
                              className="h-20 w-20 rounded-md border object-cover"
                            />
                          ),
                        )}
                      </div>
                    )}
                    <div className="rounded-2xl rounded-br-md bg-primary px-4 py-2 text-primary-foreground">
                      <p className="text-sm whitespace-pre-wrap">
                        {message.prompt}
                      </p>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="flex justify-start">
                  <div className="max-w-[90%]">
                    <ImageGrid
                      message={message}
                      allImages={allImages}
                      onSelectAsContext={handleSelectAsContext}
                      contextSelectionDisabled={contextSelectionDisabled}
                      onGenerateMore={
                        !isGenerating
                          ? () => handleGenerateMore(message)
                          : undefined
                      }
                    />
                  </div>
                </div>
              )}
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Input area */}
      <ChatInput
        onSubmit={handleSubmit}
        isGenerating={isGenerating}
        contextImages={contextImages}
        onRemoveContextImage={handleRemoveContextImage}
      />
    </div>
  );
}
