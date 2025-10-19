import XCTest
@testable import SwiftAgentKit
import JSONSchema

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

    func testToolExecutionInvalidInput() async throws {
        let tool = MathTool()
        do {
            _ = try await tool.execute(input: ["expression": "invalid"])
            XCTFail("Expected ToolError.invalidInput")
        } catch ToolError.invalidInput {
            // Expected
        }
    }

    func testMathToolInjectionPrevention() async throws {
        let tool = MathTool()
        do {
            _ = try await tool.execute(input: ["expression": "2 + 2; print('injected')"])
            XCTFail("Expected ToolError.invalidInput")
        } catch ToolError.invalidInput {
            // Expected
        }
    }

    func testAgentMaxIterations() async throws {
        // Mock a provider that always returns tool calls
        class MockProvider: LanguageModelProvider {
            func generateText(messages: [Message], tools: [ToolDescriptor]?) async throws -> LLMResponse {
                return LLMResponse(content: "", toolCalls: [ToolCall(id: "test", name: "calculate", arguments: ["expression": "1+1"])])
            }
            func streamText(messages: [Message], tools: [ToolDescriptor]?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
                fatalError("Not implemented")
            }
            func generateObject<T: Decodable>(messages: [Message], outputSchema: JSONSchema, tools: [ToolDescriptor]?) async throws -> T {
                fatalError("Not implemented")
            }
            func streamObject<T: Decodable>(messages: [Message], outputSchema: JSONSchema, tools: [ToolDescriptor]?) -> AsyncThrowingStream<T, Error> {
                fatalError("Not implemented")
            }
        }

        let agent = Agent(
            provider: MockProvider(),
            tools: [MathTool()],
            instructions: "Test"
        )

        do {
            _ = try await agent.respond(to: "Test", maxIterations: 1)
            XCTFail("Expected AgentError.maxIterationsExceeded")
        } catch AgentError.maxIterationsExceeded {
            // Expected
        }
    }

    func testGenerateObject() async throws {
        let provider = try FoundationProvider()
        let schema = JSONSchema.object(
            description: "Test schema",
            properties: [
                "example": .string(description: "Example string"),
                "value": .integer(description: "Example int")
            ],
            required: ["example", "value"]
        )
        let result: TestObject = try await provider.generateObject(messages: [], outputSchema: schema, tools: nil)
        XCTAssertEqual(result.example, "data")
        XCTAssertEqual(result.value, 42)
    }


}