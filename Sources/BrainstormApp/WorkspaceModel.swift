import AppKit
import SwiftUI
import UniformTypeIdentifiers
import BrainstormCore

@MainActor
final class WorkspaceModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var batches: [GenerationBatch] = []
    @Published private(set) var assets: [UUID: Asset] = [:]
    @Published private(set) var selectedProjectID: UUID?
    @Published var prompt = "" { didSet { scheduleSave() } }
    @Published private(set) var referenceIDs: [UUID] = []
    @Published private(set) var parentAssetID: UUID?
    @Published var settings = GenerationSettings() { didSet { saveSettings() } }
    @Published var count = 4 { didSet { UserDefaults.standard.set(count, forKey: preferenceKey("generationCount")) } }
    @Published var concurrency = 3 { didSet {
        UserDefaults.standard.set(concurrency, forKey: preferenceKey("concurrency"))
        if let queue { Task { await queue.setConcurrency(concurrency) } }
    } }
    @Published var search = ""
    @Published var errorMessage: String?
    @Published var fatalError: String?
    @Published var selectedAssetID: UUID?
    @Published var isImporting = false
    @Published var isSubmitting = false
    @Published var isLoading = true
    @Published var hasKeys: Set<ProviderID> = []
    @Published var showRefinePrompt = false
    @Published var showFileImporter = false
    @Published var renameProject: Project?
    @Published var deleteProject: Project?
    let isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
    let keychain = KeychainCredentials()
    private(set) var library: LibraryStore?
    private(set) var assetStore: AssetStore?
    private(set) var providers = ProviderRegistry()
    private var credentials: (any CredentialStore)?
    private var queue: GenerationQueue?
    private var started = false
    private var libraryLock: LibraryLock?
    private var restoring = false
    private var saveTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var navigationRevision = 0
    private(set) var libraryURL: URL?

    var project: Project? { projects.first { $0.id == selectedProjectID } }
    var visibleProjects: [Project] {
        search.isEmpty ? projects : projects.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.prompt.localizedCaseInsensitiveContains(search) }
    }
    var projectBatches: [GenerationBatch] { batches.filter { $0.projectID == selectedProjectID } }
    var activeJobCount: Int { batches.flatMap(\.jobs).filter { $0.status.isActive }.count }
    var canGenerate: Bool { !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting && !isImporting && !isLoading }
    var currentReferences: [Asset] { referenceIDs.compactMap { assets[$0] } }
    var parentAsset: Asset? { parentAssetID.flatMap { assets[$0] } }
    var selectedAsset: Asset? { selectedAssetID.flatMap { assets[$0] } }

    func start() async {
        guard !started else { return }
        started = true
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let root = support.appendingPathComponent(isDemo ? "Brainstorm Native Demo" : "Brainstorm Native", isDirectory: true)
            libraryURL = root
            libraryLock = try LibraryLock(root: root)
            let library = try LibraryStore(url: root.appendingPathComponent("library.sqlite"))
            let assetStore = try AssetStore(root: root.appendingPathComponent("Images", isDirectory: true))
            self.library = library; self.assetStore = assetStore
            if isDemo {
                providers = ProviderRegistry(providers: [.openAI: DemoProvider(), .gemini: DemoProvider()])
                credentials = DemoCredentials()
            } else { credentials = keychain }
            guard let credentials else { throw BrainstormError.storage("Credential storage is unavailable.") }
            let queue = GenerationQueue(library: library, assets: assetStore, credentials: credentials, providers: providers)
            self.queue = queue
            try await queue.prepare()
            if let data = UserDefaults.standard.data(forKey: preferenceKey("generationSettings")) {
                settings = try JSONDecoder().decode(GenerationSettings.self, from: data)
                try settings.validate()
            }
            let savedCount = UserDefaults.standard.integer(forKey: preferenceKey("generationCount"))
            if (1...16).contains(savedCount) { count = savedCount }
            let savedConcurrency = UserDefaults.standard.integer(forKey: preferenceKey("concurrency"))
            if (1...6).contains(savedConcurrency) { concurrency = savedConcurrency }
            await queue.setConcurrency(concurrency)
            try await reload()
            let savedID = UserDefaults.standard.string(forKey: isDemo ? "demoSelectedProject" : "selectedProject").flatMap(UUID.init(uuidString:))
            restore(projects.first { $0.id == savedID } ?? projects.first)
            await refreshKeys()
            isLoading = false
            eventTask = Task { [weak self] in
                for await event in queue.events {
                    guard let self, !Task.isCancelled else { break }
                    switch event {
                    case .changed:
                        do { try await self.reload() } catch { self.errorMessage = error.localizedDescription }
                    case .error(let message): self.errorMessage = message
                    }
                }
            }
            if isDemo && projects.isEmpty { await seedDemo() }
        } catch { fatalError = error.localizedDescription; isLoading = false }
    }

    func reload() async throws {
        guard let library else { return }
        let snapshot = try await library.snapshot()
        projects = snapshot.projects; batches = snapshot.batches
        assets = Dictionary(uniqueKeysWithValues: snapshot.assets.map { ($0.id, $0) })
    }
    func refreshKeys() async {
        if isDemo { hasKeys = Set(ProviderID.allCases); return }
        do {
            var available: Set<ProviderID> = []
            for provider in ProviderID.allCases where try await keychain.hasKey(for: provider) { available.insert(provider) }
            hasKeys = available
        } catch { errorMessage = error.localizedDescription }
    }
    func selectProject(_ id: UUID?) async {
        guard id != selectedProjectID, !isImporting, !isSubmitting else { return }
        navigationRevision += 1
        let revision = navigationRevision
        do {
            try await saveDraft()
            guard navigationRevision == revision else { return }
            restore(projects.first { $0.id == id })
        } catch { errorMessage = error.localizedDescription }
    }
    func createProject(prompt newPrompt: String = "", references: [Asset] = []) async {
        guard !isImporting, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await saveDraft()
            guard let library, let assetStore else { return }
            var value = Project(title: PromptBuilder.title(from: newPrompt), prompt: newPrompt)
            try await library.saveProject(value)
            for reference in references {
                let copied = try await assetStore.importFile(assetStore.url(for: reference), projectID: value.id, name: reference.name)
                try await library.addAsset(copied)
                value.referenceIDs.append(copied.id)
            }
            try await library.saveProject(value)
            try await reload()
            restore(value)
        } catch { errorMessage = error.localizedDescription }
    }
    func generate() async {
        guard canGenerate else { return }
        if project == nil { await createProject(prompt: prompt) }
        guard let project, let queue else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await saveDraft()
            let previous = parentAssetID.flatMap { parent in batches.first { $0.jobs.contains { $0.assetID == parent } } }
            let resolved = try PromptBuilder.imagePrompt(prompt, parentPrompt: parentAssetID == nil ? nil : (previous?.resolvedPrompt ?? "Use the attached image as the design to refine."))
            let references = [parentAssetID].compactMap { $0 } + referenceIDs.filter { $0 != parentAssetID }
            let id = UUID()
            let batch = GenerationBatch(id: id, projectID: project.id, prompt: prompt, resolvedPrompt: resolved,
                                        parentAssetID: parentAssetID, referenceIDs: references, settings: settings,
                                        jobs: (0..<count).map { GenerationJob(batchID: id, position: $0) })
            try await queue.submit(batch)
            try await reload()
        } catch { errorMessage = error.localizedDescription }
    }
    func selectProvider(_ provider: ProviderID) {
        settings = GenerationSettings(provider: provider, model: provider.models[0].id, shape: settings.shape, quality: settings.quality)
    }
    func refine(_ asset: Asset) {
        guard asset.projectID == selectedProjectID else { return }
        parentAssetID = asset.id
        referenceIDs = []
        prompt = ""
        selectedAssetID = nil
        scheduleSave()
    }
    func clearParent() { parentAssetID = nil; scheduleSave() }
    func useBrief(from batch: GenerationBatch) {
        parentAssetID = batch.parentAssetID
        referenceIDs = batch.referenceIDs.filter { $0 != batch.parentAssetID }
        settings = batch.settings
        prompt = batch.prompt
        scheduleSave()
    }
    func removeReference(_ id: UUID) { referenceIDs.removeAll { $0 == id }; scheduleSave() }
    func importFiles(_ urls: [URL]) async {
        guard !isImporting, !isSubmitting else { return }
        if project == nil { await createProject(prompt: prompt) }
        guard let projectID = selectedProjectID, let assetStore, let library else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            guard referenceIDs.count + urls.count + (parentAssetID == nil ? 0 : 1) <= settings.provider.maximumReferences else {
                throw BrainstormError.invalid("\(settings.provider.title) supports up to \(settings.provider.maximumReferences) images, including the image being refined.")
            }
            for url in urls {
                let asset = try await assetStore.importFile(url, projectID: projectID)
                try await library.addAsset(asset)
                assets[asset.id] = asset
                referenceIDs.append(asset.id)
                try await saveDraft()
            }
            try await reload()
        } catch { errorMessage = error.localizedDescription }
    }
    func pasteImage() async {
        guard !isImporting, !isSubmitting else { return }
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            await importFiles(urls); return
        }
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else {
            errorMessage = "Copy an image or an image file, then choose Paste Reference Image."; return
        }
        if project == nil { await createProject(prompt: prompt) }
        guard let id = selectedProjectID, let assetStore, let library else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            guard referenceIDs.count + (parentAssetID == nil ? 0 : 1) < settings.provider.maximumReferences else {
                throw BrainstormError.invalid("Remove a reference before pasting another image.")
            }
            let asset = try await assetStore.save(data: data, projectID: id, name: "Pasted image", isReference: true)
            try await library.addAsset(asset)
            assets[asset.id] = asset; referenceIDs.append(asset.id)
            try await saveDraft()
        } catch { errorMessage = error.localizedDescription }
    }
    func retry(_ job: GenerationJob) async {
        do { try await queue?.retry(job.id) } catch { errorMessage = error.localizedDescription }
    }
    func cancel(_ job: GenerationJob) async {
        do { try await queue?.cancel(job.id) } catch { errorMessage = error.localizedDescription }
    }
    func cancel(_ batch: GenerationBatch) async {
        for job in batch.jobs where job.status.isActive { await cancel(job) }
    }
    func removeProject(_ project: Project) async {
        do {
            let jobs = batches.filter { $0.projectID == project.id }.flatMap(\.jobs)
            for job in jobs where job.status.isActive { try await queue?.cancel(job.id) }
            if selectedProjectID == project.id { saveTask?.cancel(); restore(nil) }
            try await library?.deleteProject(project.id)
            try await assetStore?.removeProject(project.id)
            try await reload()
            if selectedProjectID == nil { restore(projects.first) }
        } catch { errorMessage = error.localizedDescription }
    }
    func rename(_ project: Project, to title: String) async {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            try await saveDraft()
            var updated = projects.first { $0.id == project.id } ?? project
            updated.title = String(title.prefix(120))
            try await library?.saveProject(updated)
            try await reload()
        } catch { errorMessage = error.localizedDescription }
    }
    func refinePrompt(_ original: String, direction: String, referenceAssets: [Asset], providerID: ProviderID) async throws -> String {
        guard let credentials, let assetStore else { throw BrainstormError.storage("Library unavailable.") }
        let key = try await credentials.key(for: providerID)
        let provider = try providers.provider(providerID)
        var references: [ImageReference] = []
        for asset in referenceAssets { references.append(try await assetStore.reference(asset)) }
        return try await provider.refinePrompt(original, direction: direction, references: references, apiKey: key)
    }
    func assetURL(_ asset: Asset, thumbnail: Bool = false) -> URL? { assetStore?.url(for: asset, thumbnail: thumbnail) }
    func export(_ asset: Asset) {
        guard let source = assetURL(asset) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = safeFilename(asset.name)
        panel.begin { [weak self] response in
            guard response == .OK, let target = panel.url else { return }
            do { try Data(contentsOf: source).write(to: target, options: .atomic) }
            catch { self?.errorMessage = error.localizedDescription }
        }
    }
    func exportAll(_ batch: GenerationBatch) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "Export Images"
        panel.begin { [weak self] response in
            guard let self, response == .OK, let destination = panel.url else { return }
            do {
                for job in batch.jobs {
                    guard let id = job.assetID, let asset = self.assets[id], let source = self.assetURL(asset) else { continue }
                    let name = "Brainstorm-\(batch.id.uuidString.prefix(8))-\(job.position + 1).png"
                    var target = destination.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: target.path) { target = destination.appendingPathComponent("\(UUID().uuidString.prefix(8))-\(name)") }
                    try FileManager.default.copyItem(at: source, to: target)
                }
                NSWorkspace.shared.open(destination)
            } catch { self.errorMessage = error.localizedDescription }
        }
    }
    func copyImage(_ asset: Asset) {
        guard let url = assetURL(asset), let image = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    func revealLibrary() { if let libraryURL { NSWorkspace.shared.open(libraryURL) } }
    private func safeFilename(_ name: String) -> String {
        String(name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").prefix(150))
    }
    private func restore(_ project: Project?) {
        restoring = true
        selectedProjectID = project?.id
        prompt = project?.prompt ?? ""
        parentAssetID = project?.parentAssetID
        referenceIDs = project?.referenceIDs ?? []
        selectedAssetID = nil
        UserDefaults.standard.set(project?.id.uuidString, forKey: isDemo ? "demoSelectedProject" : "selectedProject")
        restoring = false
    }
    private func scheduleSave() {
        guard !restoring, selectedProjectID != nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                try await self?.saveDraft()
            } catch is CancellationError { /* A newer draft superseded this one. */ }
            catch { self?.errorMessage = error.localizedDescription }
        }
    }
    func saveDraft() async throws {
        guard var project, let library else { return }
        project.prompt = prompt; project.referenceIDs = referenceIDs; project.parentAssetID = parentAssetID
        project.updatedAt = .now
        if project.title == "Untitled concept", !prompt.isEmpty { project.title = PromptBuilder.title(from: prompt) }
        try await library.saveProject(project)
        if let index = projects.firstIndex(where: { $0.id == project.id }) { projects[index] = project }
    }
    private func preferenceKey(_ name: String) -> String { isDemo ? "demo.\(name)" : name }
    private func saveSettings() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(settings), forKey: preferenceKey("generationSettings")) }
        catch { errorMessage = error.localizedDescription }
    }
}
