import Foundation

/// Persisted settings structure.
private struct Settings: Codable {
    var gifMapping: [String: String] = [:]  // PetState.rawValue -> file path
    var googleApiKey: String?
    var petSize: CGFloat?
}

/// Maps each PetState to an optional GIF file URL. Persists to disk as JSON.
final class GifAssignment {

    private var settings = Settings()
    private var mapping: [String: String] {
        get { settings.gifMapping }
        set { settings.gifMapping = newValue }
    }
    private let settingsURL: URL

    /// Google API key for Gemini calls.
    var googleApiKey: String? {
        get { settings.googleApiKey }
        set { settings.googleApiKey = newValue; save() }
    }

    /// Pet window size in points.
    var petSize: CGFloat {
        get { settings.petSize ?? 120 }
        set { settings.petSize = newValue; save() }
    }

    init() {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AnyGifClaudePet")
        settingsURL = appSupport.appendingPathComponent("settings.json")
        load()
    }

    /// Return the GIF URL assigned to the given state, or nil.
    func gifURL(for state: PetState) -> URL? {
        guard let path = mapping[state.rawValue], !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        // Only return if the file still exists.
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Assign a GIF file URL to a state.
    func setGif(url: URL, for state: PetState) {
        mapping[state.rawValue] = url.path
        save()
    }

    /// Clear the GIF assignment for a state.
    func clearGif(for state: PetState) {
        mapping.removeValue(forKey: state.rawValue)
        save()
    }

    // MARK: - Persistence

    func save() {
        let dir = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: settingsURL) else { return }
        // Try loading new Settings format first, fall back to legacy mapping.
        if let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
            settings = Settings(gifMapping: legacy)
        }
    }
}
