import { useState, useEffect } from "react";
import { ArrowLeft, Eye, EyeOff, FolderOpen } from "lucide-react";
import { useSettings, useUpdateSettings, usePickFolder } from "@/renderer/hooks/useSettings";
import {
  AspectRatio,
  ASPECT_RATIO_LABELS,
  ImageResolution,
  IMAGE_RESOLUTION_LABELS,
  NANO_BANANA_MODELS,
  DEFAULT_SETTINGS,
  type GeminiModelInfo,
} from "@/shared/types";

interface SettingsViewProps {
  readonly onBack: () => void;
}

export function SettingsView({ onBack }: SettingsViewProps) {
  const { data: settings } = useSettings();
  const updateSettings = useUpdateSettings();
  const pickFolder = usePickFolder();

  const [apiKey, setApiKey] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [model, setModel] = useState(DEFAULT_SETTINGS.defaultModel);
  const [aspectRatio, setAspectRatio] = useState<AspectRatio>(
    DEFAULT_SETTINGS.defaultAspectRatio
  );
  const [resolution, setResolution] = useState<ImageResolution>(
    DEFAULT_SETTINGS.defaultImageResolution
  );
  const [count, setCount] = useState(4);
  const [downloadFolder, setDownloadFolder] = useState(
    DEFAULT_SETTINGS.downloadFolder
  );

  useEffect(() => {
    if (settings) {
      setApiKey(settings.geminiApiKey);
      setModel(settings.defaultModel);
      setAspectRatio(settings.defaultAspectRatio);
      setResolution(settings.defaultImageResolution);
      setCount(settings.defaultCount);
      setDownloadFolder(settings.downloadFolder);
    }
  }, [settings]);

  const handlePickFolder = () => {
    pickFolder.mutate(undefined, {
      onSuccess: (folder) => {
        if (folder) setDownloadFolder(folder);
      },
    });
  };

  const handleSave = () => {
    updateSettings.mutate({
      geminiApiKey: apiKey,
      defaultModel: model,
      defaultAspectRatio: aspectRatio,
      defaultImageResolution: resolution,
      defaultCount: count,
      downloadFolder,
    });
  };

  return (
    <div className="flex h-full flex-col">
      <div className="app-draggable flex h-12 items-center gap-3 border-b pl-20 pr-4">
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
            <label className="text-sm font-medium">Default Model</label>
            <select
              value={model}
              onChange={(e) => setModel(e.target.value)}
              className="w-full rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
            >
              {NANO_BANANA_MODELS.map((m: GeminiModelInfo) => (
                <option key={m.id} value={m.id}>
                  {m.displayName}
                </option>
              ))}
            </select>
          </div>

          {/* Default Aspect Ratio */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Default Aspect Ratio</label>
            <select
              value={aspectRatio}
              onChange={(e) =>
                setAspectRatio(e.target.value as AspectRatio)
              }
              className="w-full rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
            >
              {Object.entries(ASPECT_RATIO_LABELS).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>

          {/* Default Resolution */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Default Resolution</label>
            <select
              value={resolution}
              onChange={(e) =>
                setResolution(e.target.value as ImageResolution)
              }
              className="w-full rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
            >
              {Object.entries(IMAGE_RESOLUTION_LABELS).map(
                ([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                )
              )}
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

          {/* Download Folder */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Download Folder</label>
            <div className="flex gap-2">
              <input
                type="text"
                value={downloadFolder}
                onChange={(e) => setDownloadFolder(e.target.value)}
                placeholder="~/Downloads"
                className="flex-1 rounded-md border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring"
              />
              <button
                onClick={handlePickFolder}
                disabled={pickFolder.isPending}
                className="rounded-md border px-3 py-2 text-muted-foreground hover:text-foreground"
              >
                <FolderOpen className="h-4 w-4" />
              </button>
            </div>
            <p className="text-xs text-muted-foreground">
              Images will be saved directly to this folder
            </p>
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
