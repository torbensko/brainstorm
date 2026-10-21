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
    try db.execute("ALTER TABLE projects DROP COLUMN suggested_title")
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

@Test func suggestedNamesSurviveDraftSavesAndRespectManualRenames() async throws {
    let fixture = try Fixture()
    var project = Project(prompt: "Create a cat logo with four different styles")
    project.updateAutomaticTitle()
    try await fixture.library.saveProject(project)
    try await fixture.library.suggestTitle("Four-style cat logo", for: project.id)
    // This copy predates the generated name, as an in-flight draft save might.
    project.prompt = "Make the cat friendlier"
    try await fixture.library.saveProject(project)
    try await fixture.library.suggestTitle("An unwanted second name", for: project.id)
    let reopened = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
    var saved = try #require(try await reopened.snapshot().projects.first)
    #expect(saved.displayTitle == "Four-style cat logo")
    #expect(saved.prompt == project.prompt)
    saved.title = "Brainstorm icon"
    saved.titleMode = .custom
    try await reopened.saveProject(saved)
    #expect(try await reopened.snapshot().projects.first?.displayTitle == "Brainstorm icon")

    let renamed = Project(title: "My room", titleMode: .custom)
    try await reopened.saveProject(renamed)
    try await reopened.suggestTitle("Room styling ideas", for: renamed.id)
    let untouched = try #require(try await reopened.snapshot().projects.first { $0.id == renamed.id })
    #expect(untouched.displayTitle == "My room" && untouched.suggestedTitle == nil)
}

@Test func versionTwoLibraryGainsNamesWithoutChangingItsExistingConversations() async throws {
    let fixture = try Fixture()
    let project = Project(title: "Personal name", titleMode: .custom)
    try await fixture.library.saveProject(project)
    let before = try await fixture.library.snapshot().projects
    let db = try SQLiteConnection(url: fixture.root.appendingPathComponent("library.sqlite"))
    try db.execute("ALTER TABLE projects DROP COLUMN suggested_title")
    try db.execute("PRAGMA user_version = 2")
    let migrated = try LibraryStore(url: fixture.root.appendingPathComponent("library.sqlite"))
    #expect(try await migrated.snapshot().projects == before)
}
