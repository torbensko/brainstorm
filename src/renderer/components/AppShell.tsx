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

  return (
    <div className="flex h-screen overflow-hidden">
      {view.kind !== "settings" && (
        <Sidebar
          selectedId={selectedConversation}
          onSelect={(id) => {
            setSelectedConversation(id);
            setView({ kind: "chat" });
          }}
          onNew={() => {
            setSelectedConversation(null);
            setView({ kind: "chat" });
          }}
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
        ) : (
          <NewConversationView onCreated={setSelectedConversation} />
        )}
      </main>
    </div>
  );
}
