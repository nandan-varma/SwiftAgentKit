import Foundation
import JSONSchema

public enum Message {
    case system(String)
    case user(String)
    case assistant(content: String, toolCalls: [ToolCall]?)
    case tool(id: String, content: String)
}

public struct ToolDescriptor {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema?  // Optional for now, to be added to Tool
}

public struct ToolResult {
    public let content: String
    public let data: [String: Any]?
    public let structuredOutput: Any?
}

public struct LLMResponse {
    public let content: String
    public let toolCalls: [ToolCall]?
}

public struct ToolCall {
    public let id: String
    public let name: String
    public let arguments: [String: Any]
}

public struct LLMStreamChunk {
    public let text: String
    public let isComplete: Bool
}

