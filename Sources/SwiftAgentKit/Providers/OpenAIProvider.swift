import Foundation
import SwiftyJSON
import JSONSchema

public struct OpenAIProvider: LanguageModelProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let timeout: TimeInterval

    public init(apiKey: String, model: String = "gpt-4", baseURL: URL? = nil, timeout: TimeInterval = 30.0) throws {
        guard !apiKey.isEmpty else {
            throw OpenAIError.apiError("API key cannot be empty")
        }
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL ?? URL(string: "https://api.openai.com")!
        self.timeout = timeout
    }

    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
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

        let (data, _) = try await performRequestWithRetry(request: request)

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
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = timeout
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let openAIMessages = messages.map(Message.toOpenAI)
                    let openAITools = tools?.map(ToolDescriptor.toOpenAI)

                    let requestBody = OpenAIRequest(
                        model: model,
                        messages: openAIMessages,
                        temperature: 0.7,
                        tools: openAITools,
                        tool_choice: openAITools != nil ? "auto" : nil,
                        stream: true
                    )

                    request.httpBody = try JSONEncoder().encode(requestBody)

                    let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in asyncBytes.lines {
                        if line.starts(with: "data: ") {
                            let json = String(line.dropFirst(6))
                            if json == "[DONE]" {
                                continuation.yield(LLMStreamChunk(text: "", isComplete: true))
                                break
                            }
                            let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: Data(json.utf8))
                            if let delta = chunk.choices.first?.delta {
                                let text = delta.content ?? ""
                                continuation.yield(LLMStreamChunk(text: text, isComplete: false))
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

    public func generateObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        // Try OpenAI's structured output first, fallback to text parsing if not supported
        let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let openAIMessages = messages.map(Message.toOpenAI)
        let openAITools = tools?.map(ToolDescriptor.toOpenAI)

        let responseFormat = OpenAIResponseFormat(type: "json_schema", json_schema: OpenAIJSONSchema(name: "response", schema: outputSchema))

        let requestBody = OpenAIRequest(
            model: model,
            messages: openAIMessages,
            temperature: 0.7,
            tools: openAITools,
            tool_choice: openAITools != nil ? "auto" : nil,
            response_format: responseFormat
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await performRequestWithRetry(request: request)

        // Check for error response first
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            // If structured output not supported, fallback to text parsing
            if errorResponse.error.message.contains("json_schema") && errorResponse.error.message.contains("not supported") {
                return try await fallbackGenerateObject(messages: messages, tools: tools)
            }
            throw OpenAIError.apiError(errorResponse.error.message)
        }

        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw OpenAIError.noResponseChoices
        }

        let content = choice.message.content ?? ""
        guard let data = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponseFormat("Response content is not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OpenAIError.invalidResponseFormat("Failed to decode response as expected type: \(error.localizedDescription)")
        }
    }

    private func fallbackGenerateObject<T: Decodable>(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> T {
        let textResponse = try await generateText(messages: messages, tools: tools)
        guard let data = textResponse.content.data(using: .utf8) else {
            throw OpenAIError.invalidResponseFormat("Response content is not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OpenAIError.invalidResponseFormat("Failed to decode response as expected type: \(error.localizedDescription)")
        }
    }

//    public func streamObject<T: Decodable>(
//        messages: [Message],
//        outputSchema: JSONSchema,
//        tools: [ToolDescriptor]?
//    ) -> AsyncThrowingStream<T, Error> {
//        AsyncThrowingStream { continuation in
//            Task {
//                do {
//                    let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")
//
//                    var request = URLRequest(url: endpoint)
//                    request.httpMethod = "POST"
//                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//                    let openAIMessages = messages.map(Message.toOpenAI)
//                    let openAITools = tools?.map(ToolDescriptor.toOpenAI)
//
//                    let responseFormat = OpenAIResponseFormat(type: "json_schema", json_schema: OpenAIJSONSchema(schema: outputSchema))
//
//                    let requestBody = OpenAIRequest(
//                        model: model,
//                        messages: openAIMessages,
//                        temperature: 0.7,
//                        tools: openAITools,
//                        tool_choice: openAITools != nil ? "auto" : nil,
//                        response_format: responseFormat,
//                        stream: true
//                    )
//
//                    request.httpBody = try JSONEncoder().encode(requestBody)
//
//                    let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
//
//                    var accumulatedContent = ""
//
//                    for try await line in asyncBytes.lines {
//                        if line.starts(with: "data: ") {
//                            let json = String(line.dropFirst(6))
//                            if json == "[DONE]" {
//                                let data = accumulatedContent.data(using: .utf8)!
//                                let object = try JSONDecoder().decode(T.self, from: data)
//                                continuation.yield(object)
//                                break
//                            }
//                            let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: Data(json.utf8))
//                            if let delta = chunk.choices.first?.delta {
//                                if let content = delta.content {
//                                    accumulatedContent += content
//                                }
//                            }
//                        }
//                    }
//                    continuation.finish()
//                } catch {
//                    continuation.finish(throwing: error)
//                }
//            }
//        }
//    }
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
    let parameters: JSON?
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
    let delta: OpenAIDelta
}

private struct OpenAIDelta: Codable {
    let role: String?
    let content: String?
    let tool_calls: [OpenAIToolCall]?
    let tool_call_id: String?
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
    let json_schema: OpenAIJSONSchema?
}

private struct OpenAIJSONSchema: Codable {
    let name: String
    let schema: JSONSchema
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
            let openAIToolCalls = toolCalls?.map { 
                let dict = $0.arguments.mapValues { $0.rawValue }
                let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
                let argsString = String(data: data, encoding: .utf8)!
                return OpenAIToolCall(id: $0.id, type: "function", function: OpenAIFunctionCall(name: $0.name, arguments: argsString))
            }
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
            parameters: JSON(dict ?? [:])
        ))
    }
}



    private extension OpenAIToolCall {
        func toToolCall() throws -> ToolCall {
            guard let data = function.arguments.data(using: .utf8) else {
                throw OpenAIError.invalidArgumentsEncoding
            }
            let arguments = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            return ToolCall(id: id, name: function.name, arguments: arguments.mapValues { JSON($0) })
        }
    }

    private func performRequestWithRetry(request: URLRequest, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await URLSession.shared.data(for: request)
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