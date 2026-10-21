import AppKit
import SwiftUI

/// SwiftUI places custom actions after the sidebar's tracking separator.
/// Keep this action on the sidebar side of that native separator instead. AppKit
/// still owns the toolbar, glass, divider tracking, and collapsed-sidebar layout.
struct SidebarToolbarPlacement: NSViewRepresentable {
    static let actionID = "brainstorm.newConversation"
    func makeNSView(context: Context) -> PlacementView { PlacementView() }
    func updateNSView(_ view: PlacementView, context: Context) { view.schedulePlacement() }

    final class PlacementView: NSView {
        private var placementScheduled = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            schedulePlacement()
        }

        override func layout() {
            super.layout()
            schedulePlacement()
        }

        func schedulePlacement() {
            guard window != nil, !placementScheduled else { return }
            placementScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.placementScheduled = false
                self.placeInSidebar()
            }
        }

        private func placeInSidebar() {
            guard let toolbar = window?.toolbar,
                  let actionIndex = toolbar.items.firstIndex(where: { $0.itemIdentifier.rawValue == SidebarToolbarPlacement.actionID }),
                  let separatorIndex = toolbar.items.firstIndex(where: { $0 is NSTrackingSeparatorToolbarItem }),
                  separatorIndex < actionIndex else { return }
            let identifier = toolbar.items[actionIndex].itemIdentifier
            toolbar.removeItem(at: actionIndex)
            toolbar.insertItem(withItemIdentifier: identifier, at: separatorIndex)
        }
    }
}
