import Foundation

/// Calls Google Gemini API to generate a vibe summary from daily stats.
final class GeminiAPIService {

    enum GeminiError: Error, LocalizedError {
        case missingAPIKey
        case networkError(String)
        case invalidResponse
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Google API Key is not configured."
            case .networkError(let msg): return "Network error: \(msg)"
            case .invalidResponse: return "Invalid response from Gemini API."
            case .apiError(let msg): return "Gemini API error: \(msg)"
            }
        }
    }

    /// Generate a vibe summary string from today's stats using Gemini 2.0 Flash.
    func generateVibeSummary(stats: DayStats, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let prompt = """
        你是一个有趣的桌面宠物，请根据以下 Claude Code 使用数据，用轻松幽默的中文写一段100字以内的'每日 vibe 锐评'，要有个性有态度：
        今日数据：工具调用 \(stats.totalToolCalls) 次，Bash \(stats.bashCount) 次，编辑 \(stats.editCount) 次，阅读 \(stats.readCount) 次，活跃时长 \(stats.activeDurationMinutes) 分钟，报错 \(stats.errorCount) 次
        """

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiError.networkError("Invalid URL") }

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode): \(bodyStr)")
        }

        // Parse response JSON.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
