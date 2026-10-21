import SwiftUI
import BrainstormCore

struct SettingsView: View {
    @ObservedObject var model: WorkspaceModel
    @State private var provider = ProviderID.openAI
    @State private var key = ""
    @State private var message: String?
    @State private var saving = false
    var body: some View {
        Form {
            Section {
                Text("Your studio, your services.").font(.system(size: 24, weight: .medium, design: .serif)).padding(.vertical, 4)
                Text("Images and prompts are saved on this Mac. Generation uses your own API account.")
                    .foregroundStyle(.secondary)
            }
            Section("Service accounts") {
                Picker("Provider", selection: $provider) {
                    ForEach(ProviderID.allCases) { provider in Text(provider.title).tag(provider) }
                }
                HStack {
                    Label(model.hasKeys.contains(provider) ? "API key saved in Keychain" : "No API key saved", systemImage: model.hasKeys.contains(provider) ? "checkmark.shield" : "key")
                        .foregroundStyle(model.hasKeys.contains(provider) ? StudioStyle.accent : .secondary)
                    Spacer()
                    Link("Get an API key ↗", destination: URL(string: provider == .openAI ? "https://platform.openai.com/api-keys" : "https://aistudio.google.com/apikey")!)
                }
                SecureField(model.hasKeys.contains(provider) ? "Replace API key" : "API key", text: $key)
                HStack {
                    Button("Save Key") {
                        saving = true; message = nil
                        let selected = provider; let value = key
                        Task {
                            do {
                                try await model.keychain.save(value, for: selected)
                                key = ""; message = "Saved securely in Keychain."
                                await model.refreshKeys()
                            } catch { message = error.localizedDescription }
                            saving = false
                        }
                    }.disabled(key.isEmpty || saving || model.isDemo)
                    if model.hasKeys.contains(provider) && !model.isDemo {
                        Button("Remove Key", role: .destructive) {
                            Task {
                                do { try await model.keychain.remove(for: provider); await model.refreshKeys(); message = "Key removed." }
                                catch { message = error.localizedDescription }
                            }
                        }
                    }
                    Spacer()
                }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                if provider == .openAI {
                    Text("API image generation is billed separately from your ChatGPT subscription.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Generation") {
                Stepper("Concurrent requests: \(model.concurrency)", value: $model.concurrency, in: 1...6)
                Text("Larger sets wait in the queue. Reduce this if your account frequently reaches a rate limit.").font(.caption).foregroundStyle(.secondary)
                Text("Interrupted requests stay available for manual retry. Cancelling stops this app’s request; a provider may already have started processing it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Library") {
                LabeledContent("Location", value: "Application Support / Brainstorm Native")
                Button("Show Library Folder") { model.revealLibrary() }
                Text("Back up this folder to preserve concepts, references, and original images. API keys remain in Keychain.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).frame(width: 580, height: 620)
        .onChange(of: provider) { _, _ in key = ""; message = nil }
        .task { await model.refreshKeys() }
    }
}
