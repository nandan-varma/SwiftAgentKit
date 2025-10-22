import Foundation
@preconcurrency import JSONSchema
@preconcurrency import SwiftyJSON

public enum Message: Sendable {
    case system(String)
    case user(String)
    case assistant(content: String, toolCalls: [ToolCall]?)
    case tool(id: String, content: String)
}

public struct ToolDescriptor: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema
}

public struct ToolResult: Sendable {
    public let content: String
    public let data: [String: JSON]?
    public let structuredOutput: JSON?
}

public struct LLMResponse: Sendable {
    public let content: String
    public let toolCalls: [ToolCall]?
}

public struct ToolCall: Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: JSON]
}

public struct LLMStreamChunk: Sendable {
    public let text: String
    public let isComplete: Bool
}
