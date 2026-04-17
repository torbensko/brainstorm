import { useState, useEffect } from "react";
import { ArrowLeft, Eye, EyeOff, RefreshCw } from "lucide-react";
import { useSettings, useUpdateSettings } from "@/renderer/hooks/useSettings";
import { useImageModels } from "@/renderer/hooks/useGemini";
import { ImageSize, IMAGE_SIZE_LABELS, DEFAULT_SETTINGS } from "@/shared/types";
import { useQueryClient } from "@tanstack/react-query";

interface SettingsViewProps {
  readonly onBack: () => void;
}

export function SettingsView({ onBack }: SettingsViewProps) {
  const { data: settings } = useSettings();
  const updateSettings = useUpdateSettings();
  const { data: models, isLoading: modelsLoading, error: modelsError } = useImageModels();
  const queryClient = useQueryClient();

  const [apiKey, setApiKey] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [model, setModel] = useState(DEFAULT_SETTINGS.defaultModel);
  const [imageSize, setImageSize] = useState<ImageSize>(ImageSize.MEDIUM);
  const [count, setCount] = useState(4);

  useEffect(() => {
    if (settings) {
      setApiKey(settings.geminiApiKey);
      setModel(settings.defaultModel);
      setImageSize(settings.defaultImageSize);
      setCount(settings.defaultCount);
    }
  }, [settings]);

  const handleSave = () => {
    updateSettings.mutate({
      geminiApiKey: apiKey,
      defaultModel: model,
      defaultImageSize: imageSize,
      defaultCount: count,
    });
  };

  const handleRefreshModels = () => {
    queryClient.invalidateQueries({ queryKey: ["gemini-models"] });
  };

  return (
    <div className="flex h-full flex-col">
      <div className="app-draggable flex h-12 items-center gap-3 border-b px-4">
        <button
          onClick={onBack}
          className="app-no-drag rounded-md p-1 text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <h2 className="text-sm font-semibold">Settings</h2>
      </div>

      <div className="flex-1 overflow-y-auto p-6">
        <div className="mx-auto max-w-lg space-y-6">
          {/* API Key */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Gemini API Key</label>
            <div className="flex gap-2">
              <input
                type={showKey ? "text" : "password"}
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="Enter your Gemini API key..."
                className="flex-1 rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
              />
              <button
                onClick={() => setShowKey(!showKey)}
                className="rounded-md border px-3 py-2 text-muted-foreground hover:text-foreground"
              >
                {showKey ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
              </button>
            </div>
            <p className="text-xs text-muted-foreground">
              Get your API key from{" "}
              <span className="font-medium">aistudio.google.com</span>
            </p>
          </div>

          {/* Default Model */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium">Default Model</label>
              <button
                onClick={handleRefreshModels}
                disabled={modelsLoading}
                className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground disabled:opacity-50"
                title="Refresh model list from Google"
              >
                <RefreshCw
                  className={`h-3 w-3 ${modelsLoading ? "animate-spin" : ""}`}
                />
                Refresh
              </button>
            </div>
            <select
              value={model}
              onChange={(e) => setModel(e.target.value)}
              disabled={modelsLoading}
              className="w-full rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring disabled:opacity-50"
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
                <option value={model}>{model}</option>
              )}
            </select>
            {modelsError && (
              <p className="text-xs text-destructive">
                Failed to load models. Save your API key first, then refresh.
              </p>
            )}
            {models && models.length > 0 && (
              <p className="text-xs text-muted-foreground">
                {models.length} image-capable model
                {models.length !== 1 ? "s" : ""} available
              </p>
            )}
          </div>

          {/* Default Image Size */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Default Image Size</label>
            <select
              value={imageSize}
              onChange={(e) => setImageSize(e.target.value as ImageSize)}
              className="w-full rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
            >
              {Object.entries(IMAGE_SIZE_LABELS).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>

          {/* Default Count */}
          <div className="space-y-2">
            <label className="text-sm font-medium">
              Default Number of Images
            </label>
            <input
              type="number"
              min={1}
              max={8}
              value={count}
              onChange={(e) => setCount(parseInt(e.target.value, 10))}
              className="w-full rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
            />
          </div>

          {/* Save button */}
          <button
            onClick={handleSave}
            disabled={updateSettings.isPending}
            className="rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-50"
          >
            {updateSettings.isPending ? "Saving..." : "Save Settings"}
          </button>
          {updateSettings.isSuccess && (
            <p className="text-sm text-green-600">Settings saved!</p>
          )}
        </div>
      </div>
    </div>
  );
}
