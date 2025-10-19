import Foundation
import AnyCodable

public struct OpenAIProvider: LanguageModelProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: URL

    public init(apiKey: String, model: String = "gpt-4", baseURL: URL? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL ?? URL(string: "https://api.openai.com")!
    }

    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let openAIMessages = messages.map(Message.toOpenAI)
        let openAITools = tools?.map(ToolDescriptor.toOpenAI)

        let requestBody = OpenAIRequest(
            model: model,
            messages: openAIMessages,
            temperature: 0.7,
            tools: openAITools,
            tool_choice: "auto"
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw OpenAIError.noResponseChoices
        }

        let content = choice.message.content ?? ""
        let toolCalls = try choice.message.tool_calls?.map { try $0.toToolCall() }

        return LLMResponse(content: content, toolCalls: toolCalls)
    }

    public func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        // TODO: Implement OpenAI streaming
        AsyncThrowingStream { continuation in
            continuation.yield(LLMStreamChunk(text: "Streaming not yet implemented", isComplete: true))
            continuation.finish()
        }
    }
}

// OpenAI API Types
private struct OpenAIMessage: Codable {
    let role: String
    let content: String?
    let tool_calls: [OpenAIToolCall]?
    let tool_call_id: String?

    init(role: String, content: String? = nil, tool_calls: [OpenAIToolCall]? = nil, tool_call_id: String? = nil) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
    }
}

private struct OpenAITool: Codable {
    let type: String
    let function: OpenAIFunction

    init(function: OpenAIFunction) {
        self.type = "function"
        self.function = function
    }
}

private struct OpenAIFunction: Codable {
    let name: String
    let description: String?
    let parameters: AnyCodable?
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

private struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

private struct OpenAIFunctionCall: Codable {
    let name: String
    let arguments: String
}

private struct OpenAIStreamChunk: Codable {
    let choices: [OpenAIStreamChoice]
}

private struct OpenAIStreamChoice: Codable {
    let delta: OpenAIMessage
}

private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let tools: [OpenAITool]?
    let tool_choice: String
    let stream: Bool?

    init(model: String, messages: [OpenAIMessage], temperature: Double, tools: [OpenAITool]?, tool_choice: String, stream: Bool? = nil) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.tools = tools
        self.tool_choice = tool_choice
        self.stream = stream
    }
}



// Extensions
private extension Message {
    static func toOpenAI(_ message: Message) -> OpenAIMessage {
        switch message {
        case .system(let content):
            return OpenAIMessage(role: "system", content: content)
        case .user(let content):
            return OpenAIMessage(role: "user", content: content)
        case .assistant(let content):
            return OpenAIMessage(role: "assistant", content: content)
        case .tool(let name, let content):
            return OpenAIMessage(role: "tool", content: content, tool_call_id: name)
        }
    }
}

private extension ToolDescriptor {
    static func toOpenAI(_ descriptor: ToolDescriptor) -> OpenAITool {
        return OpenAITool(function: OpenAIFunction(
            name: descriptor.name,
            description: descriptor.description,
            parameters: JSONSchema.toOpenAI(descriptor.inputSchema)
        ))
    }
}

private extension JSONSchema {
    static func toOpenAI(_ schema: JSONSchema) -> AnyCodable {
        switch schema {
        case .string(let description):
            return AnyCodable(["type": "string", "description": description as Any])
        case .number(let description):
            return AnyCodable(["type": "number", "description": description as Any])
        case .boolean(let description):
            return AnyCodable(["type": "boolean", "description": description as Any])
        case .object(let properties):
            return AnyCodable([
                "type": "object",
                "properties": properties.mapValues { JSONSchema.toOpenAI($0).value },
                "required": Array(properties.keys)
            ])
        case .array(let itemSchema, let description):
            return AnyCodable([
                "type": "array",
                "items": JSONSchema.toOpenAI(itemSchema).value,
                "description": description as Any
            ])
        }
    }
}

private extension OpenAIToolCall {
    func toToolCall() throws -> ToolCall {
        guard let data = function.arguments.data(using: .utf8) else {
            throw OpenAIError.invalidArgumentsEncoding
        }
        let arguments = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return ToolCall(name: function.name, arguments: arguments)
    }
}