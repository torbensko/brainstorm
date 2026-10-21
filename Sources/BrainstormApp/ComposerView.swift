import SwiftUI
import BrainstormCore

struct ComposerView: View {
    @ObservedObject var model: WorkspaceModel
    @FocusState private var promptFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let parent = model.parentAsset {
                HStack(spacing: 10) {
                    AssetImage(url: model.assetURL(parent, thumbnail: true)).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Refining this image").font(.system(size: 12, weight: .semibold))
                        Text("Describe what should change. The original stays in your library.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.clearParent() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).help("Return to exploration")
                }.padding(10).background(StudioStyle.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
            if !model.currentReferences.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(model.currentReferences) { asset in
                            HStack(spacing: 7) {
                                AssetImage(url: model.assetURL(asset, thumbnail: true)).frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 5))
                                Text(asset.name).font(.caption).lineLimit(1).frame(maxWidth: 130)
                                Button { model.removeReference(asset.id) } label: { Image(systemName: "xmark").font(.caption2) }.buttonStyle(.plain)
                            }.padding(5).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            VStack(alignment: .leading, spacing: 14) {
                TextField(model.parentAssetID == nil ? "Describe the idea you want to explore…" : "What would you like to change?", text: $model.prompt, axis: .vertical)
                    .font(.system(size: 15)).lineLimit(3...7).textFieldStyle(.plain).focused($promptFocused)
                    .padding(.horizontal, 3).padding(.top, 3)
                HStack(spacing: 10) {
                    Menu {
                        Button("Choose images…") { model.showFileImporter = true }
                        Button("Paste image") { Task { await model.pasteImage() } }
                    } label: { Label("Attach", systemImage: "paperclip") }
                        .menuStyle(.borderlessButton).fixedSize().help("Attach reference images")
                    Button { model.showRefinePrompt = true } label: { Label("Refine wording", systemImage: "pencil.and.outline") }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                        .disabled(model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                    if model.isImporting { ProgressView().controlSize(.small); Text("Adding images…").font(.caption).foregroundStyle(.secondary) }
                    Text("⌘ Return to generate").font(.caption2).foregroundStyle(.tertiary)
                }
                Divider()
                HStack(spacing: 12) {
                    Menu {
                        ForEach(ProviderID.allCases) { provider in
                            Section(provider.title) {
                                ForEach(provider.models) { imageModel in
                                    Button {
                                        model.settings = GenerationSettings(provider: provider, model: imageModel.id, shape: model.settings.shape, quality: model.settings.quality)
                                    } label: {
                                        if model.settings.model == imageModel.id { Label(imageModel.title, systemImage: "checkmark") }
                                        else { Text(imageModel.title) }
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(model.settings.provider.models.first { $0.id == model.settings.model }?.title ?? model.settings.model)
                            .font(.caption).lineLimit(1)
                    }.menuStyle(.borderlessButton).frame(maxWidth: 215)
                    Picker("Shape", selection: $model.settings.shape) {
                        ForEach(ImageShape.allCases) { shape in Text(shape.title).tag(shape) }
                    }.labelsHidden().frame(width: 115).help("Image shape")
                    Picker("Quality", selection: $model.settings.quality) {
                        ForEach(ImageQuality.allCases) { quality in
                            Text(model.settings.provider == .gemini ? "\(quality.title) · \(quality.geminiSize)" : quality.title).tag(quality)
                        }
                    }.labelsHidden().frame(width: model.settings.provider == .gemini ? 135 : 110).help("Image quality")
                    Stepper(value: $model.count, in: 1...16) { Text("\(model.count) images").font(.caption).monospacedDigit() }.fixedSize()
                    Spacer(minLength: 4)
                    Button { Task { await model.generate() } } label: {
                        HStack(spacing: 8) {
                            if model.isSubmitting { ProgressView().controlSize(.small) }
                            else { Image(systemName: "sparkles") }
                            Text(model.parentAssetID == nil ? "Explore" : "Generate revisions").fontWeight(.semibold)
                        }.padding(.horizontal, 7).padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command).disabled(!model.canGenerate)
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            HStack {
                Text(model.isDemo ? "Demo mode · Sample images are generated locally" : "Uses your \(model.settings.provider.title) API account · \(model.count) separate image requests")
                Spacer()
                Text("Saved on this Mac")
            }.font(.system(size: 10)).foregroundStyle(.tertiary).padding(.horizontal, 4)
        }
        .padding(.horizontal, 28).padding(.top, 14).padding(.bottom, 18)
        .background(.bar)
        .disabled(model.isLoading)
        .onChange(of: model.parentAssetID) { _, new in if new != nil { promptFocused = true } }
    }
}
