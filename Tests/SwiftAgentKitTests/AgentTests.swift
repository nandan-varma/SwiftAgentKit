import XCTest
@testable import SwiftAgentKit

final class AgentTests: XCTestCase {
    func testAgentCreation() async throws {
        let provider = try FoundationProvider()
        let agent = Agent(
            provider: provider,
            tools: [MathTool()],
            instructions: "You are a helpful assistant."
        )
        
        let response = try await agent.respond(to: "Hello")
        XCTAssertFalse(response.content.isEmpty)
    }
    
    func testToolExecution() async throws {
        let tool = MathTool()
        let result = try await tool.execute(input: ["expression": "2 + 2"])
        XCTAssertEqual(result.content, "Result: 4.0")
    }
}