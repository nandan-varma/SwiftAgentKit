import Foundation
import AnyCodable
import JSONSchema

public struct AnthropicProvider: LanguageModelProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: URL

    public init(apiKey: String, model: String = "claude-3-sonnet-20240229", baseURL: URL? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL ?? URL(string: "https://api.anthropic.com")!
    }

    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("x-api-key \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let anthropicMessages = messages.map { $0.toAnthropic() }
        let anthropicTools = tools?.map { $0.toAnthropic() }

        let requestBody = AnthropicRequest(
            model: model,
            max_tokens: 1024,
            messages: anthropicMessages,
            tools: anthropicTools
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        let content = response.content.first?.text ?? ""
        // Anthropic tool calls not fully implemented yet
        return LLMResponse(content: content, toolCalls: nil)
    }

    public func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        // TODO: Implement Anthropic streaming
        AsyncThrowingStream { continuation in
            continuation.yield(LLMStreamChunk(text: "Streaming not yet implemented for Anthropic", isComplete: true))
            continuation.finish()
        }
    }

    public func generateObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        let textResponse = try await generateText(messages: messages, tools: tools)
        return try JSONDecoder().decode(T.self, from: textResponse.content.data(using: .utf8)!)
    }

    public func streamObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<T, Error> {
        // TODO: Implement streaming
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

// Anthropic API Types
private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicTool: Codable {
    let name: String
    let description: String
    let input_schema: AnyCodable
}

private struct AnthropicResponse: Codable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Codable {
    let text: String
}

private struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]?
}

// Extensions
private extension Message {
    func toAnthropic() -> AnthropicMessage {
        switch self {
        case .system(let content):
            return AnthropicMessage(role: "system", content: content)
        case .user(let content):
            return AnthropicMessage(role: "user", content: content)
        case .assistant(let content, _):
            return AnthropicMessage(role: "assistant", content: content)
        case .tool(_, let content):
            return AnthropicMessage(role: "tool", content: content)
        }
    }
}

private extension ToolDescriptor {
    func toAnthropic() -> AnthropicTool {
        let encoder = JSONEncoder()
        let schemaData = try? encoder.encode(inputSchema)
        let dict = try? JSONSerialization.jsonObject(with: schemaData ?? Data(), options: []) as? [String: Any]
        return AnthropicTool(
            name: name,
            description: description,
            input_schema: AnyCodable(dict ?? [:])
        )
    }
}

