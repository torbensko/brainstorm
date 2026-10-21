import Foundation
import Testing
@testable import BrainstormCore

@Test func automaticTitlesFollowDraftThenKeepTheFirstMessage() async throws {
    let fixture = try Fixture()
    var project = Project()
    for draft in ["S", "Show some", "Show some of the ways I could style this room"] {
        project.prompt = draft
        project.updateAutomaticTitle()
        try await fixture.library.saveProject(project)
        project = try #require(try await fixture.library.snapshot().projects.first)
        #expect(project.title == PromptBuilder.title(from: draft))
        #expect(project.titleMode == .automatic)
    }
    let firstMessage = project.prompt
    project.prompt = ""
    project.updateAutomaticTitle(firstMessage: firstMessage)
    #expect(project.title == "Show some of the ways I could")
    project.prompt = "Make it brighter"
    project.updateAutomaticTitle(firstMessage: firstMessage)
    #expect(project.title == "Show some of the ways I could")

    project.title = "Living room"
    project.titleMode = .custom
    try await fixture.library.saveProject(project)
    let reopened = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
    project = try #require(try await reopened.snapshot().projects.first)
    project.updateAutomaticTitle(firstMessage: firstMessage)
    #expect(project.title == "Living room")
    #expect(project.titleMode == .custom)
}

@Test func legacyOneLetterTitleIsRepairedWithoutRenamingOtherConversations() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("brainstorm-title-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("library.sqlite")
    // Start with the real schema, then remove the new field to reproduce an older library.
    _ = try LibraryStore(url: url)
    let db = try SQLiteConnection(url: url)
    try db.execute("ALTER TABLE projects DROP COLUMN title_mode")
    try db.execute("PRAGMA user_version = 1")
    let prompt = "Show some of the ways I could style this room"
    for title in ["S", "Living room", "X"] {
        try db.execute("INSERT INTO projects(id,title,prompt,created_at,updated_at) VALUES(?,?,?,?,?)",
                       [.id(UUID()), .text(title), .text(prompt), .number(0), .number(0)])
    }
    let migrated = try LibraryStore(url: url)
    let projects = try await migrated.snapshot().projects
    #expect(projects.contains { $0.title == PromptBuilder.title(from: prompt) && $0.titleMode == .automatic })
    #expect(projects.contains { $0.title == "Living room" && $0.titleMode == .custom })
    #expect(projects.contains { $0.title == "X" && $0.titleMode == .custom })
    #expect(projects.allSatisfy { $0.prompt == prompt })
    let reopened = try LibraryStore(url: url)
    #expect(try await reopened.snapshot().projects == projects)
}
