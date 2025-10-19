import Foundation

struct TestConfig {
    static let shared = TestConfig()

    let openAIAPIKey: String?
    let hasOpenAIKey: Bool

    private init() {
        openAIAPIKey = Self.loadEnvValue(forKey: "OPENAI_API_KEY")
        hasOpenAIKey = openAIAPIKey != nil && !openAIAPIKey!.isEmpty
    }

    private static func loadEnvValue(forKey key: String) -> String? {
        // First check process environment
        if let value = ProcessInfo.processInfo.environment[key] {
            return value
        }

        // Then check .env.local file
        let envPath = ".env.local"
        guard let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }

        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("\(key)=") {
                let value = String(trimmed.dropFirst(key.count + 1))
                return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        return nil
    }

    static let defaultModel = "gpt-3.5-turbo"
    static let timeout: TimeInterval = 30.0
}