import Foundation
import JSONSchema

/// A language model backend that `Agent` drives — OpenAI, Anthropic, and Apple's
/// on-device Foundation Models are the built-in conformers.
///
/// Each call receives the full conversation history (`messages`), matching the
/// stateless request/response shape of typical LLM REST APIs. Implementations
/// that wrap a stateful session (like `FoundationProvider`) reconstruct
/// whatever state they need from that history on every call.
public protocol LanguageModelProvider: Sendable {
    /// Generates a complete (non-streamed) response for the given conversation.
    /// - Parameters:
    ///   - messages: The full conversation history, including the system prompt.
    ///   - tools: Tools the model may call, or nil/empty if none are available.
    /// - Returns: The model's response. `toolCalls` holds any calls the caller
    ///   (typically `Agent`) still needs to execute; `executedToolResults` holds
    ///   results for calls the provider already executed itself — see
    ///   `LLMResponse` for when each applies.
    func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse

    /// Streams a response for the given conversation as incremental text chunks.
    /// - Parameters:
    ///   - messages: The full conversation history, including the system prompt.
    ///   - tools: Tools the model may call, or nil/empty if none are available.
    func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error>

    /// Generates a response and decodes it into `T` according to `outputSchema`.
    /// - Parameters:
    ///   - messages: The full conversation history, including the system prompt.
    ///   - outputSchema: The JSON schema `T`'s encoded form must satisfy.
    ///   - tools: Tools the model may call, or nil/empty if none are available.
    func generateObject<T: Decodable & Sendable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T

    // func streamObject<T: Decodable & Sendable>(
    //     messages: [Message],
    //     outputSchema: JSONSchema,
    //     tools: [ToolDescriptor]?
    // ) -> AsyncThrowingStream<T, Error>
}
