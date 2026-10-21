import Foundation
import BrainstormCore

struct ConversationSummary {
    let iterationCount: Int
    let imageCount: Int
    let latestImage: Asset?

    init(batches: [GenerationBatch], assets: [UUID: Asset]) {
        iterationCount = batches.count
        let completed = batches.flatMap(\.jobs).filter { $0.status == .succeeded }
        imageCount = completed.count
        latestImage = completed.compactMap { $0.assetID.flatMap { assets[$0] } }
            .max { $0.createdAt < $1.createdAt }
    }

    var caption: String {
        "\(iterationCount) \(iterationCount == 1 ? "iteration" : "iterations") · \(imageCount) \(imageCount == 1 ? "image" : "images")"
    }
}
