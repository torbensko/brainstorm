import { Download, Plus } from "lucide-react";
import type { GeneratedImage } from "@/shared/types";
import { useSaveImage } from "@/renderer/hooks/useGemini";
import { ImageLightbox } from "./ImageLightbox";

interface ImageCardProps {
  readonly image: GeneratedImage;
  readonly allImages: readonly GeneratedImage[];
  readonly onSelectAsContext?: (image: GeneratedImage) => void;
  readonly contextSelectionDisabled?: boolean;
}

export function ImageCard({
  image,
  allImages,
  onSelectAsContext,
  contextSelectionDisabled,
}: ImageCardProps) {
  const saveImage = useSaveImage();

  const src = `data:${image.mimeType};base64,${image.data}`;

  return (
    <ImageLightbox image={image} allImages={allImages}>
      <div className="group relative cursor-pointer overflow-hidden rounded-lg border bg-muted">
        <img
          src={src}
          alt={`Generated image ${image.index + 1}`}
          className="aspect-square w-full object-cover"
        />
        <div className="absolute inset-0 flex items-end justify-end bg-gradient-to-t from-black/40 to-transparent p-2 opacity-0 transition-opacity group-hover:opacity-100">
          <div className="flex gap-1">
            {onSelectAsContext && !contextSelectionDisabled && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onSelectAsContext(image);
                }}
                className="rounded-md bg-white/90 p-2 text-black shadow transition-colors hover:bg-white"
                title="Use as context"
              >
                <Plus className="h-4 w-4" />
              </button>
            )}
            <button
              onClick={(e) => {
                e.stopPropagation();
                saveImage.mutate(image);
              }}
              className="rounded-md bg-white/90 p-2 text-black shadow transition-colors hover:bg-white"
              title="Save image"
            >
              <Download className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </ImageLightbox>
  );
}
