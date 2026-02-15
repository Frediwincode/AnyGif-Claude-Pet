import Foundation

/// Model representing a generated vibe summary for a given day.
struct VibeSummary: Codable {
    let date: String
    let stats: DayStats
    let summary: String
    let generatedAt: Date
}
