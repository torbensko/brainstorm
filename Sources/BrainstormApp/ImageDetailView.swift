import SwiftUI
import BrainstormCore

struct ImageDetailView: View {
    @ObservedObject var model: WorkspaceModel
    let asset: Asset
    @Environment(\.dismiss) private var dismiss
    @State private var zoom = 1.0
    private var batch: GenerationBatch? { model.batches.first { $0.jobs.contains { $0.assetID == asset.id } } }
    private var family: [Asset] {
        let root = rootID(asset.id)
        return model.batches.filter { $0.projectID == asset.projectID }.flatMap(\.jobs).compactMap(\.assetID)
            .filter { rootID($0) == root }.compactMap { model.assets[$0] }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A closer look").font(.headline)
                    Text("\(asset.width) × \(asset.height) · \(batch?.settings.provider == .chatGPT ? "ChatGPT subscription" : (batch?.settings.model ?? "Reference image"))").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
            }.padding(20)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                AssetImage(url: model.assetURL(asset)).frame(width: 850 * zoom, height: 530 * zoom).padding(10)
            }.frame(width: 880, height: 550).background(.black.opacity(0.04))
            if family.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        Text("REVISIONS").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                        ForEach(family) { relative in
                            Button { model.selectedAssetID = relative.id } label: {
                                AssetImage(url: model.assetURL(relative, thumbnail: true)).frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(relative.id == asset.id ? StudioStyle.accent : .clear, lineWidth: 2))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 10)
                }
            }
            if let batch { Text(batch.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled).padding(.horizontal, 20).padding(.top, 10) }
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $zoom, in: 1...3).frame(width: 100)
                Button("Open in Preview") { if let url = model.assetURL(asset) { NSWorkspace.shared.open(url) } }
                Spacer()
                Button("Copy") { model.copyImage(asset) }
                Button("Export…") { model.export(asset) }
                Button("Refine This Image") { model.refine(asset); dismiss() }.buttonStyle(.borderedProminent)
            }.padding(20)
        }.frame(width: 880).tint(StudioStyle.accent)
    }
    private func rootID(_ id: UUID) -> UUID {
        var current = id
        var visited: Set<UUID> = []
        while visited.insert(current).inserted,
              let parent = model.batches.first(where: { $0.jobs.contains { $0.assetID == current } })?.parentAssetID {
            current = parent
        }
        return current
    }
}
