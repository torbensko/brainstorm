import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { SquarePen, Trash2, Settings, Search } from "lucide-react";
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
    <aside className="flex h-full w-72 shrink-0 flex-col bg-sidebar text-sidebar-foreground">
      {/* Draggable region for traffic lights */}
      <div className="app-draggable h-10 shrink-0" />

      {/* Title row */}
      <div className="flex items-center justify-between px-5 pb-2">
        <div>
          <h1 className="text-sm font-semibold leading-tight tracking-tight">
            Brainstorm
          </h1>
          {version && (
            <span className="text-[11px] text-muted-foreground">
              v{version}
            </span>
          )}
        </div>
        <button
          onClick={onShowSettings}
          className="app-no-drag rounded-full p-2 text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
          title="Settings"
        >
          <Settings className="h-4 w-4" />
        </button>
      </div>

      {/* New chat */}
      <div className="px-3 pt-2">
        <button
          onClick={onNew}
          className="app-no-drag flex w-full items-center gap-3 rounded-full px-4 py-2.5 text-sm font-medium text-sidebar-foreground transition-colors hover:bg-sidebar-accent"
        >
          <SquarePen className="h-4 w-4" strokeWidth={2} />
          New chat
        </button>
      </div>

      {/* Search */}
      <div className="px-3 py-2">
        <div className="flex items-center gap-2 rounded-full px-4 py-2 text-sm text-muted-foreground transition-colors hover:bg-sidebar-accent/70 focus-within:bg-sidebar-accent/70">
          <Search className="h-4 w-4 shrink-0" strokeWidth={2} />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search chats"
            className="w-full bg-transparent text-sm text-sidebar-foreground outline-none placeholder:text-muted-foreground"
          />
        </div>
      </div>

      {/* Conversation list */}
      <div className="mt-2 flex-1 overflow-y-auto px-3 pb-3">
        {filtered.length > 0 && (
          <p className="px-4 pb-1 pt-2 text-[11px] font-medium uppercase tracking-wider text-muted-foreground">
            Chats
          </p>
        )}
        {filtered.map((conv: ConversationSummary) => (
          <button
            key={conv.id}
            onClick={() => onSelect(conv.id)}
            className={cn(
              "app-no-drag group flex w-full items-center gap-2 rounded-full px-4 py-2 text-left text-sm transition-colors",
              selectedId === conv.id
                ? "bg-sidebar-accent text-sidebar-accent-foreground"
                : "text-sidebar-foreground hover:bg-sidebar-accent/60"
            )}
          >
            <span className="truncate flex-1">{conv.title}</span>
            <button
              onClick={(e) => handleDelete(e, conv.id)}
              className="invisible shrink-0 rounded-full p-1 text-muted-foreground hover:text-destructive group-hover:visible"
              title="Delete"
            >
              <Trash2 className="h-3.5 w-3.5" />
            </button>
          </button>
        ))}
        {search && filtered.length === 0 && (
          <p className="px-4 py-4 text-center text-xs text-muted-foreground">
            No matching conversations
          </p>
        )}
      </div>
    </aside>
  );
}
