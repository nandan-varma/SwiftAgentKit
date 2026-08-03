import Foundation
import SwiftyJSON
import JSONSchema

/// A `LanguageModelProvider` backed by Anthropic's Messages API.
public struct AnthropicProvider: LanguageModelProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let timeout: TimeInterval
    private let session: URLSession

    /// - Parameters:
    ///   - apiKey: Your Anthropic API key.
    ///   - model: The model ID to use. Check Anthropic's model listing for the
    ///     current recommended model for your use case.
    ///   - baseURL: Override for the API base URL (e.g. for a proxy), defaults to `api.anthropic.com`.
    ///   - timeout: Per-request timeout.
    ///   - session: The `URLSession` to issue requests on; override for testing.
    /// - Throws: `AnthropicError.invalidAPIKey` if `apiKey` is empty.
    public init(apiKey: String, model: String = "claude-sonnet-5", baseURL: URL? = nil, timeout: TimeInterval = 30.0, session: URLSession = .shared) throws {
        guard !apiKey.isEmpty else {
            throw AnthropicError.invalidAPIKey
        }
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL ?? URL(string: "https://api.anthropic.com")!
        self.timeout = timeout
        self.session = session
    }

    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (system, anthropicMessages) = Self.splitForAnthropic(messages)
        let anthropicTools = try tools?.map { try $0.toAnthropic() }

        let requestBody = AnthropicRequest(
            model: model,
            max_tokens: 1024,
            system: system,
            messages: anthropicMessages,
            tools: anthropicTools,
            stream: nil
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await performRequestWithRetry(request: request)

        if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data), errorResponse.type == "error" {
            throw AnthropicError.apiError(errorResponse.error.message)
        }

        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        let textContent = response.content.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }.joined()

        let toolCalls = Self.parseToolCalls(from: response)
        return LLMResponse(content: textContent, toolCalls: toolCalls)
    }

    public func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let endpoint = baseURL.appendingPathComponent("/v1/messages")

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = timeout
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let (system, anthropicMessages) = Self.splitForAnthropic(messages)
                    let anthropicTools = try tools?.map { try $0.toAnthropic() }

                    let requestBody = AnthropicRequest(
                        model: model,
                        max_tokens: 1024,
                        system: system,
                        messages: anthropicMessages,
                        tools: anthropicTools,
                        stream: true
                    )

                    request.httpBody = try JSONEncoder().encode(requestBody)

                    let (asyncBytes, _) = try await session.bytes(for: request)

                    for try await line in asyncBytes.lines {
                        if line.starts(with: "data: ") {
                            let json = String(line.dropFirst(6))
                            let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(json.utf8))
                            if event.type == "content_block_delta", let delta = event.delta, let text = delta.text {
                                continuation.yield(LLMStreamChunk(text: text, isComplete: false))
                            } else if event.type == "error" {
                                let message = event.error?.message ?? "Unknown Anthropic streaming error"
                                continuation.finish(throwing: AnthropicError.apiError(message))
                                return
                            } else if event.type == "message_stop" {
                                continuation.yield(LLMStreamChunk(text: "", isComplete: true))
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateObject<T: Decodable & Sendable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        // Add schema instruction to messages
        var modifiedMessages = messages
        let schemaText = (try? outputSchema.asJSON())?.rawString() ?? String(describing: outputSchema)
        let schemaDescription = "Respond with valid JSON matching this schema: \(schemaText)"
        if let systemIndex = modifiedMessages.firstIndex(where: { if case .system = $0 { return true } else { return false } }) {
            if case .system(let content) = modifiedMessages[systemIndex] {
                modifiedMessages[systemIndex] = .system(content + " " + schemaDescription)
            }
        } else {
            modifiedMessages.insert(.system(schemaDescription), at: 0)
        }

        let textResponse = try await generateText(messages: modifiedMessages, tools: tools)
        guard let data = textResponse.content.data(using: .utf8) else {
            throw AnthropicError.invalidResponseFormat("Response content is not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AnthropicError.invalidResponseFormat("Failed to decode response as expected type: \(error.localizedDescription)")
        }
    }

    private static func parseToolCalls(from response: AnthropicResponse) -> [ToolCall]? {
        let toolCalls = response.content.compactMap { block -> ToolCall? in
            if case .toolUse(let id, let name, let input) = block {
                return ToolCall(id: id, name: name, arguments: input.dictionaryValue)
            }
            return nil
        }
        return toolCalls.isEmpty ? nil : toolCalls
    }

    /// Anthropic's Messages API takes `system` as a top-level request field (not a
    /// message with `role: "system"`), and `messages` only supports `role: "user"`/
    /// `"assistant"`. Tool results must be sent back as a `user` message containing
    /// `tool_result` content blocks, so consecutive `.tool` messages are merged into
    /// a single turn.
    private static func splitForAnthropic(_ messages: [Message]) -> (system: String?, messages: [AnthropicMessage]) {
        var system: String?
        var result: [AnthropicMessage] = []
        var pendingToolResults: [AnthropicContentBlock] = []

        func flushToolResults() {
            if !pendingToolResults.isEmpty {
                result.append(AnthropicMessage(role: "user", content: pendingToolResults))
                pendingToolResults = []
            }
        }

        for message in messages {
            switch message {
            case .system(let content):
                system = system.map { $0 + "\n" + content } ?? content
            case .user(let content):
                flushToolResults()
                result.append(AnthropicMessage(role: "user", content: [.text(content)]))
            case .assistant(let content, let toolCalls):
                flushToolResults()
                var blocks: [AnthropicContentBlock] = content.isEmpty ? [] : [.text(content)]
                blocks += (toolCalls ?? []).map { call in
                    .toolUse(id: call.id, name: call.name, input: JSON(call.arguments.mapValues { $0.rawValue }))
                }
                result.append(AnthropicMessage(role: "assistant", content: blocks))
            case .tool(let id, let content):
                pendingToolResults.append(.toolResult(toolUseId: id, content: content))
            }
        }
        flushToolResults()
        return (system, result)
    }

    private func performRequestWithRetry(request: URLRequest, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = TimeInterval(pow(2.0, Double(attempt))) // Exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}

// Anthropic API Types

private struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContentBlock]
}

/// A single Anthropic message content block. Covers the subset of block types this
/// provider produces/consumes (`text`, `tool_use`, `tool_result`); any other type
/// encountered while decoding a response (e.g. `thinking`) decodes to `.other` and
/// is ignored rather than failing the whole response.
private enum AnthropicContentBlock: Codable {
    case text(String)
    case toolUse(id: String, name: String, input: JSON)
    case toolResult(toolUseId: String, content: String)
    case other

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, tool_use_id, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent(JSON.self, forKey: .input) ?? JSON([:])
            self = .toolUse(id: id, name: name, input: input)
        case "tool_result":
            let toolUseId = try container.decode(String.self, forKey: .tool_use_id)
            let content = try container.decode(String.self, forKey: .content)
            self = .toolResult(toolUseId: toolUseId, content: content)
        default:
            self = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseId, let content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .tool_use_id)
            try container.encode(content, forKey: .content)
        case .other:
            break
        }
    }
}

private struct AnthropicTool: Codable {
    let name: String
    let description: String
    let input_schema: JSON
}

private struct AnthropicResponse: Codable {
    let content: [AnthropicContentBlock]
}

private struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]?
    let stream: Bool?
}

private struct AnthropicErrorResponse: Codable {
    let type: String
    let error: AnthropicErrorDetail
}

private struct AnthropicErrorDetail: Codable {
    let type: String
    let message: String
}

private struct AnthropicStreamEvent: Codable {
    let type: String
    let delta: AnthropicDelta?
    let error: AnthropicErrorDetail?
}

private struct AnthropicDelta: Codable {
    let text: String?
}

// Extensions

private extension ToolDescriptor {
    func toAnthropic() throws -> AnthropicTool {
        AnthropicTool(name: name, description: description, input_schema: try inputSchema.asJSON())
    }
}
