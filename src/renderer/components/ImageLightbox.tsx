import { useCallback, useEffect, useState } from "react";
import { ChevronLeft, ChevronRight, Download } from "lucide-react";
import type { GeneratedImage } from "@/shared/types";
import { Dialog, DialogContent, DialogTrigger } from "./ui/dialog";
import { useSaveImage } from "@/renderer/hooks/useGemini";

interface ImageLightboxProps {
  readonly image: GeneratedImage;
  readonly allImages: readonly GeneratedImage[];
  readonly children: React.ReactNode;
}

export function ImageLightbox({ image, allImages, children }: ImageLightboxProps) {
  const saveImage = useSaveImage();
  const [open, setOpen] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);

  const currentImage = allImages[currentIndex];
  const src = currentImage
    ? `data:${currentImage.mimeType};base64,${currentImage.data}`
    : "";

  const hasPrev = currentIndex > 0;
  const hasNext = currentIndex < allImages.length - 1;

  const goToPrev = useCallback(() => {
    setCurrentIndex((i) => (i > 0 ? i - 1 : i));
  }, []);

  const goToNext = useCallback(() => {
    setCurrentIndex((i) => (i < allImages.length - 1 ? i + 1 : i));
  }, [allImages.length]);

  // Sync currentIndex when the dialog opens
  const handleOpenChange = useCallback(
    (nextOpen: boolean) => {
      if (nextOpen) {
        const idx = allImages.findIndex((img) => img.id === image.id);
        setCurrentIndex(idx >= 0 ? idx : 0);
      }
      setOpen(nextOpen);
    },
    [allImages, image.id],
  );

  // Keyboard navigation
  useEffect(() => {
    if (!open) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        goToPrev();
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        goToNext();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, goToPrev, goToNext]);

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="max-h-[90vh] max-w-[90vw]">
        {currentImage && (
          <>
            <img
              src={src}
              alt={`Generated image ${currentIndex + 1} of ${allImages.length}`}
              className="max-h-[85vh] max-w-[90vw] rounded-lg object-contain"
            />

            {/* Navigation arrows */}
            {hasPrev && (
              <button
                onClick={goToPrev}
                className="absolute left-3 top-[50%] translate-y-[-50%] rounded-full bg-black/60 p-2 text-white/80 transition-colors hover:bg-black/80 hover:text-white"
                title="Previous image"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>
            )}
            {hasNext && (
              <button
                onClick={goToNext}
                className="absolute right-12 top-[50%] translate-y-[-50%] rounded-full bg-black/60 p-2 text-white/80 transition-colors hover:bg-black/80 hover:text-white"
                title="Next image"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            )}

            {/* Footer: counter + save */}
            <div className="absolute bottom-3 left-3 right-3 flex items-center justify-between">
              <span className="rounded-full bg-black/60 px-3 py-1 text-xs text-white/80">
                {currentIndex + 1} / {allImages.length}
              </span>
              <button
                onClick={() => saveImage.mutate(currentImage)}
                className="rounded-md bg-black/60 p-2 text-white/80 transition-colors hover:bg-black/80 hover:text-white"
                title="Save image"
              >
                <Download className="h-5 w-5" />
              </button>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
