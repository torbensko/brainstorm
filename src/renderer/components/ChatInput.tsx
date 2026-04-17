import { useState, useRef } from "react";
import { Send, ImagePlus, X, Loader2 } from "lucide-react";
import {
  ImageSize,
  IMAGE_SIZE_LABELS,
  DEFAULT_SETTINGS,
  type AttachedImage,
} from "@/shared/types";
import { useSettings, useUpdateSettings } from "@/renderer/hooks/useSettings";
import { useImageModels } from "@/renderer/hooks/useGemini";

interface ChatInputProps {
  readonly onSubmit: (data: {
    prompt: string;
    attachedImages: AttachedImage[];
    model: string;
    imageSize: ImageSize;
    count: number;
  }) => void;
  readonly isGenerating: boolean;
}

export function ChatInput({ onSubmit, isGenerating }: ChatInputProps) {
  const { data: settings } = useSettings();
  const updateSettings = useUpdateSettings();
  const { data: models, isLoading: modelsLoading } = useImageModels();
  const [prompt, setPrompt] = useState("");
  const [attachedImages, setAttachedImages] = useState<AttachedImage[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const effectiveModel = settings?.defaultModel ?? DEFAULT_SETTINGS.defaultModel;
  const effectiveSize = settings?.defaultImageSize ?? ImageSize.MEDIUM;
  const effectiveCount = settings?.defaultCount ?? 4;

  const handleModelChange = (value: string) => {
    updateSettings.mutate({ defaultModel: value });
  };

  const handleSizeChange = (value: ImageSize) => {
    updateSettings.mutate({ defaultImageSize: value });
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
      imageSize: effectiveSize,
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
          disabled={modelsLoading}
          className="rounded-md border bg-background px-2 py-1 text-xs outline-none focus:ring-1 focus:ring-ring disabled:opacity-50"
        >
          {modelsLoading ? (
            <option>Loading models...</option>
          ) : models && models.length > 0 ? (
            models.map((m) => (
              <option key={m.id} value={m.id}>
                {m.displayName}
              </option>
            ))
          ) : (
            <option value={effectiveModel}>{effectiveModel}</option>
          )}
        </select>

        <select
          value={effectiveSize}
          onChange={(e) => handleSizeChange(e.target.value as ImageSize)}
          className="rounded-md border bg-background px-2 py-1 text-xs outline-none focus:ring-1 focus:ring-ring"
        >
          {Object.entries(IMAGE_SIZE_LABELS).map(([value, label]) => (
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
