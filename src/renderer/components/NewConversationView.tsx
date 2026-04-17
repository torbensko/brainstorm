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
    // 1. Create the conversation
    const conversation = await createConversation.mutateAsync(
      "New Conversation"
    );

    // 2. Navigate to it immediately
    onCreated(conversation.id);

    // 3. Start image generation
    generate.mutate({
      conversationId: conversation.id,
      ...data,
    });

    // 4. Fire-and-forget title generation
    generateTitle.mutate({
      conversationId: conversation.id,
      prompt: data.prompt,
    });
  };

  return (
    <div className="flex h-full flex-col">
      <div className="app-draggable h-12 border-b" />
      <div className="flex flex-1 items-center justify-center px-4">
        <div className="w-full max-w-2xl">
          <div className="mb-6 text-center">
            <h2 className="mb-2 text-2xl font-semibold">
              Start a new conversation
            </h2>
            <p className="text-muted-foreground">
              Describe the image you want to generate
            </p>
          </div>
          <ChatInput onSubmit={handleSubmit} isGenerating={false} />
        </div>
      </div>
    </div>
  );
}
