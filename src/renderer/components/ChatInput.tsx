import { useState, useRef } from "react";
import { Send, ImagePlus, X, Loader2 } from "lucide-react";
import {
  AspectRatio,
  ASPECT_RATIO_LABELS,
  ImageResolution,
  IMAGE_RESOLUTION_LABELS,
  DEFAULT_SETTINGS,
  NANO_BANANA_MODELS,
  type AttachedImage,
  type GeminiModelInfo,
} from "@/shared/types";
import { useSettings, useUpdateSettings } from "@/renderer/hooks/useSettings";

interface ChatInputProps {
  readonly onSubmit: (data: {
    prompt: string;
    attachedImages: AttachedImage[];
    model: string;
    aspectRatio: AspectRatio;
    imageResolution: ImageResolution;
    count: number;
  }) => void;
  readonly isGenerating: boolean;
  readonly contextImages?: readonly AttachedImage[];
  readonly onRemoveContextImage?: (index: number) => void;
}

export function ChatInput({
  onSubmit,
  isGenerating,
  contextImages,
  onRemoveContextImage,
}: ChatInputProps) {
  const { data: settings } = useSettings();
  const updateSettings = useUpdateSettings();
  const [prompt, setPrompt] = useState("");
  const [attachedImages, setAttachedImages] = useState<AttachedImage[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const effectiveModel =
    settings?.defaultModel ?? DEFAULT_SETTINGS.defaultModel;
  const effectiveAspectRatio =
    settings?.defaultAspectRatio ?? DEFAULT_SETTINGS.defaultAspectRatio;
  const effectiveResolution =
    settings?.defaultImageResolution ??
    DEFAULT_SETTINGS.defaultImageResolution;
  const effectiveCount = settings?.defaultCount ?? 4;

  const handleModelChange = (value: string) => {
    updateSettings.mutate({ defaultModel: value });
  };

  const handleAspectRatioChange = (value: AspectRatio) => {
    updateSettings.mutate({ defaultAspectRatio: value });
  };

  const handleResolutionChange = (value: ImageResolution) => {
    updateSettings.mutate({ defaultImageResolution: value });
  };

  const handleCountChange = (value: number) => {
    if (value >= 1 && value <= 8) {
      updateSettings.mutate({ defaultCount: value });
    }
  };

  const handleSubmit = () => {
    const trimmed = prompt.trim();
    if (!trimmed || isGenerating) return;
    onSubmit({
      prompt: trimmed,
      attachedImages,
      model: effectiveModel,
      aspectRatio: effectiveAspectRatio,
      imageResolution: effectiveResolution,
      count: effectiveCount,
    });
    setPrompt("");
    setAttachedImages([]);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;

    const newImages: AttachedImage[] = [];
    for (const file of Array.from(files)) {
      if (!file.type.startsWith("image/")) continue;
      const buffer = await file.arrayBuffer();
      const data = btoa(
        new Uint8Array(buffer).reduce(
          (acc, byte) => acc + String.fromCharCode(byte),
          ""
        )
      );
      newImages.push({ data, mimeType: file.type, name: file.name });
    }

    setAttachedImages((prev) => [...prev, ...newImages]);
    e.target.value = "";
  };

  const removeImage = (index: number) => {
    setAttachedImages((prev) => prev.filter((_, i) => i !== index));
  };

  return (
    <div className="border-t bg-background p-4">
      {/* Context images from conversation */}
      {contextImages && contextImages.length > 0 && (
        <div className="mb-3">
          <p className="mb-1.5 text-xs font-medium text-muted-foreground">
            Context from conversation
          </p>
          <div className="flex flex-wrap gap-2">
            {contextImages.map((img, i) => (
              <div key={i} className="group relative">
                <img
                  src={`data:${img.mimeType};base64,${img.data}`}
                  alt={img.name}
                  className="h-16 w-16 rounded-md border-2 border-primary object-cover"
                />
                {onRemoveContextImage && (
                  <button
                    onClick={() => onRemoveContextImage(i)}
                    className="absolute -right-1 -top-1 rounded-full bg-destructive p-0.5 text-destructive-foreground shadow"
                  >
                    <X className="h-3 w-3" />
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Attached images preview */}
      {attachedImages.length > 0 && (
        <div className="mb-3 flex flex-wrap gap-2">
          {attachedImages.map((img, i) => (
            <div key={i} className="group relative">
              <img
                src={`data:${img.mimeType};base64,${img.data}`}
                alt={img.name}
                className="h-16 w-16 rounded-md border object-cover"
              />
              <button
                onClick={() => removeImage(i)}
                className="absolute -right-1 -top-1 rounded-full bg-destructive p-0.5 text-destructive-foreground shadow"
              >
                <X className="h-3 w-3" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Options row */}
      <div className="mb-3 flex flex-wrap gap-3">
        <select
          value={effectiveModel}
          onChange={(e) => handleModelChange(e.target.value)}
          className="rounded-md border bg-background px-2 py-1 text-xs outline-none focus:ring-1 focus:ring-ring"
        >
          {NANO_BANANA_MODELS.map((m: GeminiModelInfo) => (
            <option key={m.id} value={m.id}>
              {m.displayName}
            </option>
          ))}
        </select>

        <select
          value={effectiveAspectRatio}
          onChange={(e) =>
            handleAspectRatioChange(e.target.value as AspectRatio)
          }
          className="rounded-md border bg-background px-2 py-1 text-xs outline-none focus:ring-1 focus:ring-ring"
        >
          {Object.entries(ASPECT_RATIO_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>

        <select
          value={effectiveResolution}
          onChange={(e) =>
            handleResolutionChange(e.target.value as ImageResolution)
          }
          className="rounded-md border bg-background px-2 py-1 text-xs outline-none focus:ring-1 focus:ring-ring"
        >
          {Object.entries(IMAGE_RESOLUTION_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>

        <div className="flex items-center gap-1">
          <label className="text-xs text-muted-foreground">Images:</label>
          <input
            type="number"
            min={1}
            max={8}
            value={effectiveCount}
            onChange={(e) => handleCountChange(parseInt(e.target.value, 10))}
            className="w-14 rounded-md border bg-background px-2 py-1 text-xs outline-none focus:ring-1 focus:ring-ring"
          />
        </div>
      </div>

      {/* Prompt input row */}
      <div className="flex items-end gap-2">
        <button
          onClick={() => fileInputRef.current?.click()}
          className="shrink-0 rounded-md border p-2 text-muted-foreground transition-colors hover:text-foreground"
          title="Attach image"
        >
          <ImagePlus className="h-5 w-5" />
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          onChange={handleFileSelect}
          className="hidden"
        />

        <textarea
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Describe the image you want to generate..."
          rows={1}
          className="max-h-32 min-h-[40px] flex-1 resize-none rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
        />

        <button
          onClick={handleSubmit}
          disabled={!prompt.trim() || isGenerating}
          className="shrink-0 rounded-md bg-primary p-2 text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-50"
          title="Generate images"
        >
          {isGenerating ? (
            <Loader2 className="h-5 w-5 animate-spin" />
          ) : (
            <Send className="h-5 w-5" />
          )}
        </button>
      </div>
    </div>
  );
}
