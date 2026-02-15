import AppKit
import ImageIO

/// Decodes GIF files using ImageIO and drives frame animation via a timer.
final class GifAnimator {

    /// Called on each new frame.
    var onFrame: ((NSImage) -> Void)?

    private var frames: [(image: NSImage, duration: TimeInterval)] = []
    private var currentIndex = 0
    private var timer: DispatchSourceTimer?

    // MARK: - Public

    /// Load a GIF from disk. Returns false if the file cannot be decoded.
    @discardableResult
    func load(from url: URL) -> Bool {
        stop()
        frames.removeAll()
        currentIndex = 0

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return false }

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let duration = frameDuration(at: i, source: source)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            frames.append((nsImage, duration))
        }

        guard !frames.isEmpty else { return false }

        // Single-frame GIF: just emit the image, no timer needed.
        if frames.count == 1 {
            onFrame?(frames[0].image)
            return true
        }

        startTimer()
        return true
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Private

    private func startTimer() {
        guard !frames.isEmpty else { return }

        currentIndex = 0
        onFrame?(frames[0].image)
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        let delay = frames[currentIndex].duration
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + delay)
        t.setEventHandler { [weak self] in
            self?.advanceFrame()
        }
        t.resume()
        timer = t
    }

    private func advanceFrame() {
        currentIndex = (currentIndex + 1) % frames.count
        onFrame?(frames[currentIndex].image)
        scheduleNextFrame()
    }

    /// Extract per-frame delay from GIF metadata (default 0.1s).
    private func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifDict = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }

        // Prefer unclamped delay, fall back to standard delay.
        if let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
            return unclamped
        }
        if let delay = gifDict[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
            return delay
        }
        return 0.1
    }
}
