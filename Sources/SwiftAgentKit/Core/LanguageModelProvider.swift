import Foundation
import JSONSchema

public protocol LanguageModelProvider {
    func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse

    func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error>

    func generateObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T

    func streamObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<T, Error>
}