import type { AttachedImage } from "@/shared/types";
import { AspectRatio, ImageResolution } from "@/shared/types";
import { useCreateConversation } from "@/renderer/hooks/useConversations";
import { useGenerate, useGenerateTitle } from "@/renderer/hooks/useGemini";
import { ChatInput } from "./ChatInput";

interface NewConversationViewProps {
  readonly onCreated: (conversationId: string) => void;
}

export function NewConversationView({ onCreated }: NewConversationViewProps) {
  const createConversation = useCreateConversation();
  const generate = useGenerate();
  const generateTitle = useGenerateTitle();

  const handleSubmit = async (data: {
    prompt: string;
    attachedImages: AttachedImage[];
    model: string;
    aspectRatio: AspectRatio;
    imageResolution: ImageResolution;
    count: number;
  }) => {
    const conversation = await createConversation.mutateAsync(
      "New Conversation"
    );

    onCreated(conversation.id);

    generate.mutate({
      conversationId: conversation.id,
      ...data,
    });

    generateTitle.mutate({
      conversationId: conversation.id,
      prompt: data.prompt,
    });
  };

  return (
    <div className="flex h-full flex-col">
      <div className="app-draggable h-12 shrink-0" />
      <div className="flex flex-1 flex-col items-center justify-center px-4">
        <div className="mb-8 text-center">
          <h2 className="display-heading text-5xl leading-tight">
            Where should we start?
          </h2>
        </div>
        <div className="w-full max-w-3xl">
          <ChatInput
            onSubmit={handleSubmit}
            isGenerating={false}
            acceptDropAnywhere
          />
        </div>
      </div>
    </div>
  );
}
