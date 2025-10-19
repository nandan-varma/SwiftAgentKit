import Foundation
import AnyCodable
import JSONSchema

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
            tool_choice: openAITools != nil ? "auto" : nil
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)

        // Check for error response first
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            throw OpenAIError.apiError(errorResponse.error.message)
        }

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

    public func generateObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        // Use OpenAI's structured output if available, else fallback to text and parse
        let textResponse = try await generateText(messages: messages, tools: tools)
        // Assume the content is JSON and decode to T
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

private struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetails
}

private struct OpenAIErrorDetails: Codable {
    let message: String
    let type: String
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
    let tool_choice: String?
    let response_format: OpenAIResponseFormat?
    let stream: Bool?

    init(model: String, messages: [OpenAIMessage], temperature: Double, tools: [OpenAITool]?, tool_choice: String?, response_format: OpenAIResponseFormat? = nil, stream: Bool? = nil) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.tools = tools
        self.tool_choice = tool_choice
        self.response_format = response_format
        self.stream = stream
    }
}

private struct OpenAIResponseFormat: Codable {
    let type: String
}



// Extensions
private extension Message {
    static func toOpenAI(_ message: Message) -> OpenAIMessage {
        switch message {
        case .system(let content):
            return OpenAIMessage(role: "system", content: content)
        case .user(let content):
            return OpenAIMessage(role: "user", content: content)
        case .assistant(let content, let toolCalls):
            let openAIToolCalls = toolCalls?.map { OpenAIToolCall(id: $0.id, type: "function", function: OpenAIFunctionCall(name: $0.name, arguments: ($0.arguments as? [String: Any]).map { try! JSONSerialization.data(withJSONObject: $0, options: []).base64EncodedString() } ?? "")) }
            return OpenAIMessage(role: "assistant", content: content, tool_calls: openAIToolCalls)
        case .tool(let id, let content):
            return OpenAIMessage(role: "tool", content: content, tool_call_id: id)
        }
    }
}

private extension ToolDescriptor {
    static func toOpenAI(_ descriptor: ToolDescriptor) -> OpenAITool {
        let encoder = JSONEncoder()
        let parameters = try? encoder.encode(descriptor.inputSchema)
        let dict = try? JSONSerialization.jsonObject(with: parameters ?? Data(), options: []) as? [String: Any]
        return OpenAITool(function: OpenAIFunction(
            name: descriptor.name,
            description: descriptor.description,
            parameters: AnyCodable(dict ?? [:])
        ))
    }
}



private extension OpenAIToolCall {
    func toToolCall() throws -> ToolCall {
        guard let data = function.arguments.data(using: .utf8) else {
            throw OpenAIError.invalidArgumentsEncoding
        }
        let arguments = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return ToolCall(id: id, name: function.name, arguments: arguments)
    }
}