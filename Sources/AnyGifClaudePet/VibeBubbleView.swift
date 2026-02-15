import AppKit

/// A speech-bubble popup window that displays the vibe summary text.
/// Auto-dismisses after 15 seconds or when clicked.
final class VibeBubbleView {

    private var bubbleWindow: NSPanel?
    private var dismissTimer: Timer?

    /// Show a bubble with the given text, positioned relative to the pet window.
    func show(text: String, relativeTo petWindow: NSWindow) {
        dismiss()

        let maxWidth: CGFloat = 280
        let padding: CGFloat = 16

        // Calculate text size.
        let font = NSFont.systemFont(ofSize: 13)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textRect = (text as NSString).boundingRect(
            with: NSSize(width: maxWidth - padding * 2, height: 400),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        let bubbleWidth = min(maxWidth, textRect.width + padding * 2 + 8)
        let bubbleHeight = textRect.height + padding * 2 + 8

        // Position above the pet window.
        let petFrame = petWindow.frame
        let bubbleX = petFrame.midX - bubbleWidth / 2
        let bubbleY = petFrame.maxY + 10

        let panel = NSPanel(
            contentRect: NSRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false

        // Background view with rounded corners and semi-transparency.
        let backgroundView = BubbleBackgroundView(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
        panel.contentView = backgroundView

        // Text field.
        let textField = NSTextField(wrappingLabelWithString: text)
        textField.font = font
        textField.textColor = .labelColor
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.frame = NSRect(x: padding, y: padding, width: bubbleWidth - padding * 2, height: bubbleHeight - padding * 2)
        textField.autoresizingMask = [.width, .height]
        backgroundView.addSubview(textField)

        // Click to dismiss.
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        backgroundView.addGestureRecognizer(clickGesture)

        panel.orderFront(nil)
        bubbleWindow = panel

        // Auto-dismiss after 15 seconds.
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    /// Dismiss the bubble immediately.
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        bubbleWindow?.orderOut(nil)
        bubbleWindow = nil
    }

    @objc private func handleClick() {
        dismiss()
    }
}

/// Rounded semi-transparent background for the speech bubble.
private final class BubbleBackgroundView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)

        // Semi-transparent background.
        NSColor.windowBackgroundColor.withAlphaComponent(0.92).setFill()
        path.fill()

        // Subtle border.
        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
