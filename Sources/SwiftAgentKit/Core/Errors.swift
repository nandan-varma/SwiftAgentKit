import Foundation

public enum ToolError: Error {
    case invalidInput
}

enum AgentError: Error {
    case maxIterationsExceeded
}

enum OpenAIError: Error {
    case invalidArgumentsEncoding
    case noResponseChoices
    case apiError(String)
    case invalidResponseFormat(String)
}