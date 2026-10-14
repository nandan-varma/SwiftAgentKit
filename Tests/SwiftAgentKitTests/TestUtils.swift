import XCTest
#if canImport(FoundationModels)
import FoundationModels
#endif
import Foundation
import SwiftAgentKit
import JSONSchema

struct TestObject: Codable, Equatable {
    let example: String
    let value: Int
}

struct TestUtils {
    /// Apple Intelligence isn't available on CI runners (or ineligible devices),
    /// so tests that hit FoundationProvider can only run where the system model is ready.
    static func skipUnlessFoundationModelAvailable() throws {
        #if canImport(FoundationModels)
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            throw XCTSkip("Foundation model unavailable: \(reason)")
        }
        #else
        throw XCTSkip("FoundationModels not available on this platform")
        #endif
    }

    static func createTestMessage(content: String, role: MessageRole = .user) -> Message {
        switch role {
        case .user:
            return .user(content)
        case .assistant:
            return .assistant(content: content, toolCalls: nil)
        case .system:
            return .system(content)
        case .tool:
            return .tool(id: "test", content: content)
        }
    }

    static func createMathTool() -> MathTool {
        return MathTool()
    }

    static func createWeatherTool() -> WeatherTool {
        return WeatherTool()
    }

    static func createTestSchema() -> JSONSchema {
        return .object(
            description: "Test object",
            properties: [
                "example": .string(description: "An example"),
                "value": .integer(description: "A value")
            ],
            required: ["example"]
        )
    }

    enum MessageRole {
        case user, assistant, system, tool
    }
}

struct WeatherResponse: Codable {
    let location: String
    let temperature: String
}

struct MathResponse: Codable {
    let expression: String
    let result: Double
}