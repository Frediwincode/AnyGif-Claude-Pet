import Foundation

/// Daily statistics derived from Claude Code hook events.
struct DayStats: Codable {
    let totalToolCalls: Int
    let bashCount: Int
    let editCount: Int
    let readCount: Int
    let activeDurationMinutes: Int
    let errorCount: Int
    let date: String  // "yyyy-MM-dd"
}

/// Reads ~/.claude-pet/events.jsonl and computes daily usage statistics.
final class EventLogger {

    private let eventsFileURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        eventsFileURL = home.appendingPathComponent(".claude-pet/events.jsonl")
    }

    /// Compute stats for today (midnight to now).
    func todayStats() -> DayStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        let events = loadTodayEvents(dateString: todayString)

        var bashCount = 0
        var editCount = 0
        var readCount = 0
        var errorCount = 0
        var timestamps: [TimeInterval] = []

        for event in events {
            timestamps.append(event.timestamp)

            let tool = (event.tool ?? "").lowercased()
            if tool.contains("bash") { bashCount += 1 }
            if tool.contains("edit") || tool.contains("write") { editCount += 1 }
            if tool.contains("read") { readCount += 1 }

            // Count events with event type containing "error".
            if event.event.lowercased().contains("error") {
                errorCount += 1
            }
        }

        let totalToolCalls = events.count
        let activeDuration: Int
        if let first = timestamps.min(), let last = timestamps.max(), last > first {
            activeDuration = Int((last - first) / 60.0)
        } else {
            activeDuration = 0
        }

        return DayStats(
            totalToolCalls: totalToolCalls,
            bashCount: bashCount,
            editCount: editCount,
            readCount: readCount,
            activeDurationMinutes: activeDuration,
            errorCount: errorCount,
            date: todayString
        )
    }

    /// Remove event lines older than the specified number of days.
    func cleanupOldEvents(daysToKeep: Int = 30) {
        guard FileManager.default.fileExists(atPath: eventsFileURL.path),
              let content = try? String(contentsOf: eventsFileURL, encoding: .utf8) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-Double(daysToKeep) * 86400).timeIntervalSince1970
        let decoder = JSONDecoder()

        let kept = content.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let event = try? decoder.decode(EventLine.self, from: data) else {
                return false
            }
            return event.timestamp >= cutoff
        }

        let result = kept.joined(separator: "\n") + (kept.isEmpty ? "" : "\n")
        try? result.write(to: eventsFileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Private

    /// JSON structure for each line in events.jsonl.
    private struct EventLine: Codable {
        let event: String
        let tool: String?
        let timestamp: TimeInterval
        let sessionId: String?

        enum CodingKeys: String, CodingKey {
            case event, tool, timestamp
            case sessionId = "sessionId"
        }
    }

    /// Load and filter events matching today's date string.
    private func loadTodayEvents(dateString: String) -> [EventLine] {
        guard FileManager.default.fileExists(atPath: eventsFileURL.path),
              let content = try? String(contentsOf: eventsFileURL, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = todayStart.addingTimeInterval(86400)
        let startTimestamp = todayStart.timeIntervalSince1970
        let endTimestamp = todayEnd.timeIntervalSince1970

        var results: [EventLine] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let event = try? decoder.decode(EventLine.self, from: data) else {
                continue
            }
            if event.timestamp >= startTimestamp && event.timestamp < endTimestamp {
                results.append(event)
            }
        }
        return results
    }
}
