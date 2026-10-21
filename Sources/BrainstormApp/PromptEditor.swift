import AppKit
import SwiftUI

/// Intercept attachments before AppKit's default text drop inserts a file path.
struct PromptEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusID: UUID?
    let onAttachments: ([ReferenceAttachment]) -> Void
    let onError: (Error) -> Void
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = PromptScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 60))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        let editor = AttachmentTextView(frame: scroll.contentView.bounds)
        editor.minSize = NSSize(width: 0, height: 60)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: editor.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainerInset = NSSize(width: 0, height: 3)
        editor.font = .systemFont(ofSize: 15)
        editor.textColor = .labelColor
        editor.delegate = context.coordinator
        editor.registerForDraggedTypes(ReferenceDrop.pasteboardTypes)
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? AttachmentTextView else { return }
        editor.isEditable = context.environment.isEnabled
        editor.onAttachments = onAttachments
        editor.onError = onError
        editor.onSubmit = onSubmit
        editor.setAccessibilityLabel(placeholder)
        if editor.string != text {
            let selected = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(selected.location, (text as NSString).length), length: 0))
        }
        if context.coordinator.focusID != focusID {
            context.coordinator.focusID = focusID
            if focusID != nil {
                DispatchQueue.main.async { [weak editor] in
                    guard let editor else { return }
                    editor.window?.makeFirstResponder(editor)
                }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView scroll: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        // SwiftUI probes multiple widths. Measuring must never resize the live text container.
        let font = NSFont.systemFont(ofSize: 15)
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        let lineHeight = layout.defaultLineHeight(for: font)
        let contentHeight = max(layout.usedRect(for: container).maxY, layout.extraLineFragmentRect.maxY)
        let height = min(max(contentHeight, lineHeight * 3), lineHeight * 7) + 6
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptEditor
        var focusID: UUID?
        init(_ parent: PromptEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            if let editor = notification.object as? NSTextView { parent.text = editor.string }
        }
    }
}

final class PromptScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let editor = documentView as? NSTextView else { return }
        let width = contentView.bounds.width
        if editor.frame.width != width {
            editor.setFrameSize(NSSize(width: width, height: max(editor.frame.height, contentView.bounds.height)))
        }
        editor.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    }
}

final class AttachmentTextView: NSTextView {
    var onAttachments: ([ReferenceAttachment]) -> Void = { _ in }
    var onError: (Error) -> Void = { _ in }
    var onSubmit: () -> Void = {}

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        ReferenceDrop.containsAttachments(sender.draggingPasteboard) ? .copy : super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        ReferenceDrop.containsAttachments(sender.draggingPasteboard) ? .copy : super.draggingUpdated(sender)
    }
    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        ReferenceDrop.containsAttachments(sender.draggingPasteboard) || super.prepareForDragOperation(sender)
    }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        consumeAttachments(from: sender.draggingPasteboard) || super.performDragOperation(sender)
    }
    override func paste(_ sender: Any?) {
        if !consumeAttachments(from: .general) { super.paste(sender) }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && event.modifierFlags.contains(.command) { onSubmit() }
        else { super.keyDown(with: event) }
    }

    @discardableResult func consumeAttachments(from board: NSPasteboard) -> Bool {
        guard ReferenceDrop.containsAttachments(board) else { return false }
        do { onAttachments(try ReferenceDrop.read(board)) }
        catch { onError(error) }
        // Even unreadable attachments are consumed: never insert their paths as prompt text.
        return true
    }
}
