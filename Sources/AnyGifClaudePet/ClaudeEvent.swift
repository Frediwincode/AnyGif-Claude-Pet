import Foundation

/// Represents a Claude Code hook event read from ~/.claude-pet/current-event.json.
struct ClaudeEvent: Codable {
    let event: String        // "PreToolUse", "PostToolUse", "Stop", "Notification"
    let tool: String?        // tool name if applicable
    let timestamp: TimeInterval?
    let sessionId: String?
}
