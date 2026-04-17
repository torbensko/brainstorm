import { Plus, Trash2, MessageSquare, Settings } from "lucide-react";
import { cn } from "@/renderer/lib/utils";
import type { ConversationSummary } from "@/shared/types";
import {
  useConversationList,
  useCreateConversation,
  useDeleteConversation,
} from "@/renderer/hooks/useConversations";

interface SidebarProps {
  readonly selectedId: string | null;
  readonly onSelect: (id: string) => void;
  readonly onShowSettings: () => void;
}

export function Sidebar({ selectedId, onSelect, onShowSettings }: SidebarProps) {
  const { data: conversations = [] } = useConversationList();
  const createConversation = useCreateConversation();
  const deleteConversation = useDeleteConversation();

  const handleNew = async () => {
    const conv = await createConversation.mutateAsync("New Conversation");
    onSelect(conv.id);
  };

  const handleDelete = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    deleteConversation.mutate(id);
  };

  return (
    <aside className="flex h-full w-64 flex-col border-r border-sidebar-border bg-sidebar text-sidebar-foreground">
      {/* Draggable title bar region */}
      <div className="app-draggable flex h-12 items-center px-4 pt-1">
        <h1 className="text-sm font-semibold">Brainstorm</h1>
      </div>

      {/* New conversation button */}
      <div className="px-3 pb-2">
        <button
          onClick={handleNew}
          className="app-no-drag flex w-full items-center gap-2 rounded-md bg-primary px-3 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <Plus className="h-4 w-4" />
          New Conversation
        </button>
      </div>

      {/* Conversation list */}
      <div className="flex-1 overflow-y-auto px-3">
        {conversations.map((conv: ConversationSummary) => (
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
      </div>

      {/* Settings button */}
      <div className="border-t border-sidebar-border p-3">
        <button
          onClick={onShowSettings}
          className="app-no-drag flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
        >
          <Settings className="h-4 w-4" />
          Settings
        </button>
      </div>
    </aside>
  );
}
