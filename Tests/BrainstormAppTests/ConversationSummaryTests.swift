import Foundation
import Testing
import BrainstormCore
@testable import BrainstormApp

@Test func sidebarSummaryCountsFinishedImagesAndUsesTheLatestGeneratedPreview() {
    let projectID = UUID()
    func image(_ date: TimeInterval) -> Asset {
        Asset(projectID: projectID, name: "Image", filename: "image.png", thumbnailFilename: "thumb.png",
              mimeType: "image/png", width: 100, height: 100, createdAt: Date(timeIntervalSince1970: date))
    }
    let first = image(1), latest = image(2), reference = image(3)
    let firstID = UUID(), secondID = UUID()
    let batches = [
        GenerationBatch(id: firstID, projectID: projectID, prompt: "First", resolvedPrompt: "First", settings: GenerationSettings(),
                        jobs: [GenerationJob(batchID: firstID, position: 0, status: .succeeded, assetID: latest.id),
                               GenerationJob(batchID: firstID, position: 1, status: .failed)]),
        GenerationBatch(id: secondID, projectID: projectID, prompt: "Second", resolvedPrompt: "Second", referenceIDs: [reference.id], settings: GenerationSettings(),
                        jobs: [GenerationJob(batchID: secondID, position: 0, status: .succeeded, assetID: first.id),
                               GenerationJob(batchID: secondID, position: 1, status: .running)])
    ]
    let summary = ConversationSummary(batches: batches, assets: Dictionary(uniqueKeysWithValues: [first, latest, reference].map { ($0.id, $0) }))
    #expect(summary.caption == "2 iterations · 2 images")
    #expect(summary.latestImage?.id == latest.id)
}
