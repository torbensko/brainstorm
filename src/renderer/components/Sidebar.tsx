import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { Plus, Trash2, MessageSquare, Settings, Search } from "lucide-react";
import { cn } from "@/renderer/lib/utils";
import type { ConversationSummary } from "@/shared/types";
import {
  useConversationList,
  useDeleteConversation,
} from "@/renderer/hooks/useConversations";

interface SidebarProps {
  readonly selectedId: string | null;
  readonly onSelect: (id: string) => void;
  readonly onNew: () => void;
  readonly onDelete: (id: string) => void;
  readonly onShowSettings: () => void;
}

export function Sidebar({
  selectedId,
  onSelect,
  onNew,
  onDelete,
  onShowSettings,
}: SidebarProps) {
  const { data: conversations = [] } = useConversationList();
  const deleteConversation = useDeleteConversation();
  const [search, setSearch] = useState("");

  const { data: version } = useQuery({
    queryKey: ["app-version"],
    queryFn: () => window.electronAPI.getVersion() as Promise<string>,
    staleTime: Infinity,
  });

  const filtered = useMemo(() => {
    if (!search.trim()) return conversations;
    const q = search.toLowerCase();
    return conversations.filter((c: ConversationSummary) =>
      c.title.toLowerCase().includes(q)
    );
  }, [conversations, search]);

  const handleDelete = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    deleteConversation.mutate(id);
    onDelete(id);
  };

  return (
    <aside className="flex h-full w-64 flex-col border-r border-sidebar-border bg-sidebar text-sidebar-foreground">
      {/* Draggable region for traffic lights — empty space above title */}
      <div className="app-draggable h-10 shrink-0" />

      {/* Title row: name + version on left, settings gear on right */}
      <div className="flex items-center justify-between px-4 pb-1">
        <div>
          <h1 className="text-sm font-bold leading-tight">Brainstorm</h1>
          {version && (
            <span className="text-[11px] text-muted-foreground">
              v{version}
            </span>
          )}
        </div>
        <button
          onClick={onShowSettings}
          className="app-no-drag rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
          title="Settings"
        >
          <Settings className="h-4 w-4" />
        </button>
      </div>

      {/* Search */}
      <div className="px-3 py-2">
        <div className="flex items-center gap-2 rounded-md border bg-background px-2.5 py-1.5">
          <Search className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search chats..."
            className="w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
          />
        </div>
      </div>

      {/* New conversation button */}
      <div className="px-3 pb-2">
        <button
          onClick={onNew}
          className="app-no-drag flex w-full items-center gap-2 rounded-md bg-primary px-3 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <Plus className="h-4 w-4" />
          New Conversation
        </button>
      </div>

      {/* Conversation list */}
      <div className="flex-1 overflow-y-auto px-3">
        {filtered.map((conv: ConversationSummary) => (
          <button
            key={conv.id}
            onClick={() => onSelect(conv.id)}
            className={cn(
              "app-no-drag group flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm transition-colors",
              selectedId === conv.id
                ? "bg-sidebar-accent text-sidebar-accent-foreground"
                : "hover:bg-sidebar-accent/50"
            )}
          >
            <MessageSquare className="h-4 w-4 shrink-0" />
            <span className="truncate flex-1">{conv.title}</span>
            <button
              onClick={(e) => handleDelete(e, conv.id)}
              className="invisible shrink-0 rounded p-1 text-muted-foreground hover:text-destructive group-hover:visible"
            >
              <Trash2 className="h-3 w-3" />
            </button>
          </button>
        ))}
        {search && filtered.length === 0 && (
          <p className="px-3 py-4 text-center text-xs text-muted-foreground">
            No matching conversations
          </p>
        )}
      </div>
    </aside>
  );
}
