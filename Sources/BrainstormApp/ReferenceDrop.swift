import AppKit
import UniformTypeIdentifiers
import BrainstormCore

enum ReferenceAttachment: Sendable {
    case file(URL)
    case image(Data, name: String)
}

/// A drag can contain a file URL, image bytes, or both representations of the same image.
/// Prefer the file so each item is attached once, with its original name.
@MainActor
enum ReferenceDrop {
    static let contentTypes: [UTType] = [.fileURL, .image]
    static let pasteboardTypes: [NSPasteboard.PasteboardType] = [.fileURL] + NSImage.imageTypes
        .filter { UTType($0)?.conforms(to: .image) == true }
        .map { NSPasteboard.PasteboardType($0) }

    static func containsAttachments(_ board: NSPasteboard) -> Bool {
        board.types?.contains { $0 == .fileURL || UTType($0.rawValue)?.conforms(to: .image) == true } == true
    }

    static func read(_ board: NSPasteboard) throws -> [ReferenceAttachment] {
        try (board.pasteboardItems ?? []).compactMap { item in
            if item.types.contains(.fileURL) {
                guard let value = item.string(forType: .fileURL), let url = URL(string: value), url.isFileURL else {
                    throw BrainstormError.invalid("The dropped file could not be read. Try choosing it with Attach.")
                }
                return .file(url)
            }
            guard let type = item.types.first(where: { UTType($0.rawValue)?.conforms(to: .image) == true }) else { return nil }
            guard let data = item.data(forType: type), !data.isEmpty else {
                throw BrainstormError.invalid("The dropped image could not be read. Try saving it and attaching the file.")
            }
            return .image(data, name: "Attached image")
        }
    }

    static func read(_ provider: NSItemProvider) async throws -> ReferenceAttachment {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let data = try await data(from: provider, type: UTType.fileURL.identifier)
            guard let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL else {
                throw BrainstormError.invalid("The dropped file could not be read. Try choosing it with Attach.")
            }
            return .file(url)
        }
        guard let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else {
            throw BrainstormError.invalid("Drop an image file or an image to attach it.")
        }
        let name = provider.suggestedName ?? "Dropped image"
        return .image(try await data(from: provider, type: type), name: name)
    }

    private static func data(from provider: NSItemProvider, type: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data, !data.isEmpty { continuation.resume(returning: data) }
                else { continuation.resume(throwing: BrainstormError.invalid("The dropped image contained no readable data.")) }
            }
        }
    }
}
