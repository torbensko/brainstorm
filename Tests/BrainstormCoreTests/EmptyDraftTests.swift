import Foundation
import Testing
@testable import BrainstormCore

@Test func consolidatingDraftsPreservesNamesTextImagesAndGenerationHistory() async throws {
    let fixture = try Fixture()
    let selected = Project()
    let duplicate = Project(prompt: " \n\t ")
    let named = Project(title: "Ideas for later", titleMode: .custom)
    let written = Project(prompt: "Keep this idea")
    let illustrated = Project()
    let generated = Project()
    for project in [selected, duplicate, named, written, illustrated, generated] {
        try await fixture.library.saveProject(project)
    }
    let image = try await fixture.assets.save(data: testPNG(), projectID: illustrated.id, name: "Reference")
    try await fixture.library.addAsset(image)
    let batchID = UUID()
    try await fixture.library.addBatch(GenerationBatch(id: batchID, projectID: generated.id,
        prompt: "A finished conversation with an empty composer", resolvedPrompt: "A design",
        settings: GenerationSettings(), jobs: [GenerationJob(batchID: batchID, position: 0)]))

    let retained = try await fixture.library.consolidateEmptyDrafts(preferredID: selected.id)
    #expect(retained?.id == selected.id)
    let snapshot = try await fixture.library.snapshot()
    #expect(Set(snapshot.projects.map(\.id)) == Set([selected.id, named.id, written.id, illustrated.id, generated.id]))
    #expect(snapshot.assets.map(\.id) == [image.id])
    #expect(snapshot.batches.map(\.id) == [batchID])

    let reopened = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
    #expect(try await reopened.consolidateEmptyDrafts()?.id == selected.id)
    #expect(try await reopened.snapshot().projects == snapshot.projects)
}
