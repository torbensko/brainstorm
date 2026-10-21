import SwiftUI
import BrainstormCore
import UniformTypeIdentifiers

enum StudioStyle {
    static let accent = Color(red: 0.20, green: 0.39, blue: 0.32)
    static let canvas = Color(nsColor: .textBackgroundColor)
}

struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceModel
    @State private var dropTarget = false

    var body: some View {
        Group {
            if let fatal = model.fatalError {
                ContentUnavailableView {
                    Label("Couldn’t open your library", systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text(fatal) } actions: {
                    Button("Show Library Folder") { model.revealLibrary() }
                }
            } else {
                NavigationSplitView {
                    SidebarView(model: model)
                        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
                } detail: {
                    VStack(spacing: 0) {
                        if model.isDemo {
                            HStack {
                                Image(systemName: "play.rectangle")
                                Text("Demo workspace").fontWeight(.medium)
                                Text("Sample artwork · no API requests")
                                Spacer()
                            }
                            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 28).padding(.vertical, 9)
                            .background(.yellow.opacity(0.12))
                        }
                        GalleryView(model: model)
                        ComposerView(model: model)
                    }
                    .background(StudioStyle.canvas)
                    .overlay {
                        if dropTarget {
                            RoundedRectangle(cornerRadius: 16).fill(StudioStyle.accent.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudioStyle.accent, style: StrokeStyle(lineWidth: 3, dash: [8])))
                                .overlay(Label("Add reference images", systemImage: "photo.badge.plus").font(.title2).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)))
                                .padding(12).allowsHitTesting(false)
                        }
                    }
                    .dropDestination(for: URL.self) { urls, _ in
                        guard !urls.isEmpty else { return false }
                        Task { await model.importFiles(urls) }; return true
                    } isTargeted: { dropTarget = $0 }
                    .navigationTitle(model.project?.title ?? "Brainstorm")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            HStack(spacing: 12) {
                                if model.activeJobCount > 0 {
                                    ProgressView().controlSize(.small)
                                    Text("\(model.activeJobCount) in progress").font(.caption).foregroundStyle(.secondary)
                                }
                                SettingsLink { Image(systemName: "slider.horizontal.3") }.help("Settings")
                            }
                        }
                    }
                }
            }
        }
        .tint(StudioStyle.accent)
        .fileImporter(isPresented: $model.showFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await model.importFiles(urls) }
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
        .alert("Something needs attention", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("Delete this concept and its images?", isPresented: Binding(get: { model.deleteProject != nil }, set: { if !$0 { model.deleteProject = nil } }), titleVisibility: .visible) {
            Button("Delete Concept", role: .destructive) {
                if let project = model.deleteProject { Task { await model.removeProject(project) } }
                model.deleteProject = nil
            }
            Button("Cancel", role: .cancel) { model.deleteProject = nil }
        } message: { Text("Export any images you want to keep first.") }
        .sheet(item: $model.renameProject) { project in RenameView(model: model, project: project) }
        .sheet(isPresented: $model.showRefinePrompt) {
            PromptRefinementView(model: model, original: model.prompt,
                                 references: [model.parentAsset].compactMap { $0 } + model.currentReferences,
                                 provider: model.settings.provider)
        }
        .sheet(item: Binding(get: { model.selectedAsset }, set: { model.selectedAssetID = $0?.id })) { asset in
            ImageDetailView(model: model, asset: asset)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            Task { do { try await model.saveDraft() } catch { model.errorMessage = error.localizedDescription } }
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.title2).foregroundStyle(StudioStyle.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Brainstorm").font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("A little room to explore").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 24)
            Button { Task { await model.createProject() } } label: {
                Label("New concept", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
            }
            .buttonStyle(.bordered).controlSize(.large).padding(.horizontal, 14).padding(.bottom, 16)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Find a concept", text: $model.search).textFieldStyle(.plain)
            }.padding(8).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 14)
            List(selection: Binding(get: { model.selectedProjectID }, set: { id in Task { await model.selectProject(id) } })) {
                Section("Your concepts") {
                    ForEach(model.visibleProjects) { project in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "square.grid.2x2").foregroundStyle(.secondary).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(project.title).lineLimit(2).font(.system(size: 13, weight: .medium))
                                Text(project.createdAt, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 7).tag(project.id)
                        .contextMenu {
                            Button("Rename…") { model.renameProject = project }
                            Button("Delete…", role: .destructive) { model.deleteProject = project }
                        }
                    }
                }
            }
            .listStyle(.sidebar).scrollContentBackground(.hidden)
            Divider().padding(.horizontal, 14)
            HStack {
                Circle().fill(model.hasKeys.contains(model.settings.provider) ? StudioStyle.accent : Color.orange).frame(width: 6, height: 6)
                Text(model.hasKeys.contains(model.settings.provider) ? "\(model.settings.provider.title) connected" : "Add an API key in Settings")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }.buttonStyle(.plain)
            }.padding(17)
        }
        .disabled(model.isImporting || model.isSubmitting || model.isLoading)
    }
}

private struct GalleryView: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if model.projectBatches.isEmpty { emptyState }
                    else {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Explore the possibilities.").font(.system(size: 27, weight: .medium, design: .serif))
                                Text("Compare a set. Pick a direction. Make it yours.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(model.projectBatches.reduce(0) { $0 + $1.completedCount }) images")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.bottom, 3)
                        ForEach(Array(model.projectBatches.enumerated()), id: \.element.id) { index, batch in
                            BatchView(model: model, batch: batch, number: index + 1).id(batch.id)
                        }
                    }
                }
                .padding(28).frame(maxWidth: 1500, alignment: .leading).frame(maxWidth: .infinity)
            }
            .onChange(of: model.projectBatches.count) { old, new in
                if new > old, let id = model.projectBatches.last?.id { withAnimation { proxy.scrollTo(id, anchor: .top) } }
            }
        }
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("YOUR NEXT IDEA STARTS HERE", systemImage: "sparkle")
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.6).foregroundStyle(StudioStyle.accent)
            Text("One idea.\nMany possibilities.")
                .font(.system(size: 46, weight: .regular, design: .serif)).lineSpacing(2)
            Text("Describe what you have in mind, add a few references,\nand explore a whole set of images together.")
                .font(.system(size: 15)).foregroundStyle(.secondary).lineSpacing(5)
            HStack(alignment: .top, spacing: 28) {
                hint("01", "Explore", "See different takes on your idea.")
                hint("02", "Refine", "Choose an image and give it direction.")
                hint("03", "Start fresh", "Rework the brief for a new concept.")
            }.padding(.top, 26)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 26).padding(.vertical, 52)
    }
    private func hint(_ number: String, _ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(number).font(.system(.caption, design: .monospaced)).foregroundStyle(StudioStyle.accent)
            Text(title).font(.headline)
            Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BatchView: View {
    @ObservedObject var model: WorkspaceModel
    let batch: GenerationBatch
    let number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                if let parentID = batch.parentAssetID, let parent = model.assets[parentID] {
                    AssetImage(url: model.assetURL(parent, thumbnail: true)).frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 7))
                        .onTapGesture { model.selectedAssetID = parentID }.help("View the original image")
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(batch.parentAssetID == nil ? "EXPLORATION \(number.formatted(.number.precision(.integerLength(2))))" : "REFINEMENT \(number.formatted(.number.precision(.integerLength(2))))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.1).foregroundStyle(StudioStyle.accent)
                        Text("· \(batch.settings.provider.title) · \(batch.settings.quality.title)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(batch.prompt).font(.system(size: 14, weight: .medium)).lineLimit(3).textSelection(.enabled)
                }
                Spacer()
                Menu {
                    Button("Use this prompt again") { model.useBrief(from: batch) }
                    Button("Start a new concept from this prompt") {
                        Task { await model.createProject(prompt: batch.prompt, references: batch.referenceIDs.compactMap { model.assets[$0] }) }
                    }
                    Button("Export images…") { model.exportAll(batch) }.disabled(batch.completedCount == 0)
                    if batch.isActive { Button("Cancel remaining images") { Task { await model.cancel(batch) } } }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().help("Set options")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 370), spacing: 14)], spacing: 14) {
                ForEach(batch.jobs) { job in ImageCard(model: model, job: job) }
            }
            HStack(spacing: 10) {
                Text(batch.isActive ? "\(batch.completedCount) of \(batch.jobs.count) ready" : "\(batch.completedCount) of \(batch.jobs.count) images")
                    .font(.caption).foregroundStyle(.secondary)
                if !batch.referenceIDs.isEmpty {
                    Text("· \(batch.referenceIDs.count) reference\(batch.referenceIDs.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                if batch.completedCount > 0 {
                    Button { model.exportAll(batch) } label: { Label("Export set", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ImageCard: View {
    @ObservedObject var model: WorkspaceModel
    let job: GenerationJob
    @State private var hovering = false
    private var asset: Asset? { job.assetID.flatMap { model.assets[$0] } }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.035))
                if let asset {
                    AssetImage(url: model.assetURL(asset, thumbnail: true))
                        .onTapGesture { model.selectedAssetID = asset.id }
                        .onDrag { NSItemProvider(contentsOf: model.assetURL(asset)!) ?? NSItemProvider() }
                } else {
                    VStack(spacing: 12) {
                        if job.status == .running { ProgressView().controlSize(.regular) }
                        else { Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(.tertiary) }
                        Text(statusTitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        if let error = job.error {
                            Text(error).font(.caption2).foregroundStyle(.secondary).lineLimit(4).multilineTextAlignment(.center).help(error)
                        }
                        if job.status.canRetry {
                            Button("Retry image") { Task { await model.retry(job) } }.controlSize(.small)
                        } else if job.status.isActive {
                            Button("Cancel") { Task { await model.cancel(job) } }.buttonStyle(.plain).font(.caption).foregroundStyle(.tertiary)
                        }
                    }.padding(20)
                }
            }
            .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Text(String(format: "%02d", job.position + 1)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                if let asset {
                    Button { model.export(asset) } label: { Image(systemName: "arrow.down.to.line") }.buttonStyle(.plain).help("Export image")
                    Button { model.refine(asset) } label: { Label("Refine", systemImage: "arrow.turn.down.right") }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).padding(.leading, 8).foregroundStyle(StudioStyle.accent)
                } else { Text(job.status.title).font(.caption2).foregroundStyle(.tertiary) }
            }.padding(.horizontal, 3).padding(.top, 10)
        }
        .contextMenu {
            if let asset {
                Button("View image") { model.selectedAssetID = asset.id }
                Button("Refine this image") { model.refine(asset) }
                Button("Copy image") { model.copyImage(asset) }
                Button("Export…") { model.export(asset) }
            }
            if job.status.canRetry { Button("Retry image") { Task { await model.retry(job) } } }
        }
    }
    private var symbol: String {
        switch job.status { case .queued: "clock"; case .cancelled: "xmark.circle"; case .interrupted: "pause.circle"; default: "exclamationmark.triangle" }
    }
    private var statusTitle: String {
        switch job.status { case .queued: "Waiting its turn"; case .running: "Creating your image…"; case .interrupted: "Ready to resume"; default: job.status.title }
    }
}

struct AssetImage: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var failed = false
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image { Image(nsImage: image).resizable().scaledToFit() }
                else if failed { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary).help("The image file could not be read.") }
                else { ProgressView().controlSize(.small) }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .task(id: url) {
            image = nil; failed = false
            guard let url else { failed = true; return }
            do {
                let data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
                try Task.checkCancellation()
                image = NSImage(data: data)
                failed = image == nil
            } catch is CancellationError { /* The image view was replaced. */ }
            catch { failed = true }
        }
    }
}

private struct RenameView: View {
    @ObservedObject var model: WorkspaceModel
    let project: Project
    @State private var title: String
    @Environment(\.dismiss) private var dismiss
    init(model: WorkspaceModel, project: Project) { self.model = model; self.project = project; _title = State(initialValue: project.title) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename concept").font(.headline)
            TextField("Name", text: $title).textFieldStyle(.roundedBorder)
            HStack {
                Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { Task { await model.rename(project, to: title); dismiss() } }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 380)
    }
}
