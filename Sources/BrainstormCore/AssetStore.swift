import Foundation
import ImageIO
import UniformTypeIdentifiers

public actor AssetStore {
    public nonisolated let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    public nonisolated func url(for asset: Asset, thumbnail: Bool = false) -> URL {
        root.appendingPathComponent(thumbnail ? asset.thumbnailFilename : asset.filename)
    }
    public func importFile(_ url: URL, projectID: UUID, name: String? = nil) throws -> Asset {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= 30_000_000 else {
            throw BrainstormError.invalid("Choose an image file smaller than 30 MB.")
        }
        return try save(data: Data(contentsOf: url), projectID: projectID, name: name ?? url.lastPathComponent, isReference: true)
    }
    public func save(data: Data, projectID: UUID, name: String, isReference: Bool = false) throws -> Asset {
        guard data.count <= 60_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, Double(width) * Double(height) <= 64_000_000 else {
            throw BrainstormError.invalid("This file is not a readable image, or it is too large.")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: isReference ? 4096 : max(width, height)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw BrainstormError.invalid("Could not decode this image.")
        }
        let original = try encode(image, type: UTType.png.identifier)
        guard !isReference || original.count < 14_000_000 else {
            throw BrainstormError.invalid("This reference is too large to send. Resize it before attaching it.")
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw BrainstormError.invalid("Could not create an image preview.")
        }
        let id = UUID()
        let directory = root.appendingPathComponent(projectID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(projectID)/\(id).png"
        let thumbnailFilename = "\(projectID)/\(id)-preview.png"
        try original.write(to: root.appendingPathComponent(filename), options: .atomic)
        do {
            try encode(thumbnail, type: UTType.png.identifier).write(to: root.appendingPathComponent(thumbnailFilename), options: .atomic)
        } catch {
            try FileManager.default.removeItem(at: root.appendingPathComponent(filename))
            throw error
        }
        return Asset(id: id, projectID: projectID, name: name, filename: filename,
                     thumbnailFilename: thumbnailFilename, mimeType: "image/png", width: image.width, height: image.height)
    }
    public func reference(_ asset: Asset) throws -> ImageReference {
        let data = try Data(contentsOf: url(for: asset))
        guard data.count < 14_000_000 else { throw BrainstormError.invalid("This image is too large for an edit request. Attach a smaller copy.") }
        return ImageReference(data: data, mimeType: asset.mimeType)
    }
    public func remove(_ asset: Asset) throws {
        for url in [url(for: asset), url(for: asset, thumbnail: true)] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    public func removeProject(_ id: UUID) throws {
        let directory = root.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    private func encode(_ image: CGImage, type: String) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil) else {
            throw BrainstormError.storage("Cannot create an image file.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BrainstormError.storage("Cannot save the image.") }
        return output as Data
    }
}
