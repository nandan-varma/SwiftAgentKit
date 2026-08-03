#if canImport(FoundationModels)
import Foundation
import FoundationModels
@preconcurrency import SwiftyJSON
import JSONSchema

/// Bridges SwiftAgentKit's stateless, full-history `LanguageModelProvider` calls
/// onto Apple's stateful `LanguageModelSession`. A fresh session is created per
/// call — reconstructing a `Transcript` from an arbitrary `[Message]` history
/// isn't a well-defined mapping, so instead prior turns are flattened into plain
/// text and passed as part of the prompt. This is a deliberate simplification,
/// not an oversight.
enum FoundationModelsBridge {
    static func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?,
        registeredTools: [String: SwiftAgentKit.Tool]
    ) async throws -> LLMResponse {
        try checkAvailability()
        let (instructions, prompt) = renderPrompt(from: messages)
        let sink = ToolResultSink()
        let toolAdapters = try adapters(for: tools, registeredTools: registeredTools, sink: sink)

        let session = LanguageModelSession(tools: toolAdapters, instructions: instructions)
        let response = try await session.respond(to: prompt)
        let executed = await sink.results
        return LLMResponse(content: response.content, toolCalls: nil, executedToolResults: executed.isEmpty ? nil : executed)
    }

    static func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?,
        registeredTools: [String: SwiftAgentKit.Tool]
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try checkAvailability()
                    let (instructions, prompt) = renderPrompt(from: messages)
                    let sink = ToolResultSink()
                    let toolAdapters = try adapters(for: tools, registeredTools: registeredTools, sink: sink)
                    let session = LanguageModelSession(tools: toolAdapters, instructions: instructions)

                    var previous = ""
                    for try await snapshot in session.streamResponse(to: prompt) {
                        let cumulative = snapshot.content
                        if cumulative.count > previous.count {
                            continuation.yield(LLMStreamChunk(text: String(cumulative.dropFirst(previous.count)), isComplete: false))
                            previous = cumulative
                        }
                    }
                    continuation.yield(LLMStreamChunk(text: "", isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func checkAvailability() throws {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            throw FoundationModelsError.modelUnavailable(String(describing: availability))
        }
    }

    /// Uses FoundationModels' real structured-generation API (`respond(to:schema:)`)
    /// rather than the "ask for JSON in prose, hope it parses" trick the other
    /// providers fall back to — we already have the `DynamicGenerationSchema`
    /// machinery built for tool arguments, so it's reused here for output schemas
    /// too, and produces reliably well-formed JSON.
    static func generateObjectJSON(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?,
        registeredTools: [String: SwiftAgentKit.Tool]
    ) async throws -> String {
        try checkAvailability()
        let (instructions, prompt) = renderPrompt(from: messages)
        let sink = ToolResultSink()
        let toolAdapters = try adapters(for: tools, registeredTools: registeredTools, sink: sink)
        let session = LanguageModelSession(tools: toolAdapters, instructions: instructions)

        let schemaJSON = try outputSchema.asJSON()
        let dynamicSchema = FoundationModelsToolAdapter.dynamicSchema(from: schemaJSON, name: "GeneratedObject")
        let schema = try GenerationSchema(root: dynamicSchema, dependencies: [])

        let response = try await session.respond(to: prompt, schema: schema)
        return response.content.jsonString
    }

    private static func adapters(
        for tools: [ToolDescriptor]?,
        registeredTools: [String: SwiftAgentKit.Tool],
        sink: ToolResultSink
    ) throws -> [FoundationModelsToolAdapter] {
        try (tools ?? []).compactMap { registeredTools[$0.name] }.map {
            try FoundationModelsToolAdapter(wrapped: $0, sink: sink)
        }
    }

    /// FoundationModels' provider protocol is stateless per call (it always
    /// receives the full message history, matching the OpenAI/Anthropic REST
    /// shape) while `LanguageModelSession` is a stateful conversation object.
    /// Rather than rely on the framework's session-resumption APIs (not a
    /// confirmed stable mapping from an arbitrary `[Message]` array), prior
    /// turns are rendered as plain text and appended to the prompt, with the
    /// system message(s) becoming the session's `instructions`.
    private static func renderPrompt(from messages: [Message]) -> (instructions: String?, prompt: String) {
        var instructionLines: [String] = []
        var turns: [String] = []

        for message in messages {
            switch message {
            case .system(let content):
                instructionLines.append(content)
            case .user(let content):
                turns.append("User: \(content)")
            case .assistant(let content, _):
                if !content.isEmpty {
                    turns.append("Assistant: \(content)")
                }
            case .tool(let id, let content):
                turns.append("Tool result (\(id)): \(content)")
            }
        }

        let instructions = instructionLines.isEmpty ? nil : instructionLines.joined(separator: "\n")
        return (instructions, turns.joined(separator: "\n"))
    }
}

/// Collects `ToolResult`s as FoundationModels invokes tools mid-`respond`/
/// `streamResponse` — the framework calls tools internally and only returns once
/// its own tool loop is fully resolved, so results are gathered via this
/// side-channel rather than being handed back as pending `ToolCall`s.
actor ToolResultSink {
    private(set) var results: [ToolResult] = []
    func record(_ result: ToolResult) { results.append(result) }
}

/// Wraps a `SwiftAgentKit.Tool` (whose input shape is a runtime `JSONSchema`) as
/// an Apple `FoundationModels.Tool`. Since our schemas are only known at runtime
/// (not a compile-time `@Generable` struct), `Arguments` is `GeneratedContent`
/// and `parameters` is built via `DynamicGenerationSchema`.
struct FoundationModelsToolAdapter: FoundationModels.Tool {
    typealias Arguments = GeneratedContent
    typealias Output = String

    let wrapped: SwiftAgentKit.Tool
    let sink: ToolResultSink
    let parameters: GenerationSchema

    var name: String { wrapped.name }
    var description: String { wrapped.description }

    init(wrapped: SwiftAgentKit.Tool, sink: ToolResultSink) throws {
        self.wrapped = wrapped
        self.sink = sink
        let schemaJSON = try wrapped.inputSchema.asJSON()
        let dynamicSchema = Self.dynamicSchema(from: schemaJSON, name: wrapped.name)
        self.parameters = try GenerationSchema(root: dynamicSchema, dependencies: [])
    }

    func call(arguments: GeneratedContent) async throws -> String {
        let json = JSON(parseJSON: arguments.jsonString)
        let result = try await wrapped.execute(input: json.dictionaryValue)
        await sink.record(result)
        return result.content
    }

    /// Walks a raw JSON Schema document (see `JSONSchema.asJSON()`) to build the
    /// equivalent `DynamicGenerationSchema`, since `JSONSchema`'s own case
    /// storage isn't public and this is the only supported introspection path.
    static func dynamicSchema(from json: JSON, name: String) -> DynamicGenerationSchema {
        switch json["type"].string {
        case "object":
            let requiredKeys = Set(json["required"].arrayValue.map { $0.stringValue })
            let properties = json["properties"].dictionaryValue.map { key, value in
                DynamicGenerationSchema.Property(
                    name: key,
                    description: value["description"].string,
                    schema: dynamicSchema(from: value, name: "\(name)_\(key)"),
                    isOptional: !requiredKeys.contains(key)
                )
            }
            return DynamicGenerationSchema(name: name, description: json["description"].string, properties: properties)
        case "array":
            let itemSchema = dynamicSchema(from: json["items"], name: "\(name)_item")
            return DynamicGenerationSchema(arrayOf: itemSchema)
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        default:
            return DynamicGenerationSchema(type: String.self)
        }
    }
}
#endif
