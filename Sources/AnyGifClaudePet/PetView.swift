import AppKit
import QuartzCore

/// NSView that renders the current GIF frame. Falls back to an expressive placeholder circle.
final class PetView: NSView {

    /// Current pet state, used for placeholder animations.
    var petState: PetState = .idle {
        didSet {
            if currentFrame == nil { startPlaceholderAnimation() }
        }
    }

    /// The current frame to display. Setting this triggers a cross-fade transition.
    var currentFrame: NSImage? {
        didSet {
            if currentFrame !== oldValue {
                animateCrossFade()
            }
        }
    }

    /// Sublayer for placeholder animations.
    private var placeholderTimer: Timer?
    private var animationPhase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    // MARK: - Cross-fade transition

    private func animateCrossFade() {
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        if let image = currentFrame {
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            drawPlaceholder(in: ctx)
        }
    }

    /// Draw an expressive placeholder circle based on the current pet state.
    private func drawPlaceholder(in ctx: CGContext) {
        let inset: CGFloat = 8
        let baseRect = bounds.insetBy(dx: inset, dy: inset)

        // Apply state-specific transform
        var rect = baseRect
        let cx = rect.midX
        let cy = rect.midY
        let r = rect.width / 2

        ctx.saveGState()

        switch petState {
        case .idle:
            // Gentle breathing: scale oscillation
            let scale = 1.0 + 0.03 * sin(animationPhase)
            let offset = rect.width * (1.0 - scale) / 2
            rect = rect.insetBy(dx: offset, dy: offset)

        case .thinking:
            break // eyes handled below

        case .working:
            // Slight shake
            let shakeX = 2.0 * sin(animationPhase * 3)
            ctx.translateBy(x: shakeX, y: 0)

        case .happy:
            // Jump up
            let jumpY = 6.0 * abs(sin(animationPhase))
            ctx.translateBy(x: 0, y: jumpY)

        case .sad:
            // Droop down
            let droopY = -4.0 * abs(sin(animationPhase * 0.5))
            ctx.translateBy(x: 0, y: droopY)

        case .celebrating:
            // Spin
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: animationPhase)
            ctx.translateBy(x: -cx, y: -cy)

        case .sleeping:
            break
        }

        // Body
        ctx.setFillColor(NSColor.systemPurple.withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: rect)

        let drawCx = rect.midX
        let drawCy = rect.midY
        let drawR = rect.width / 2

        // Eyes
        ctx.setFillColor(NSColor.white.cgColor)
        let eyeSize: CGFloat = drawR * 0.15

        if petState == .sleeping {
            // Closed eyes (horizontal lines)
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(2)
            let leftEyeX = drawCx - drawR * 0.3
            let rightEyeX = drawCx + drawR * 0.3
            let eyeY = drawCy + drawR * 0.2
            ctx.move(to: CGPoint(x: leftEyeX - eyeSize, y: eyeY))
            ctx.addLine(to: CGPoint(x: leftEyeX + eyeSize, y: eyeY))
            ctx.move(to: CGPoint(x: rightEyeX - eyeSize, y: eyeY))
            ctx.addLine(to: CGPoint(x: rightEyeX + eyeSize, y: eyeY))
            ctx.strokePath()
        } else if petState == .thinking {
            // Eyes look left-right
            let lookOffset = drawR * 0.1 * sin(animationPhase * 2)
            ctx.fillEllipse(in: CGRect(x: drawCx - drawR * 0.3 - eyeSize + lookOffset,
                                        y: drawCy + drawR * 0.15,
                                        width: eyeSize * 2, height: eyeSize * 2))
            ctx.fillEllipse(in: CGRect(x: drawCx + drawR * 0.3 - eyeSize + lookOffset,
                                        y: drawCy + drawR * 0.15,
                                        width: eyeSize * 2, height: eyeSize * 2))
        } else {
            // Normal eyes
            ctx.fillEllipse(in: CGRect(x: drawCx - drawR * 0.3 - eyeSize,
                                        y: drawCy + drawR * 0.15,
                                        width: eyeSize * 2, height: eyeSize * 2))
            ctx.fillEllipse(in: CGRect(x: drawCx + drawR * 0.3 - eyeSize,
                                        y: drawCy + drawR * 0.15,
                                        width: eyeSize * 2, height: eyeSize * 2))
        }

        // Mouth
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(2)
        if petState == .sad {
            // Frown
            ctx.addArc(center: CGPoint(x: drawCx, y: drawCy - drawR * 0.05),
                       radius: drawR * 0.25,
                       startAngle: .pi * 1.2, endAngle: .pi * 1.8, clockwise: false)
        } else {
            // Smile
            ctx.addArc(center: CGPoint(x: drawCx, y: drawCy - drawR * 0.1),
                       radius: drawR * 0.25,
                       startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: true)
        }
        ctx.strokePath()

        // Sleeping: draw "zzz" text
        if petState == .sleeping {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: drawR * 0.35, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            ]
            let zzzOffset = 3.0 * sin(animationPhase)
            let str = "zzz" as NSString
            str.draw(at: CGPoint(x: drawCx + drawR * 0.3, y: drawCy + drawR * 0.5 + zzzOffset), withAttributes: attrs)
        }

        ctx.restoreGState()
    }

    // MARK: - Placeholder animation timer

    func startPlaceholderAnimation() {
        guard placeholderTimer == nil else { return }
        placeholderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.currentFrame == nil else {
                self?.stopPlaceholderAnimation()
                return
            }
            self.animationPhase += 0.08
            self.needsDisplay = true
        }
    }

    func stopPlaceholderAnimation() {
        placeholderTimer?.invalidate()
        placeholderTimer = nil
    }

    // MARK: - Right-click menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Pet")
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.openSettings), keyEquivalent: "")
        settingsItem.target = NSApp.delegate
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    override var acceptsFirstResponder: Bool { true }
}
