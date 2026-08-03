import Foundation

struct TestConfig {
    static let shared = TestConfig()

    let openAIAPIKey: String?
    let hasOpenAIKey: Bool
    let anthropicAPIKey: String?
    let hasAnthropicKey: Bool

    private init() {
        openAIAPIKey = Self.loadEnvValue(forKey: "OPENAI_API_KEY")
        hasOpenAIKey = openAIAPIKey != nil && !openAIAPIKey!.isEmpty
        anthropicAPIKey = Self.loadEnvValue(forKey: "ANTHROPIC_API_KEY")
        hasAnthropicKey = anthropicAPIKey != nil && !anthropicAPIKey!.isEmpty
    }

    private static func loadEnvValue(forKey key: String) -> String? {
        // First check process environment
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        // Then check .env.local file. Tolerant of optional whitespace around
        // `=`, quoted values (single or double), comments, and blank lines —
        // not just the strict `KEY=value` shape.
        let envPath = ".env.local"
        guard let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }

        for rawLine in contents.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else {
                continue
            }

            let lineKey = line[line.startIndex..<separator].trimmingCharacters(in: .whitespaces)
            guard lineKey == key else { continue }

            var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, let last = value.last, first == last, (first == "\"" || first == "'") {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }

        return nil
    }

    static let timeout: TimeInterval = 30.0
}
