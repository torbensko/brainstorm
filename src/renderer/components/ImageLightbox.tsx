import { Download } from "lucide-react";
import type { GeneratedImage } from "@/shared/types";
import { Dialog, DialogContent, DialogTrigger } from "./ui/dialog";
import { useSaveImage } from "@/renderer/hooks/useGemini";

interface ImageLightboxProps {
  readonly image: GeneratedImage;
  readonly children: React.ReactNode;
}

export function ImageLightbox({ image, children }: ImageLightboxProps) {
  const saveImage = useSaveImage();
  const src = `data:${image.mimeType};base64,${image.data}`;

  return (
    <Dialog>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="max-h-[90vh] max-w-[90vw]">
        <img
          src={src}
          alt={`Generated image ${image.index + 1}`}
          className="max-h-[85vh] max-w-[90vw] rounded-lg object-contain"
        />
        <div className="absolute bottom-3 right-3">
          <button
            onClick={() => saveImage.mutate(image)}
            className="rounded-md bg-black/60 p-2 text-white/80 transition-colors hover:bg-black/80 hover:text-white"
            title="Save image"
          >
            <Download className="h-5 w-5" />
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
