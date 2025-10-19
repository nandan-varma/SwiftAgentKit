// Mock implementation for testing without FoundationModels
import Foundation

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
}