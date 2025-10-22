import Foundation
import SwiftyJSON
import JSONSchema

public struct AnthropicProvider: LanguageModelProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let timeout: TimeInterval

    public init(apiKey: String, model: String = "claude-3-sonnet-20240229", baseURL: URL? = nil, timeout: TimeInterval = 30.0) throws {
        guard !apiKey.isEmpty else {
            throw ToolError.invalidInput
        }
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL ?? URL(string: "https://api.anthropic.com")!
        self.timeout = timeout
    }

    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("x-api-key \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let anthropicMessages = messages.map { $0.toAnthropic() }
        let anthropicTools = tools?.map { $0.toAnthropic() }

        let requestBody = AnthropicRequest(
            model: model,
            max_tokens: 1024,
            messages: anthropicMessages,
            tools: anthropicTools,
            stream: nil
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await performRequestWithRetry(request: request)
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        let textContent = response.content.filter { $0.type == "text" }.first?.text ?? ""
        // Parse tool calls from Anthropic response if present
        let toolCalls = parseToolCalls(from: response)
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
                    request.setValue("x-api-key \(apiKey)", forHTTPHeaderField: "x-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let anthropicMessages = messages.map { $0.toAnthropic() }
                    let anthropicTools = tools?.map { $0.toAnthropic() }

                    let requestBody = AnthropicRequest(
                        model: model,
                        max_tokens: 1024,
                        messages: anthropicMessages,
                        tools: anthropicTools,
                        stream: true
                    )

                    request.httpBody = try JSONEncoder().encode(requestBody)

                    let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in asyncBytes.lines {
                        if line.starts(with: "data: ") {
                            let json = String(line.dropFirst(6))
                            let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(json.utf8))
                            if event.type == "content_block_delta", let delta = event.delta, let text = delta.text {
                                continuation.yield(LLMStreamChunk(text: text, isComplete: false))
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
        let schemaDescription = "Respond with valid JSON matching this schema: \(String(describing: outputSchema))"
        if let systemIndex = modifiedMessages.firstIndex(where: { if case .system = $0 { return true } else { return false } }) {
            if case .system(let content) = modifiedMessages[systemIndex] {
                modifiedMessages[systemIndex] = .system(content + " " + schemaDescription)
            }
        } else {
            modifiedMessages.insert(.system(schemaDescription), at: 0)
        }

        let textResponse = try await generateText(messages: modifiedMessages, tools: tools)
        guard let data = textResponse.content.data(using: .utf8) else {
            throw ToolError.invalidInput
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

//    public func streamObject<T: Decodable & Sendable>(
//        messages: [Message],
//        outputSchema: JSONSchema,
//        tools: [ToolDescriptor]?
//    ) -> AsyncThrowingStream<T, Error> {
//        AsyncThrowingStream { continuation in
//            Task {
//                do {
//                    let endpoint = baseURL.appendingPathComponent("/v1/messages")
//
//                    var request = URLRequest(url: endpoint)
//                    request.httpMethod = "POST"
//                    request.setValue("x-api-key \(apiKey)", forHTTPHeaderField: "x-api-key")
//                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
//
//                    let anthropicMessages = messages.map { $0.toAnthropic() }
//                    let anthropicTools = tools?.map { $0.toAnthropic() }
//
//                    // For structured output, add a system message instructing JSON
//                    var modifiedMessages = anthropicMessages
//                    if let systemIndex = modifiedMessages.firstIndex(where: { $0.role == "system" }) {
//                        modifiedMessages[systemIndex].content += " Respond with valid JSON matching this schema: \(String(describing: outputSchema))"
//                    } else {
//                        modifiedMessages.insert(AnthropicMessage(role: "system", content: "Respond with valid JSON matching this schema: \(String(describing: outputSchema))"), at: 0)
//                    }
//
//                    let requestBody = AnthropicRequest(
//                        model: model,
//                        max_tokens: 1024,
//                        messages: modifiedMessages,
//                        tools: anthropicTools,
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
//                            let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(json.utf8))
//                            if event.type == "content_block_delta", let delta = event.delta, let text = delta.text {
//                                accumulatedContent += text
//                            } else if event.type == "message_stop" {
//                                let data = accumulatedContent.data(using: .utf8)!
//                                let object = try JSONDecoder().decode(T.self, from: data)
//                                continuation.yield(object)
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

    private func parseToolCalls(from response: AnthropicResponse) -> [ToolCall]? {
        let toolCalls = response.content.filter { $0.type == "tool_use" }.compactMap { content -> ToolCall? in
            guard let id = content.id, let name = content.name, let input = content.input else { return nil }
            return ToolCall(id: id, name: name, arguments: input.dictionaryValue)
        }
        return toolCalls.isEmpty ? nil : toolCalls
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
}

// Anthropic API Types
private struct AnthropicMessage: Codable {
    let role: String
    var content: String
}

private struct AnthropicTool: Codable {
    let name: String
    let description: String
    let input_schema: JSON
}

private struct AnthropicResponse: Codable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Codable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: JSON?
}

private struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]?
    let stream: Bool?
}

private struct AnthropicStreamEvent: Codable {
    let type: String
    let delta: AnthropicDelta?
}

private struct AnthropicDelta: Codable {
    let text: String?
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
            input_schema: JSON(dict ?? [:])
        )
    }
}

