import Foundation
@preconcurrency import JSONSchema
@preconcurrency import SwiftyJSON

/// A single turn in a conversation with a `LanguageModelProvider`.
public enum Message: Sendable {
    /// System-level instructions for the model.
    case system(String)
    /// A message from the user.
    case user(String)
    /// A response from the model, optionally including tool calls it wants executed.
    case assistant(content: String, toolCalls: [ToolCall]?)
    /// The result of executing a tool, matched back to its call by `id`.
    case tool(id: String, content: String)
}

/// The schema-only description of a `Tool`, as sent to a `LanguageModelProvider`
/// (see `Tool.descriptor`).
public struct ToolDescriptor: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema
}

/// The outcome of executing a `Tool`.
public struct ToolResult: Sendable {
    /// Human/model-readable text summarizing the result, fed back into the
    /// conversation as a `Message.tool` entry.
    public let content: String
    /// Optional structured fields, for callers that want typed access beyond `content`.
    public let data: [String: JSON]?
    /// Optional structured output as a single JSON value, per `Tool.outputSchema`.
    public let structuredOutput: JSON?

    public init(content: String, data: [String: JSON]? = nil, structuredOutput: JSON? = nil) {
        self.content = content
        self.data = data
        self.structuredOutput = structuredOutput
    }
}

/// A `LanguageModelProvider`'s response to `generateText(messages:tools:)`.
public struct LLMResponse: Sendable {
    public let content: String
    /// Tool calls the provider wants the `Agent` loop to execute. Nil when the
    /// provider has nothing pending (either it made no tool calls, or — as with
    /// `FoundationProvider` — it already executed them internally; see
    /// `executedToolResults`).
    public let toolCalls: [ToolCall]?
    /// Tools the provider already executed internally while resolving this turn
    /// (e.g. FoundationModels' session-managed tool calling), as opposed to
    /// `toolCalls`, which are pending calls the `Agent` loop must still execute.
    public let executedToolResults: [ToolResult]?

    public init(content: String, toolCalls: [ToolCall]? = nil, executedToolResults: [ToolResult]? = nil) {
        self.content = content
        self.toolCalls = toolCalls
        self.executedToolResults = executedToolResults
    }
}

/// A request from the model to execute a `Tool`, pending execution by the `Agent` loop.
public struct ToolCall: Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: JSON]

    public init(id: String, name: String, arguments: [String: JSON]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// A single piece of a streamed `LanguageModelProvider` response.
public struct LLMStreamChunk: Sendable {
    /// The incremental text for this chunk (empty on the final `isComplete` chunk).
    public let text: String
    /// Whether this is the last chunk in the stream.
    public let isComplete: Bool
}
