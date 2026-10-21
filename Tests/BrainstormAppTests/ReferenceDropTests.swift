import AppKit
import SwiftUI
import Testing
import UniformTypeIdentifiers
import BrainstormCore
@testable import BrainstormApp

@Suite(.serialized) @MainActor
struct ReferenceDropTests {
    @Test func emptyEditorHasClickableBoundsAndUpdatesPrompt() throws {
        _ = NSApplication.shared
        var prompt = ""
        let view = PromptEditor(text: Binding(get: { prompt }, set: { prompt = $0 }),
                                placeholder: "Describe an idea", focusID: nil,
                                onAttachments: { _ in }, onError: { Issue.record($0) }, onSubmit: {})
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 70)
        host.layoutSubtreeIfNeeded()
        let editor = try #require(findEditor(in: host))
        #expect(editor.bounds.width > 0)
        #expect(editor.bounds.height >= 60)
        editor.insertText("First line", replacementRange: NSRange(location: 0, length: 0))
        editor.insertNewline(nil)
        editor.insertText("Second line", replacementRange: editor.selectedRange())
        #expect(prompt == "First line\nSecond line")
    }

    @Test func editorWrapsAtItsActualWidthAfterMeasurementAndResizing() throws {
        _ = NSApplication.shared
        let prompt = "Show some of the ways I could style this room"
        let view = PromptEditor(text: .constant(prompt), placeholder: "Describe an idea", focusID: nil,
                                onAttachments: { _ in }, onError: { Issue.record($0) }, onSubmit: {})
        let controller = NSHostingController(rootView: view.frame(maxWidth: .infinity))
        let host = controller.view
        for width: CGFloat in [900, 180, 700] {
            host.frame = NSRect(x: 0, y: 0, width: width, height: 100)
            host.layoutSubtreeIfNeeded()
            // Probe a narrow alternative without changing the final frame, as SwiftUI layouts do.
            _ = controller.sizeThatFits(in: NSSize(width: 120, height: 200))
            let editor = try #require(findEditor(in: host))
            let container = try #require(editor.textContainer)
            let layout = try #require(editor.layoutManager)
            layout.ensureLayout(for: container)
            #expect(abs(editor.bounds.width - width) < 2)
            #expect(abs(container.size.width - editor.bounds.width) < 2)
            var lines = 0
            layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, _, _ in lines += 1 }
            #expect(width > 500 ? lines == 1 : lines > 1)
        }
    }

    @Test func filesDroppedOnEditorAttachOnceWithoutChangingPrompt() throws {
        _ = NSApplication.shared
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let urls = [URL(fileURLWithPath: "/tmp/First reference.png"), URL(fileURLWithPath: "/tmp/Second.png")]
        let items = urls.map { url in
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .fileURL)
            item.setString(url.path, forType: .string)
            item.setData(Data([1, 2, 3]), forType: .png) // Alternate representation must not duplicate the file.
            return item
        }
        #expect(board.writeObjects(items))
        let editor = AttachmentTextView()
        editor.string = "Keep this prompt unchanged"
        var attached: [ReferenceAttachment] = []
        editor.onAttachments = { attached += $0 }
        editor.onError = { Issue.record($0) }
        let drag = TestDraggingInfo(board: board)
        #expect(editor.draggingEntered(drag) == .copy)
        #expect(editor.draggingUpdated(drag) == .copy)
        #expect(editor.prepareForDragOperation(drag))
        #expect(editor.performDragOperation(drag))
        #expect(editor.string == "Keep this prompt unchanged")
        #expect(attached.count == 2)
        let actual = attached.compactMap { attachment -> URL? in
            if case .file(let url) = attachment { return url }; return nil
        }
        #expect(actual == urls)
    }

    @Test func imageOnlyDropOnEditorAttachesBytes() throws {
        _ = NSApplication.shared
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let data = try imageData()
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        #expect(board.writeObjects([item]))
        let editor = AttachmentTextView()
        editor.string = "An existing idea"
        var received: Data?
        editor.onAttachments = {
            if case .image(let bytes, _) = $0.first { received = bytes }
        }
        editor.onError = { Issue.record($0) }
        #expect(editor.performDragOperation(TestDraggingInfo(board: board)))
        #expect(received == data)
        #expect(editor.string == "An existing idea")
    }

    @Test func textIsNotAnAttachmentAndBrokenFileDropsNeverInsertPaths() {
        _ = NSApplication.shared
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Ordinary text", forType: .string)
        let editor = AttachmentTextView()
        editor.string = "Existing prompt"
        #expect(!editor.consumeAttachments(from: board))
        board.clearContents()
        board.setString("https://example.com/not-a-local-file.png", forType: .fileURL)
        var reportedError = false
        editor.onError = { _ in reportedError = true }
        editor.onAttachments = { _ in Issue.record("Invalid file should not attach") }
        #expect(editor.performDragOperation(TestDraggingInfo(board: board)))
        #expect(reportedError)
        #expect(editor.string == "Existing prompt")
    }

    @Test func workspaceDropSupportsFileURLsAndRawImageProviders() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brainstorm-drop-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("Reference with spaces.png")
        let bytes = try imageData()
        try bytes.write(to: file)
        let fileProvider = NSItemProvider(item: file as NSURL, typeIdentifier: UTType.fileURL.identifier)
        let imageProvider = NSItemProvider(item: bytes as NSData, typeIdentifier: UTType.png.identifier)
        imageProvider.suggestedName = "Browser image"
        let store = try AssetStore(root: root.appendingPathComponent("Images"))
        let projectID = UUID()
        var assets: [Asset] = []
        for provider in [fileProvider, imageProvider] {
            switch try await ReferenceDrop.read(provider) {
            case .file(let url): assets.append(try await store.importFile(url, projectID: projectID))
            case .image(let data, let name): assets.append(try await store.save(data: data, projectID: projectID, name: name, isReference: true))
            }
        }
        #expect(assets.map(\.name) == [file.lastPathComponent, "Browser image"])
        #expect(assets.allSatisfy { FileManager.default.fileExists(atPath: store.url(for: $0).path) })
        #expect(assets.allSatisfy { $0.width == 8 && $0.height == 8 })
    }

    @Test func providerReadFailureIsReported() async {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(nil, NSError(domain: "Drop test", code: 1))
            return nil
        }
        do {
            _ = try await ReferenceDrop.read(provider)
            Issue.record("Unreadable drop should fail")
        } catch { #expect(!error.localizedDescription.isEmpty) }
    }

    private func imageData() throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
                                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    private func findEditor(in view: NSView) -> AttachmentTextView? {
        if let editor = view as? AttachmentTextView { return editor }
        return view.subviews.lazy.compactMap { findEditor(in: $0) }.first
    }
}

@MainActor private final class TestDraggingInfo: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    init(board: NSPasteboard) { draggingPasteboard = board }
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    nonisolated var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?,
                                classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any],
                                using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
