import type {
  Conversation,
  ConversationSummary,
  Message,
} from "@/shared/types";
import { randomUUID } from "crypto";

let storeInstance: import("electron-store").default | null = null;

async function getStore(): Promise<import("electron-store").default> {
  if (storeInstance) return storeInstance;
  const { default: Store } = await import("electron-store");
  storeInstance = new Store({
    name: "conversations",
    defaults: { conversations: {} as Record<string, Conversation> },
  });
  return storeInstance;
}

function getAllConversations(
  store: import("electron-store").default
): Record<string, Conversation> {
  return store.get("conversations", {}) as Record<string, Conversation>;
}

export async function listConversations(): Promise<ConversationSummary[]> {
  const store = await getStore();
  const all = getAllConversations(store);
  return Object.values(all)
    .map(({ id, title, createdAt, updatedAt }) => ({
      id,
      title,
      createdAt,
      updatedAt,
    }))
    .sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
    );
}

export async function getConversation(
  id: string
): Promise<Conversation | null> {
  const store = await getStore();
  const all = getAllConversations(store);
  return all[id] ?? null;
}

export async function createConversation(
  title: string
): Promise<Conversation> {
  const store = await getStore();
  const all = getAllConversations(store);
  const now = new Date().toISOString();
  const conversation: Conversation = {
    id: randomUUID(),
    title,
    createdAt: now,
    updatedAt: now,
    messages: [],
  };
  all[conversation.id] = conversation;
  store.set("conversations", all);
  return conversation;
}

export async function deleteConversation(id: string): Promise<void> {
  const store = await getStore();
  const all = getAllConversations(store);
  delete all[id];
  store.set("conversations", all);
}

export async function updateConversationTitle(
  id: string,
  title: string
): Promise<Conversation | null> {
  const store = await getStore();
  const all = getAllConversations(store);
  const conv = all[id];
  if (!conv) return null;
  const updated = { ...conv, title, updatedAt: new Date().toISOString() };
  all[id] = updated;
  store.set("conversations", all);
  return updated;
}

export async function addMessage(
  conversationId: string,
  message: Message
): Promise<Conversation | null> {
  const store = await getStore();
  const all = getAllConversations(store);
  const conv = all[conversationId];
  if (!conv) return null;
  const updated: Conversation = {
    ...conv,
    updatedAt: new Date().toISOString(),
    messages: [...conv.messages, message],
  };
  all[conversationId] = updated;
  store.set("conversations", all);
  return updated;
}

export async function updateMessage(
  conversationId: string,
  messageId: string,
  updater: (msg: Message) => Message
): Promise<void> {
  const store = await getStore();
  const all = getAllConversations(store);
  const conv = all[conversationId];
  if (!conv) return;
  const updated: Conversation = {
    ...conv,
    messages: conv.messages.map((m) => (m.id === messageId ? updater(m) : m)),
  };
  all[conversationId] = updated;
  store.set("conversations", all);
}
