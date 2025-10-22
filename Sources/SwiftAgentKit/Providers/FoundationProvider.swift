// Mock implementation for testing without FoundationModels
import Foundation
import JSONSchema

public struct FoundationProvider: LanguageModelProvider {
    public init() throws {}
    
    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        // Mock response - in real implementation, use FoundationModels
        let content = "Hello! I'm a helpful AI assistant. How can I help you today?"
        return LLMResponse(content: content, toolCalls: nil)
    }
    
    public func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let text = "Hello! I'm a helpful AI assistant. How can I help you today?"
            continuation.yield(LLMStreamChunk(text: text, isComplete: true))
            continuation.finish()
        }
    }

    public func generateObject<T: Decodable & Sendable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        // Mock: Generate a sample object based on schema
        // For simplicity, return a hardcoded object; in real implementation, use schema to guide generation
        let mockJSON = "{\"example\": \"data\", \"value\": 42}"
        guard let data = mockJSON.data(using: .utf8) else {
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
//                // Mock: Simulate streaming by yielding the object after a short delay
//                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
//                let mockJSON = "{\"example\": \"streamed data\", \"value\": 42}"
//                guard let data = mockJSON.data(using: .utf8) else {
//                    continuation.finish(throwing: ToolError.invalidInput)
//                    return
//                }
//                do {
//                    let object = try JSONDecoder().decode(T.self, from: data)
//                    continuation.yield(object)
//                    continuation.finish()
//                } catch {
//                    continuation.finish(throwing: error)
//                }
//            }
//        }
//    }
}