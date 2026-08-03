import Foundation
import JSONSchema

/// A `LanguageModelProvider` backed by Apple's on-device Foundation Models
/// framework (macOS/iOS 26+, requires Apple Intelligence enabled).
///
/// - Important: The tools passed here must be kept in sync with the tools passed
///   to `Agent(tools:)` — this provider only knows how to actually *call* a tool
///   whose name matches one registered here; a tool present in `Agent.tools` but
///   missing from this list will silently be unusable by the model. A future
///   major version may unify this by having `LanguageModelProvider` accept
///   `[Tool]` uniformly instead of just `[ToolDescriptor]`.
public struct FoundationProvider: LanguageModelProvider {
    private let registeredTools: [String: SwiftAgentKit.Tool]

    /// - Parameter tools: Executable tools this provider's on-device session may
    ///   call. See the type-level note about keeping this in sync with `Agent(tools:)`.
    public init(tools: [Tool] = []) throws {
        var registered: [String: SwiftAgentKit.Tool] = [:]
        for tool in tools {
            registered[tool.name] = tool
        }
        self.registeredTools = registered
    }

    public func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse {
        #if canImport(FoundationModels)
        return try await FoundationModelsBridge.generateText(messages: messages, tools: tools, registeredTools: registeredTools)
        #else
        throw FoundationModelsError.unsupportedPlatform
        #endif
    }

    public func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        #if canImport(FoundationModels)
        return FoundationModelsBridge.streamText(messages: messages, tools: tools, registeredTools: registeredTools)
        #else
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: FoundationModelsError.unsupportedPlatform)
        }
        #endif
    }

    /// Unlike the other providers (which emulate structured output by asking the
    /// model to answer in JSON as prose and hoping it parses), this uses
    /// FoundationModels' real `respond(to:schema:)` structured-generation API,
    /// built from the same `DynamicGenerationSchema` machinery used for tool
    /// arguments — see `FoundationModelsToolAdapter`.
    public func generateObject<T: Decodable & Sendable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T {
        #if canImport(FoundationModels)
        let jsonString = try await FoundationModelsBridge.generateObjectJSON(
            messages: messages,
            outputSchema: outputSchema,
            tools: tools,
            registeredTools: registeredTools
        )
        guard let data = jsonString.data(using: .utf8) else {
            throw FoundationModelsError.invalidResponseFormat("Response content is not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FoundationModelsError.invalidResponseFormat("Failed to decode response as expected type: \(error.localizedDescription)")
        }
        #else
        throw FoundationModelsError.unsupportedPlatform
        #endif
    }
}
