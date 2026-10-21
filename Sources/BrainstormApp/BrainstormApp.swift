import SwiftUI
import BrainstormCore

@main
struct BrainstormApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = WorkspaceModel()

    var body: some Scene {
        Window("Brainstorm", id: "workspace") {
            WorkspaceView(model: model)
                .frame(minWidth: 1000, minHeight: 720)
                .task { await model.start() }
        }
        .defaultSize(width: 1360, height: 920)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Concept") { Task { await model.createProject() } }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .pasteboard) {
                Button("Paste Reference Image") { Task { await model.pasteImage() } }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
        Settings { SettingsView(model: model) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
