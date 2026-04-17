import { Download, Loader2 } from "lucide-react";
import type { GeneratedImage, Message } from "@/shared/types";
import { ImageCard } from "./ImageCard";
import { useSaveAllImages } from "@/renderer/hooks/useGemini";

interface ImageGridProps {
  readonly message: Message;
  readonly allImages: readonly GeneratedImage[];
}

export function ImageGrid({ message, allImages }: ImageGridProps) {
  const saveAll = useSaveAllImages();
  const pendingCount = message.requestedCount - message.images.length - message.errors.length;
  const showPending = !message.complete && pendingCount > 0;

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {message.images
          .slice()
          .sort((a, b) => a.index - b.index)
          .map((image: GeneratedImage) => (
            <ImageCard key={image.id} image={image} allImages={allImages} />
          ))}
        {showPending &&
          Array.from({ length: pendingCount }).map((_, i) => (
            <div
              key={`pending-${i}`}
              className="flex aspect-square items-center justify-center rounded-lg border bg-muted"
            >
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          ))}
      </div>

      {message.errors.length > 0 && (
        <div className="space-y-1">
          {message.errors.map((error, i) => (
            <p key={i} className="text-sm text-destructive">
              {error}
            </p>
          ))}
        </div>
      )}

      {message.images.length > 1 && message.complete && (
        <button
          onClick={() => saveAll.mutate([...message.images])}
          disabled={saveAll.isPending}
          className="flex items-center gap-2 rounded-md border px-3 py-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground disabled:opacity-50"
        >
          <Download className="h-4 w-4" />
          {saveAll.isPending ? "Saving..." : "Save All Images"}
        </button>
      )}
    </div>
  );
}
