import SwiftUI
import BrainstormCore

struct SettingsView: View {
    @ObservedObject var model: WorkspaceModel
    @ObservedObject var updates: AppUpdater
    @State private var provider = ProviderID.chatGPT
    @State private var key = ""
    @State private var message: String?
    @State private var saving = false
    var body: some View {
        Form {
            Section("Service accounts") {
                Picker("Connection", selection: $provider) {
                    ForEach(ProviderID.allCases) { provider in Text(provider.title).tag(provider) }
                }
                if provider == .chatGPT { subscription }
                else { apiAccount }
            }
            Section("Generation") {
                Stepper("Concurrent requests: \(model.concurrency)", value: $model.concurrency, in: 1...6)
                Text("Larger sets wait in the queue. Each image uses its own request, so you can retry individual images.").font(.caption).foregroundStyle(.secondary)
                Text("Interrupted requests stay available for manual retry. Cancelling stops this app’s request; the service may already have started processing it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Library") {
                Button("Show Library Folder") { model.revealLibrary() }
                Text("Conversations, references, and images stay on this Mac. Back up the library folder to keep a copy. API keys stay in Keychain; ChatGPT sign-in is managed by Codex.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates }, set: updates.setAutomaticChecks
                ))
                Toggle("Automatically download and install updates", isOn: Binding(
                    get: { updates.automaticallyDownloadsUpdates }, set: updates.setAutomaticDownloads
                ))
                .disabled(!updates.automaticallyChecksForUpdates)
                HStack {
                    Button("Check for Updates…") { updates.checkForUpdates() }
                        .disabled(!updates.canCheckForUpdates)
                    Spacer()
                    if let date = updates.lastUpdateCheckDate {
                        Text("Last checked \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Downloaded updates install when you quit. You can also check and install an update immediately.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.isDemo)
            Section("About Brainstorm") {
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                   let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    LabeledContent("Version", value: "\(version) (build \(build))")
                }
                if let revision = Bundle.main.object(forInfoDictionaryKey: "BrainstormSourceRevision") as? String {
                    LabeledContent("Source revision", value: revision).textSelection(.enabled)
                }
                if let date = Bundle.main.object(forInfoDictionaryKey: "BrainstormBuildDate") as? String {
                    Text("Built \(date)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped).frame(width: 580, height: 620)
        .onChange(of: provider) { _, _ in key = ""; message = nil }
        .task { await model.refreshKeys() }
    }
    private var subscription: some View {
        Group {
            Label(model.hasKeys.contains(.chatGPT) ? "ChatGPT connected" : "Connect your ChatGPT account",
                  systemImage: model.hasKeys.contains(.chatGPT) ? "checkmark.shield" : "person.crop.circle")
                .foregroundStyle(model.hasKeys.contains(.chatGPT) ? StudioStyle.accent : .primary)
            if let status = model.subscriptionStatus, status.connected {
                if let label = status.accountLabel { Text(label).foregroundStyle(.secondary) }
                if let plan = status.plan { Text("\(plan.capitalized) plan").font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                if !model.hasKeys.contains(.chatGPT) {
                    Button(model.signingIn ? "Waiting for sign-in…" : "Sign in with ChatGPT") {
                        Task { await model.signInWithChatGPT() }
                    }.disabled(model.signingIn || model.isDemo)
                }
                Button("Refresh Connection") { Task { await model.refreshSubscription() } }.disabled(model.isDemo)
                Spacer()
                Link("Manage usage ↗", destination: URL(string: "https://chatgpt.com/codex/settings/usage")!)
            }
            if let message = model.subscriptionMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Uses your ChatGPT subscription through the Codex installation on this Mac. Your plan’s usage limits apply. Subscription mode never switches to API billing.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var apiAccount: some View {
        Group {
            HStack {
                Label(model.hasKeys.contains(provider) ? "API key saved in Keychain" : "No API key saved", systemImage: "key")
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
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Optional, separately billed API access. Select this service in the composer only when you want to use API billing.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
