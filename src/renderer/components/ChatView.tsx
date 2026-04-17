import { useEffect, useRef } from "react";
import { Loader2 } from "lucide-react";
import type { Message, AttachedImage } from "@/shared/types";
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

  useGeminiEvents(conversationId);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [conversation?.messages]);

  const isGenerating =
    conversation?.messages.some(
      (m: Message) => m.role === "assistant" && !m.complete
    ) ?? false;

  const handleSubmit = (data: {
    prompt: string;
    attachedImages: AttachedImage[];
    model: string;
    aspectRatio: AspectRatio;
    imageResolution: ImageResolution;
    count: number;
  }) => {
    generate.mutate({
      conversationId,
      ...data,
    });
  };

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
                          )
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
                    <ImageGrid message={message} />
                  </div>
                </div>
              )}
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Input area */}
      <ChatInput onSubmit={handleSubmit} isGenerating={isGenerating} />
    </div>
  );
}
