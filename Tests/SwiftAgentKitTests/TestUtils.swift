import Foundation
import SwiftAgentKit
import JSONSchema

struct TestObject: Codable, Equatable {
    let example: String
    let value: Int
}

struct TestUtils {
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
                "name": .string(description: "A name"),
                "value": .integer(description: "A value")
            ],
            required: ["name"]
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