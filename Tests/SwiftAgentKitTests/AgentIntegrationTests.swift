import XCTest
@testable import SwiftAgentKit
import JSONSchema

final class AgentIntegrationTests: XCTestCase {
    func testAgentWithFoundationProvider() async throws {
        try TestUtils.skipUnlessFoundationModelAvailable()
        let mathTool = TestUtils.createMathTool()
        let weatherTool = TestUtils.createWeatherTool()
        // FoundationProvider only calls tools it's been explicitly given, in
        // addition to the ones passed to Agent(tools:) — see its docs.
        let provider = try FoundationProvider(tools: [mathTool, weatherTool])
        let agent = Agent(
            provider: provider,
            tools: [mathTool, weatherTool],
            instructions: "You are a helpful assistant."
        )

        let response = try await agent.respond(to: "What is 4 + 5?")
        XCTAssertFalse(response.content.isEmpty)
    }

    func testAgentWithOpenAIProvider() async throws {
        guard TestConfig.shared.hasOpenAIKey else {
            throw XCTSkip("OpenAI API key not available")
        }

        let provider = try OpenAIProvider(apiKey: TestConfig.shared.openAIAPIKey!)
        let agent = Agent(
            provider: provider,
            tools: [TestUtils.createMathTool(), TestUtils.createWeatherTool()],
            instructions: "You are a helpful assistant. Use tools when appropriate."
        )

        let response = try await agent.respond(to: "Calculate 7 * 8 and tell me the weather in Paris")
        XCTAssertFalse(response.content.isEmpty)

        // Check if tools were used
        if let toolResults = response.toolResults {
            XCTAssertFalse(toolResults.isEmpty)
            for result in toolResults {
                XCTAssertFalse(result.content.isEmpty)
            }
        }
    }

    func testAgentWithAnthropicProvider() async throws {
        guard TestConfig.shared.hasAnthropicKey else {
            throw XCTSkip("Anthropic API key not available")
        }

        let provider = try AnthropicProvider(apiKey: TestConfig.shared.anthropicAPIKey!)
        let agent = Agent(
            provider: provider,
            tools: [TestUtils.createMathTool(), TestUtils.createWeatherTool()],
            instructions: "You are a helpful assistant. Use tools when appropriate."
        )

        let response = try await agent.respond(to: "Calculate 7 * 8 and tell me the weather in Paris")
        XCTAssertFalse(response.content.isEmpty)

        if let toolResults = response.toolResults {
            XCTAssertFalse(toolResults.isEmpty)
            for result in toolResults {
                XCTAssertFalse(result.content.isEmpty)
            }
        }
    }

    func testAgentToolExecution() async throws {
        try TestUtils.skipUnlessFoundationModelAvailable()
        let mathTool = TestUtils.createMathTool()
        let provider = try FoundationProvider(tools: [mathTool])
        let agent = Agent(
            provider: provider,
            tools: [mathTool],
            instructions: "Use the calculate tool for math."
        )

        let response = try await agent.respond(to: "What is 2 + 2?")
        XCTAssertFalse(response.content.isEmpty)
    }

    func testAgentMaxIterations() async throws {
        try TestUtils.skipUnlessFoundationModelAvailable()
        // Deterministic max-iterations behavior (does the loop actually stop
        // and surface partial results) is covered against a MockProvider in
        // AgentTests.testAgentMaxIterations. This is a smoke test that the
        // real on-device model + tool loop doesn't hang or crash within a
        // small iteration budget.
        let mathTool = TestUtils.createMathTool()
        let provider = try FoundationProvider(tools: [mathTool])
        let agent = Agent(
            provider: provider,
            tools: [mathTool],
            instructions: "Always use the calculate tool."
        )

        let response = try await agent.respond(to: "Calculate something", maxIterations: 5)
        XCTAssertFalse(response.content.isEmpty)
    }

    func testAgentWithStructuredOutput() async throws {
        try TestUtils.skipUnlessFoundationModelAvailable()
        let mathTool = TestUtils.createMathTool()
        let provider = try FoundationProvider(tools: [mathTool])
        let agent = Agent(
            provider: provider,
            tools: [mathTool],
            instructions: "Provide structured responses."
        )

        let response = try await agent.respond(to: "Calculate 3 + 4")
        XCTAssertFalse(response.content.isEmpty)

        // Check tool results have structured output
        if let toolResults = response.toolResults {
            for result in toolResults {
                XCTAssertNotNil(result.structuredOutput)
            }
        }
    }

    // Note: Concurrency test removed due to Swift 6 strict concurrency requirements
    // Agent class would need to be Sendable for concurrent usage

}
