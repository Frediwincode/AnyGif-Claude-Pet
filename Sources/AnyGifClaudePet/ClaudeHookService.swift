import Foundation

/// Watches ~/.claude-pet/current-event.json for changes using polling.
final class ClaudeHookService {

    typealias EventHandler = (ClaudeEvent) -> Void

    private let filePath: String
    private let directoryPath: String
    private var onEvent: EventHandler?
    private var timer: Timer?
    private var lastModDate: Date?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        directoryPath = "\(home)/.claude-pet"
        filePath = "\(directoryPath)/current-event.json"
    }

    /// Start watching. Calls `handler` on each new event (on main queue).
    func start(handler: @escaping EventHandler) {
        onEvent = handler
        ensureDirectory()

        // Record current mod date so we don't fire on startup.
        lastModDate = modificationDate()
        print("[HOOK] Starting watcher. File: \(filePath)")
        print("[HOOK] File exists: \(FileManager.default.fileExists(atPath: filePath))")
        print("[HOOK] Last mod date: \(String(describing: lastModDate))")

        // Poll every 0.5 seconds.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChange()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func ensureDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryPath) {
            try? fm.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
        }
    }

    private func modificationDate() -> Date? {
        try? FileManager.default.attributesOfItem(atPath: filePath)[.modificationDate] as? Date
    }

    private func checkForChange() {
        guard let currentMod = modificationDate() else { return }

        if lastModDate == nil || currentMod > lastModDate! {
            lastModDate = currentMod
            print("[HOOK] File changed! Reading event...")
            readAndDispatch()
        }
    }

    private func readAndDispatch() {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            print("[HOOK] Could not read file")
            return
        }
        do {
            let event = try JSONDecoder().decode(ClaudeEvent.self, from: data)
            print("[HOOK] Decoded event: \(event.event) tool: \(event.tool ?? "nil")")
            onEvent?(event)
        } catch {
            print("[HOOK] JSON decode error: \(error)")
        }
    }
}
