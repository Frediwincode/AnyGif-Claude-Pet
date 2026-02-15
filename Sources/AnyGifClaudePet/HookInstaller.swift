import Foundation

/// Installs / uninstalls the Claude Code hook script into ~/.claude/settings.json.
enum HookInstaller {

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path
    private static var hookInstallDir: String { "\(home)/.claude-pet" }
    private static var hookScriptDest: String { "\(hookInstallDir)/claude-pet-hook.sh" }
    private static var claudeSettingsPath: String { "\(home)/.claude/settings.json" }

    /// The hook command that gets registered in Claude settings.
    private static var hookCommand: String { "\(hookScriptDest)" }

    // MARK: - Public

    /// Check if hooks are already installed in ~/.claude/settings.json.
    static func isInstalled() -> Bool {
        guard let settings = readClaudeSettings() else { return false }
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }

        // Check all hook arrays for our script path.
        for (_, value) in hooks {
            if let arr = value as? [[String: Any]] {
                for entry in arr {
                    // Check nested format: { hooks: [{command: "..."}], matcher: "" }
                    if let innerHooks = entry["hooks"] as? [[String: Any]] {
                        for h in innerHooks {
                            if let cmd = h["command"] as? String, cmd.contains("claude-pet-hook.sh") {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    /// Install the hook script and register it in Claude settings.
    static func install() throws {
        // 1. Copy hook script to ~/.claude-pet/
        let fm = FileManager.default
        try fm.createDirectory(atPath: hookInstallDir, withIntermediateDirectories: true)

        // Find the bundled hook script next to the executable.
        let execPath = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let execDir = (execPath as NSString).deletingLastPathComponent
        let candidatePaths = [
            Bundle.main.resourcePath.map { "\($0)/claude-pet-hook.sh" },
            Optional("\(execDir)/../HookScript/claude-pet-hook.sh"),
            Optional("\(execDir)/HookScript/claude-pet-hook.sh"),
            // Fallback: check project structure relative to build dir.
            Optional("\(execDir)/../../HookScript/claude-pet-hook.sh"),
        ].compactMap { $0 }

        var sourceScript: String?
        for path in candidatePaths {
            let resolved = (path as NSString).standardizingPath
            if fm.fileExists(atPath: resolved) {
                sourceScript = resolved
                break
            }
        }

        guard let scriptSource = sourceScript else {
            throw HookError.scriptNotFound
        }

        // Copy (overwrite if exists).
        if fm.fileExists(atPath: hookScriptDest) {
            try fm.removeItem(atPath: hookScriptDest)
        }
        try fm.copyItem(atPath: scriptSource, toPath: hookScriptDest)

        // Make executable.
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptDest)

        // 2. Register in ~/.claude/settings.json
        try registerHooks()
    }

    /// Remove hooks from ~/.claude/settings.json.
    static func uninstall() throws {
        guard var settings = readClaudeSettings() else { return }
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        // Remove our entries from each hook array.
        for (key, value) in hooks {
            if var arr = value as? [[String: Any]] {
                arr.removeAll { entry in
                    if let innerHooks = entry["hooks"] as? [[String: Any]] {
                        return innerHooks.contains { ($0["command"] as? String)?.contains("claude-pet-hook.sh") == true }
                    }
                    return (entry["command"] as? String)?.contains("claude-pet-hook.sh") == true
                }
                hooks[key] = arr
            }
        }

        settings["hooks"] = hooks
        try writeClaudeSettings(settings)
    }

    // MARK: - Private

    private static func registerHooks() throws {
        var settings = readClaudeSettings() ?? [:]
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]

        let hookEntry: [String: Any] = [
            "hooks": [
                ["type": "command", "command": hookCommand]
            ],
            "matcher": "",
        ]

        // Hook events we want to listen to.
        let hookEvents = ["PreToolUse", "PostToolUse", "Stop", "Notification"]

        for event in hookEvents {
            var arr = (hooks[event] as? [[String: Any]]) ?? []

            // Remove any existing entries referencing our script (clean reinstall).
            arr.removeAll { entry in
                // Match nested format.
                if let innerHooks = entry["hooks"] as? [[String: Any]] {
                    return innerHooks.contains { ($0["command"] as? String)?.contains("claude-pet-hook.sh") == true }
                }
                // Match old flat format.
                return (entry["command"] as? String)?.contains("claude-pet-hook.sh") == true
            }

            arr.append(hookEntry)
            hooks[event] = arr
        }

        settings["hooks"] = hooks
        try writeClaudeSettings(settings)
    }

    private static func readClaudeSettings() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: claudeSettingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func writeClaudeSettings(_ settings: [String: Any]) throws {
        let dir = (claudeSettingsPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: claudeSettingsPath), options: .atomic)
    }

    enum HookError: LocalizedError {
        case scriptNotFound

        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "Could not find claude-pet-hook.sh in the app bundle."
            }
        }
    }
}
