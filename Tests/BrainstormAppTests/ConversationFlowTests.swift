import Foundation
import Testing
import BrainstormCore
@testable import BrainstormApp

@Suite(.serialized) @MainActor
struct ConversationFlowTests {
    @Test func sendingMovesPromptAndImagesIntoHistoryAndPersistsAnEmptyComposer() async throws {
        let fixture = try ConversationFixture()
        let model = fixture.model
        await model.createProject()
        model.prompt = "S"
        try await model.saveDraft()
        model.prompt = "Show some of the ways I could style this room"
        await model.importAttachments([.image(try DemoArtwork.image(index: 0), name: "Room")])
        let reference = try #require(model.currentReferences.first)
        await model.generate()
        let batch = try #require(model.projectBatches.first)
        #expect(batch.prompt == "Show some of the ways I could style this room")
        #expect(batch.referenceIDs == [reference.id])
        #expect(model.prompt.isEmpty && model.currentReferences.isEmpty && model.parentAssetID == nil)
        #expect(model.project?.title == "Show some of the ways I could")
        #expect(model.errorMessage == nil)
        let reopened = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
        let saved = try #require(try await reopened.snapshot().projects.first)
        #expect(saved.prompt.isEmpty && saved.referenceIDs.isEmpty && saved.parentAssetID == nil)
        #expect(try await reopened.snapshot().batches.first?.referenceIDs == [reference.id])
        await model.cancel(batch)

        model.refine(reference)
        model.prompt = "Make the room warmer"
        await model.generate()
        let reply = try #require(model.projectBatches.last)
        #expect(reply.parentAssetID == reference.id && reply.referenceIDs == [reference.id])
        #expect(model.prompt.isEmpty && model.parentAssetID == nil)
        #expect(model.project?.title == saved.title)
        await model.cancel(reply)
    }

    @Test func rejectedSendPreservesDraftAndAttachments() async throws {
        let fixture = try ConversationFixture(rejectSend: true)
        let model = fixture.model
        model.prompt = "Keep my room reference and this prompt"
        await model.importAttachments([.image(try DemoArtwork.image(index: 0), name: "Room")])
        let ids = model.referenceIDs
        await model.generate()
        #expect(model.prompt == "Keep my room reference and this prompt")
        #expect(model.referenceIDs == ids && ids.count == 1)
        #expect(model.projectBatches.isEmpty)
        #expect(model.errorMessage != nil)
        let saved = try #require(try await fixture.library.snapshot().projects.first)
        #expect(saved.prompt == model.prompt && saved.referenceIDs == ids)
    }
}

@MainActor private struct ConversationFixture {
    let root: URL
    let library: LibraryStore
    let model: WorkspaceModel
    init(rejectSend: Bool = false) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("brainstorm-conversation-\(UUID())")
        library = try LibraryStore(url: root.appendingPathComponent("library.sqlite"))
        let assets = try AssetStore(root: root.appendingPathComponent("Images"))
        let preferences = try #require(UserDefaults(suiteName: "brainstorm-tests-\(UUID())"))
        model = WorkspaceModel(library: library, assetStore: assets,
                               credentials: ConversationCredentials(reject: rejectSend),
                               providers: ProviderRegistry(providers: [.chatGPT: DemoProvider()]), preferences: preferences)
    }
}

private struct ConversationCredentials: CredentialStore {
    let reject: Bool
    func credential(for provider: ProviderID) async throws -> ProviderCredential {
        if reject { throw BrainstormError.invalid("Sign in to continue.") }
        return .apiKey("offline-demo")
    }
}
