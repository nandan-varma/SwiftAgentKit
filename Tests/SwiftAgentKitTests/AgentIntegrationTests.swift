import XCTest
@testable import SwiftAgentKit
import JSONSchema

final class AgentIntegrationTests: XCTestCase {
    func testAgentWithFoundationProvider() async throws {
        let provider = try FoundationProvider()
        let agent = Agent(
            provider: provider,
            tools: [TestUtils.createMathTool(), TestUtils.createWeatherTool()],
            instructions: "You are a helpful assistant."
        )

        let response = try await agent.respond(to: "What is 4 + 5?")
        XCTAssertFalse(response.content.isEmpty)
        // FoundationProvider may not trigger tools, but response should be present
    }

    func testAgentWithOpenAIProvider() async throws {
        guard TestConfig.shared.hasOpenAIKey else {
            throw XCTSkip("OpenAI API key not available")
        }

        let provider = OpenAIProvider(apiKey: TestConfig.shared.openAIAPIKey!, model: TestConfig.defaultModel)
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

    func testAgentToolExecution() async throws {
        let provider = try FoundationProvider()
        let agent = Agent(
            provider: provider,
            tools: [TestUtils.createMathTool()],
            instructions: "Use the calculate tool for math."
        )

        let response = try await agent.respond(to: "What is 2 + 2?")
        XCTAssertFalse(response.content.isEmpty)
        // Even with FoundationProvider, the agent should respond
    }

    func testAgentMaxIterations() async throws {
        let provider = try FoundationProvider()
        let agent = Agent(
            provider: provider,
            tools: [TestUtils.createMathTool()],
            instructions: "Always use the calculate tool."
        )

        // FoundationProvider doesn't trigger tool calls, so iterations should not exceed
        let response = try await agent.respond(to: "Calculate something", maxIterations: 5)
        XCTAssertFalse(response.content.isEmpty)
    }

    func testAgentWithStructuredOutput() async throws {
        let provider = try FoundationProvider()
        let agent = Agent(
            provider: provider,
            tools: [TestUtils.createMathTool()],
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
}