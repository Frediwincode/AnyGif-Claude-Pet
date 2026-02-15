import AppKit

/// Transparent, borderless, always-on-top window for the desktop pet.
final class PetWindow: NSWindow {

    init(size: CGFloat = 120) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = NSPoint(x: screenFrame.maxX - size - 50,
                             y: screenFrame.minY + 50)

        super.init(contentRect: NSRect(origin: origin, size: NSSize(width: size, height: size)),
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = true
        hasShadow = false
    }
}
