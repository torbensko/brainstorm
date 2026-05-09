import { useState, useRef, useEffect } from "react";
import { ArrowUp, Plus, X, Loader2 } from "lucide-react";
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
  readonly acceptDropAnywhere?: boolean;
}

async function filesToAttachedImages(
  files: FileList | File[]
): Promise<AttachedImage[]> {
  const images: AttachedImage[] = [];
  for (const file of Array.from(files)) {
    if (!file.type.startsWith("image/")) continue;
    const buffer = await file.arrayBuffer();
    const data = btoa(
      new Uint8Array(buffer).reduce(
        (acc, byte) => acc + String.fromCharCode(byte),
        ""
      )
    );
    images.push({ data, mimeType: file.type, name: file.name });
  }
  return images;
}

export function ChatInput({
  onSubmit,
  isGenerating,
  contextImages,
  onRemoveContextImage,
  acceptDropAnywhere,
}: ChatInputProps) {
  const { data: settings } = useSettings();
  const updateSettings = useUpdateSettings();
  const [prompt, setPrompt] = useState("");
  const [attachedImages, setAttachedImages] = useState<AttachedImage[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${el.scrollHeight}px`;
  }, [prompt]);

  useEffect(() => {
    if (!acceptDropAnywhere) return;

    const isFileDrag = (e: DragEvent) =>
      e.dataTransfer?.types?.includes("Files") ?? false;

    const handleDragOver = (e: DragEvent) => {
      if (!isFileDrag(e)) return;
      e.preventDefault();
      if (e.dataTransfer) e.dataTransfer.dropEffect = "copy";
    };

    const handleDrop = async (e: DragEvent) => {
      if (!isFileDrag(e)) return;
      e.preventDefault();
      const files = e.dataTransfer?.files;
      if (!files || files.length === 0) return;
      const newImages = await filesToAttachedImages(files);
      if (newImages.length > 0) {
        setAttachedImages((prev) => [...prev, ...newImages]);
      }
    };

    window.addEventListener("dragover", handleDragOver);
    window.addEventListener("drop", handleDrop);
    return () => {
      window.removeEventListener("dragover", handleDragOver);
      window.removeEventListener("drop", handleDrop);
    };
  }, [acceptDropAnywhere]);

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
    if (value >= 1 && value <= 16) {
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
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;
    const newImages = await filesToAttachedImages(files);
    setAttachedImages((prev) => [...prev, ...newImages]);
    e.target.value = "";
  };

  const removeImage = (index: number) => {
    setAttachedImages((prev) => prev.filter((_, i) => i !== index));
  };

  const canSubmit = prompt.trim().length > 0 && !isGenerating;

  return (
    <div className="px-4 pb-5 pt-2">
      <div className="mx-auto max-w-3xl">
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
                    className="h-16 w-16 rounded-xl border-2 border-ring object-cover"
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

        {/* Attached images preview (lives inside the input card visually) */}
        {attachedImages.length > 0 && (
          <div className="mb-2 flex flex-wrap gap-2 px-2">
            {attachedImages.map((img, i) => (
              <div key={i} className="group relative">
                <img
                  src={`data:${img.mimeType};base64,${img.data}`}
                  alt={img.name}
                  className="h-16 w-16 rounded-xl border object-cover"
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

        {/* Main rounded input card */}
        <div className="input-card flex flex-col gap-2 rounded-[28px] border bg-card px-3 py-2.5 shadow-sm">
          <textarea
            ref={textareaRef}
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Ask Brainstorm to create…"
            rows={1}
            className="max-h-40 min-h-[28px] w-full resize-none overflow-y-auto bg-transparent px-2 py-1 text-[15px] leading-6 outline-none placeholder:text-muted-foreground"
          />

          <div className="flex items-center gap-2">
            <button
              onClick={() => fileInputRef.current?.click()}
              className="shrink-0 rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
              title="Attach image"
            >
              <Plus className="h-5 w-5" />
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              multiple
              onChange={handleFileSelect}
              className="hidden"
            />

            <div className="flex flex-1 flex-wrap items-center gap-1.5">
              <SelectPill
                value={effectiveModel}
                onChange={handleModelChange}
                options={NANO_BANANA_MODELS.map((m: GeminiModelInfo) => ({
                  value: m.id,
                  label: m.displayName,
                }))}
              />
              <SelectPill
                value={effectiveAspectRatio}
                onChange={(v) => handleAspectRatioChange(v as AspectRatio)}
                options={Object.entries(ASPECT_RATIO_LABELS).map(
                  ([value, label]) => ({ value, label })
                )}
              />
              <SelectPill
                value={effectiveResolution}
                onChange={(v) => handleResolutionChange(v as ImageResolution)}
                options={Object.entries(IMAGE_RESOLUTION_LABELS).map(
                  ([value, label]) => ({ value, label })
                )}
              />
              <div className="inline-flex items-center gap-1 rounded-full bg-muted/60 px-3 py-1 text-xs hover:bg-muted">
                <label className="text-muted-foreground">Images</label>
                <input
                  type="number"
                  min={1}
                  max={16}
                  value={effectiveCount}
                  onChange={(e) =>
                    handleCountChange(parseInt(e.target.value, 10))
                  }
                  className="w-8 bg-transparent text-center outline-none"
                />
              </div>
            </div>

            <button
              onClick={handleSubmit}
              disabled={!canSubmit}
              className="shrink-0 rounded-full bg-primary p-2 text-primary-foreground transition-all hover:bg-primary/90 disabled:bg-muted disabled:text-muted-foreground"
              title="Generate images"
            >
              {isGenerating ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <ArrowUp className="h-5 w-5" strokeWidth={2.5} />
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

interface SelectPillProps {
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly options: ReadonlyArray<{ value: string; label: string }>;
}

function SelectPill({ value, onChange, options }: SelectPillProps) {
  return (
    <div className="relative inline-flex items-center rounded-full bg-muted/60 text-xs transition-colors hover:bg-muted">
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="appearance-none bg-transparent px-3 py-1 pr-6 text-xs outline-none"
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
      <span className="pointer-events-none absolute right-2 text-muted-foreground">
        ▾
      </span>
    </div>
  );
}
