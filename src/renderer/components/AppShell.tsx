import { useState } from "react";
import { Sidebar } from "./Sidebar";
import { ChatView } from "./ChatView";
import { SettingsView } from "./SettingsView";
import { NewConversationView } from "./NewConversationView";

type View = { kind: "chat" } | { kind: "settings" };

export function AppShell() {
  const [selectedConversation, setSelectedConversation] = useState<
    string | null
  >(null);
  const [view, setView] = useState<View>({ kind: "chat" });
  const [drafting, setDrafting] = useState(false);

  const handleNewConversation = () => {
    setSelectedConversation(null);
    setDrafting(true);
    setView({ kind: "chat" });
  };

  const handleConversationCreated = (id: string) => {
    setSelectedConversation(id);
    setDrafting(false);
  };

  return (
    <div className="flex h-screen overflow-hidden">
      {view.kind !== "settings" && (
        <Sidebar
          selectedId={selectedConversation}
          onSelect={(id) => {
            setSelectedConversation(id);
            setDrafting(false);
            setView({ kind: "chat" });
          }}
          onNew={handleNewConversation}
          onDelete={(id) => {
            if (selectedConversation === id) {
              setSelectedConversation(null);
            }
          }}
          onShowSettings={() => setView({ kind: "settings" })}
        />
      )}

      <main className="flex-1">
        {view.kind === "settings" ? (
          <SettingsView onBack={() => setView({ kind: "chat" })} />
        ) : selectedConversation ? (
          <ChatView conversationId={selectedConversation} />
        ) : drafting ? (
          <NewConversationView onCreated={handleConversationCreated} />
        ) : (
          <div className="flex h-full flex-col">
            <div className="app-draggable h-12 border-b" />
            <div className="flex flex-1 items-center justify-center">
              <div className="text-center">
                <h2 className="mb-2 text-2xl font-semibold">
                  Welcome to Brainstorm
                </h2>
                <p className="text-muted-foreground">
                  Create a new conversation to start generating images
                </p>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
