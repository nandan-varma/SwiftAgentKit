import XCTest
@testable import SwiftAgentKit
import JSONSchema
import SwiftyJSON

/// A provider that streams a fixed sequence of chunks and never returns tool
/// calls from `generateText` — used to prove the tools-empty streaming path
/// yields real incremental chunks.
private final class StreamingMockProvider: LanguageModelProvider, @unchecked Sendable {
    func generateText(messages: [Message], tools: [ToolDescriptor]?) async throws -> LLMResponse {
        LLMResponse(content: "Hello world")
    }
    func streamText(messages: [Message], tools: [ToolDescriptor]?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(LLMStreamChunk(text: "Hello", isComplete: false))
            continuation.yield(LLMStreamChunk(text: " world", isComplete: false))
            continuation.yield(LLMStreamChunk(text: "", isComplete: true))
            continuation.finish()
        }
    }
    func generateObject<T: Decodable>(messages: [Message], outputSchema: JSONSchema, tools: [ToolDescriptor]?) async throws -> T {
        throw ToolError.invalidInput
    }
}

/// A provider that always returns a tool call from `generateText` (and would
/// fail the test if `streamText` were ever called) — used to prove the
/// tools-present path resolves via the non-streamed loop and yields a single
/// completing chunk.
private final class ToolCallingMockProvider: LanguageModelProvider, @unchecked Sendable {
    func generateText(messages: [Message], tools: [ToolDescriptor]?) async throws -> LLMResponse {
        let hasToolResult = messages.contains { if case .tool = $0 { return true } else { return false } }
        if hasToolResult {
            return LLMResponse(content: "The result is 4")
        }
        return LLMResponse(content: "", toolCalls: [ToolCall(id: "call-1", name: "calculate", arguments: ["expression": JSON("2+2")])])
    }
    func streamText(messages: [Message], tools: [ToolDescriptor]?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ToolError.invalidInput)
        }
    }
    func generateObject<T: Decodable>(messages: [Message], outputSchema: JSONSchema, tools: [ToolDescriptor]?) async throws -> T {
        throw ToolError.invalidInput
    }
}

final class AgentStreamingTests: XCTestCase {
    func testStreamResponseWithNoToolsStreamsIncrementally() async throws {
        let agent = Agent(provider: StreamingMockProvider(), tools: [], instructions: "Test")

        var chunks: [String] = []
        for try await chunk in await agent.streamResponse(to: "Hi") {
            if !chunk.text.isEmpty {
                chunks.append(chunk.text)
            }
        }

        XCTAssertEqual(chunks, ["Hello", " world"])
    }

    func testStreamResponseWithToolsYieldsSingleCompletingChunk() async throws {
        let agent = Agent(provider: ToolCallingMockProvider(), tools: [MathTool()], instructions: "Test")

        var chunks: [LLMStreamChunk] = []
        for try await chunk in await agent.streamResponse(to: "What's 2+2?") {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first?.isComplete, true)
        XCTAssertEqual(chunks.first?.text, "The result is 4")
    }
}
