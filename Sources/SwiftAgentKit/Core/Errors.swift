import Foundation

public enum ToolError: Error, Sendable {
    case invalidInput
}

public enum AgentError: Error, Sendable {
    /// Thrown when the tool-execution loop hits `maxIterations` without
    /// resolving. Carries whatever content/tool results had already been
    /// produced, so callers don't lose completed work when the cap is hit.
    case maxIterationsExceeded(partial: AgentResponse)
}

public enum OpenAIError: Error, Sendable {
    case invalidArgumentsEncoding
    case noResponseChoices
    case apiError(String)
    case invalidResponseFormat(String)
}

public enum AnthropicError: Error, Sendable, Equatable {
    case invalidAPIKey
    case apiError(String)
    case invalidResponseFormat(String)
}

public enum FoundationModelsError: Error, Sendable {
    case modelUnavailable(String)
    case invalidResponseFormat(String)
    case unsupportedPlatform
}