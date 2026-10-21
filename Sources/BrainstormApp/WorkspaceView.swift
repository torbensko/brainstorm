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
                        if model.projectBatches.isEmpty {
                            Spacer(minLength: 36)
                            HStack(spacing: 16) {
                                Image(nsImage: NSApplication.shared.applicationIconImage)
                                    .resizable().scaledToFit().frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Brainstorm logo")
                                Text("What shall we explore?").font(.system(size: 34, weight: .regular, design: .serif))
                            }.padding(.bottom, 20)
                            ComposerView(model: model).frame(maxWidth: 1000)
                            Text("One idea, a few different directions.").font(.subheadline).foregroundStyle(.tertiary).padding(.top, 6)
                            Spacer(minLength: 36)
                            Spacer(minLength: 0)
                        } else {
                            GalleryView(model: model)
                            ComposerView(model: model).frame(maxWidth: 1200)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .navigationTitle("")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text(model.project?.title ?? "New conversation")
                                .font(.system(size: 14, weight: .medium)).lineLimit(1).truncationMode(.tail)
                                .help(model.project?.title ?? "New conversation")
                        }
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
        .confirmationDialog("Delete this conversation and its images?", isPresented: Binding(get: { model.deleteProject != nil }, set: { if !$0 { model.deleteProject = nil } }), titleVisibility: .visible) {
            Button("Delete Conversation", role: .destructive) {
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
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Search", text: $model.search).textFieldStyle(.plain)
            }.padding(8).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 14).padding(.top, 16)
            Button { Task { await model.createProject() } } label: {
                Label("New conversation", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain).padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 18)
            List(selection: Binding(get: { model.selectedProjectID }, set: { id in Task { await model.selectProject(id) } })) {
                Section("Conversations") {
                    ForEach(model.visibleProjects) { project in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "bubble.left").foregroundStyle(.secondary).padding(.top, 2)
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
                Text(model.hasKeys.contains(model.settings.provider) ? model.settings.provider.title : model.settings.provider == .chatGPT ? "Connect ChatGPT" : "Add an API key")
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
                    ForEach(Array(model.projectBatches.enumerated()), id: \.element.id) { index, batch in
                        BatchView(model: model, batch: batch, number: index + 1).id(batch.id)
                    }
                }
                .padding(28).frame(maxWidth: 1500, alignment: .leading).frame(maxWidth: .infinity)
            }
            .onChange(of: model.projectBatches.count) { old, new in
                if new > old, let id = model.projectBatches.last?.id { withAnimation { proxy.scrollTo(id, anchor: .top) } }
            }
        }
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
                        Text(batch.settings.provider == .chatGPT ? "· ChatGPT subscription" : "· \(batch.settings.provider.title) · \(batch.settings.quality.title)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(batch.prompt).font(.system(size: 14, weight: .medium)).lineLimit(3).textSelection(.enabled)
                }
                Spacer()
                Menu {
                    Button("Use this prompt again") { model.useBrief(from: batch) }
                    Button("Start a new conversation from this prompt") {
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
            Text("Rename conversation").font(.headline)
            TextField("Name", text: $title).textFieldStyle(.roundedBorder)
            HStack {
                Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { Task { await model.rename(project, to: title); dismiss() } }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 380)
    }
}
