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

    public func generateObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        // Mock: Generate a sample object based on schema
        // For simplicity, return a hardcoded object; in real implementation, use schema to guide generation
        let mockJSON = "{\"example\": \"data\", \"value\": 42}"
        return try JSONDecoder().decode(T.self, from: mockJSON.data(using: .utf8)!)
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