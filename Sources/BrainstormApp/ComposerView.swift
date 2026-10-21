import SwiftUI
import BrainstormCore

struct ComposerView: View {
    @ObservedObject var model: WorkspaceModel
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
                PromptEditor(text: $model.prompt, placeholder: placeholder, focusID: model.parentAssetID,
                             onAttachments: { attachments in Task { await model.importAttachments(attachments) } },
                             onError: { model.errorMessage = $0.localizedDescription },
                             onSubmit: { Task { await model.generate() } })
                    .overlay(alignment: .topLeading) {
                        if model.prompt.isEmpty {
                            Text(placeholder).font(.system(size: 15)).foregroundStyle(.placeholder)
                                .padding(.top, 3).allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 3)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { controlMenus; Spacer(minLength: 8); generateButton }
                    VStack(alignment: .leading, spacing: 12) {
                        ComposerPillLayout { controlMenus }
                        HStack { Spacer(); generateButton }
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            HStack {
                if model.isImporting {
                    ProgressView().controlSize(.mini)
                    Text("Adding images…")
                } else {
                    Text(model.isDemo ? "Demo · local sample artwork" : model.settings.provider == .chatGPT
                         ? "Uses your ChatGPT subscription" : "Uses separately billed \(model.settings.provider.title) access")
                }
                Spacer()
                if !model.prompt.isEmpty { refineButton }
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 8)
        }
        .padding(.horizontal, 28).padding(.top, 14).padding(.bottom, 18)
        .disabled(model.isLoading)
    }
    private var placeholder: String {
        model.parentAssetID == nil ? "Describe the idea you want to explore…" : "What would you like to change?"
    }
    @ViewBuilder private var controlMenus: some View {
        Menu {
            Button("Choose images…") { model.showFileImporter = true }
            Button("Paste image") { Task { await model.pasteImage() } }
        } label: {
            Image(systemName: "paperclip").font(.system(size: 17)).frame(width: 26, height: 32)
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Attach reference images")
        Menu {
            ForEach(ProviderID.allCases) { provider in
                Section(provider.title) {
                    ForEach(provider.models) { imageModel in
                        Button {
                            model.settings = GenerationSettings(provider: provider, model: imageModel.id, shape: model.settings.shape, quality: model.settings.quality)
                        } label: {
                            if model.settings.provider == provider && model.settings.model == imageModel.id { Label(imageModel.title, systemImage: "checkmark") }
                            else { Text(imageModel.title) }
                        }
                    }
                }
            }
        } label: {
            Label(model.settings.provider == .chatGPT ? modelTitle : "Model: \(modelTitle)", systemImage: "sparkles")
        }.studioMenu().help("Choose a service and model")
        Menu {
            Picker("Shape", selection: $model.settings.shape) {
                ForEach(ImageShape.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.inline)
        } label: {
            Label("Shape: \(model.settings.shape.title)", systemImage: "aspectratio")
        }.studioMenu()
        if model.settings.provider != .chatGPT {
            Menu {
                Picker("Quality", selection: $model.settings.quality) {
                    ForEach(ImageQuality.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.inline)
            } label: {
                Label("Quality: \(model.settings.quality.title)", systemImage: "slider.horizontal.3")
            }.studioMenu()
        }
        Menu {
            Picker("Images", selection: $model.count) {
                ForEach(1...16, id: \.self) { Text("\($0) image\($0 == 1 ? "" : "s")").tag($0) }
            }.pickerStyle(.inline)
        } label: {
            Label("\(model.count) image\(model.count == 1 ? "" : "s")", systemImage: "square.stack")
        }.studioMenu()
    }
    private var modelTitle: String {
        if model.settings.provider == .chatGPT { return "ChatGPT" }
        return (model.settings.provider.models.first { $0.id == model.settings.model }?.title ?? model.settings.model)
            .replacingOccurrences(of: "GPT Image 2.5 · ", with: "")
    }
    private var refineButton: some View {
        Button { model.showRefinePrompt = true } label: { Label("Refine wording", systemImage: "pencil.and.outline") }
            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
            .disabled(model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    private var generateButton: some View {
        Button { Task { await model.generate() } } label: {
            HStack(spacing: 7) {
                if model.isSubmitting { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.up") }
                Text(model.parentAssetID == nil ? "Explore" : "Refine").fontWeight(.medium)
            }.padding(.horizontal, 5).padding(.vertical, 3)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
        .keyboardShortcut(.return, modifiers: .command).disabled(!model.canGenerate)
        .help("Generate images · ⌘ Return")
    }
}

/// Keep every setting reachable when the composer is narrower than one row of pills.
private struct ComposerPillLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let origin = layout.origins[index]
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                          anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + 8; rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + 8
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), origins)
    }
}

private struct ComposerPillSurface: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11).frame(height: 32)
            .background(hovering ? Color.primary.opacity(0.05) : Color(nsColor: .controlBackgroundColor), in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .contentShape(Capsule()).onHover { hovering = $0 }
    }
}

private extension View {
    func studioMenu() -> some View {
        menuStyle(.borderlessButton).menuIndicator(.visible).fixedSize()
            .font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
            .modifier(ComposerPillSurface())
    }
}
