import Foundation

public enum Message {
    case system(String)
    case user(String)
    case assistant(String)
    case tool(name: String, content: String)
}

public struct ToolDescriptor {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
}

public struct ToolResult {
    public let content: String
    public let data: [String: Any]?
}

public struct LLMResponse {
    public let content: String
    public let toolCalls: [ToolCall]?
}

public struct ToolCall {
    public let name: String
    public let arguments: [String: Any]
}

public struct LLMStreamChunk {
    public let text: String
    public let isComplete: Bool
}

public indirect enum JSONSchema {
    case string(description: String? = nil)
    case number(description: String? = nil)
    case boolean(description: String? = nil)
    case object([String: JSONSchema])
    case array(JSONSchema, description: String? = nil)
}