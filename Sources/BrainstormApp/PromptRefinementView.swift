import SwiftUI
import BrainstormCore

struct PromptRefinementView: View {
    @ObservedObject var model: WorkspaceModel
    let original: String
    let references: [Asset]
    let provider: ProviderID
    @State private var direction = "Make the wording clearer and more specific while preserving the idea."
    @State private var proposal: String
    @State private var working = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    init(model: WorkspaceModel, original: String, references: [Asset], provider: ProviderID) {
        self.model = model; self.original = original; self.references = references; self.provider = provider
        _proposal = State(initialValue: original)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Give the idea another angle.").font(.system(size: 26, weight: .medium, design: .serif))
                    Text("Refine the wording, then start a fresh concept. Your current exploration stays as it is.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("CURRENT BRIEF").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                    ScrollView { Text(original).font(.system(size: 13)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(height: 170)
                    Text("What should change?").font(.headline)
                    TextField("Make it more concise, explore a new style…", text: $direction, axis: .vertical)
                        .lineLimit(3...5).textFieldStyle(.roundedBorder)
                    Button {
                        working = true; error = nil
                        let brief = proposal
                        task = Task {
                            do {
                                let result = try await model.refinePrompt(brief, direction: direction, referenceAssets: references, providerID: provider)
                                try Task.checkCancellation()
                                proposal = result
                            } catch is CancellationError { /* Dismissed by the user. */ }
                            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
                            working = false
                        }
                    } label: {
                        HStack { if working { ProgressView().controlSize(.small) }; Text(working ? "Refining…" : "Refine with \(provider.title)") }
                    }.disabled(working || direction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Text request only · no images are generated").font(.caption2).foregroundStyle(.tertiary)
                }.frame(width: 300)
                VStack(alignment: .leading, spacing: 12) {
                    Text("NEW BRIEF · EDITABLE").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(StudioStyle.accent)
                    TextEditor(text: $proposal).font(.system(size: 14)).scrollContentBackground(.hidden)
                        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        .frame(minHeight: 330).disabled(working)
                    Text("\(references.count) reference image\(references.count == 1 ? "" : "s") will be copied to the new concept.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            Divider()
            HStack {
                Button("Cancel") { task?.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Start New Concept") {
                    Task { await model.createProject(prompt: proposal, references: references); dismiss() }
                }
                .buttonStyle(.borderedProminent).disabled(working || model.isSubmitting || proposal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28).frame(width: 830, height: 590).tint(StudioStyle.accent)
        .onDisappear { task?.cancel() }
    }
}
