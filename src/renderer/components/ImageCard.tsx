import { Download } from "lucide-react";
import type { GeneratedImage } from "@/shared/types";
import { useSaveImage } from "@/renderer/hooks/useGemini";

interface ImageCardProps {
  readonly image: GeneratedImage;
}

export function ImageCard({ image }: ImageCardProps) {
  const saveImage = useSaveImage();

  const src = `data:${image.mimeType};base64,${image.data}`;

  return (
    <div className="group relative overflow-hidden rounded-lg border bg-muted">
      <img
        src={src}
        alt={`Generated image ${image.index + 1}`}
        className="aspect-square w-full object-cover"
      />
      <div className="absolute inset-0 flex items-end justify-end bg-gradient-to-t from-black/40 to-transparent p-2 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onClick={() => saveImage.mutate(image)}
          className="rounded-md bg-white/90 p-2 text-black shadow transition-colors hover:bg-white"
          title="Save image"
        >
          <Download className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
