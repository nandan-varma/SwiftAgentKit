import XCTest
@testable import SwiftAgentKit
import JSONSchema
import SwiftyJSON

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
        class MockProvider: LanguageModelProvider, @unchecked Sendable {
            func generateText(messages: [Message], tools: [ToolDescriptor]?) async throws -> LLMResponse {
                return LLMResponse(content: "", toolCalls: [ToolCall(id: "test", name: "calculate", arguments: ["expression": JSON("1+1")])])
            }
            func streamText(messages: [Message], tools: [ToolDescriptor]?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
                AsyncThrowingStream { continuation in
                    continuation.yield(LLMStreamChunk(text: "Mock streaming response", isComplete: true))
                    continuation.finish()
                }
            }
            func generateObject<T: Decodable>(messages: [Message], outputSchema: JSONSchema, tools: [ToolDescriptor]?) async throws -> T {
                throw ToolError.invalidInput
            }
            func streamObject<T: Decodable>(messages: [Message], outputSchema: JSONSchema, tools: [ToolDescriptor]?) -> AsyncThrowingStream<T, Error> {
                AsyncThrowingStream { continuation in
                    continuation.finish()
                }
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
        } catch AgentError.maxIterationsExceeded(let partial) {
            // The tool executed successfully before the cap was hit, so that
            // work shouldn't be lost.
            XCTAssertNotNil(partial.toolResults)
            XCTAssertEqual(partial.toolResults?.first?.content, "Result: 2.0")
        }
    }

    func testGenerateObject() async throws {
        // FoundationProvider is backed by a real on-device model, so this is a
        // smoke test (decodes successfully into the target type) rather than an
        // exact-value assertion — the model's wording isn't deterministic.
        let provider = try FoundationProvider()
        let schema = JSONSchema.object(
            description: "Test schema",
            properties: [
                "example": .string(description: "Example string"),
                "value": .integer(description: "Example int")
            ],
            required: ["example", "value"]
        )
        let result: TestObject = try await provider.generateObject(
            messages: [.user("Return a JSON object with \"example\" set to the string \"data\" and \"value\" set to the integer 42.")],
            outputSchema: schema,
            tools: nil
        )
        XCTAssertFalse(result.example.isEmpty)
    }

    func testAgentContextPersistence() async throws {
        let store = InMemoryStore()
        let context = AgentContext(store: store)

        let message = Message.user("Test message")
        await context.addMessage(message)

        // Since persistence is not implemented, just test basic functionality
        let messages = await context.messages
        XCTAssertEqual(messages.count, 1)
        if case .user(let content) = messages.first! {
            XCTAssertEqual(content, "Test message")
        }

        // Test load (should have the saved message)
        let loadedContext = AgentContext(store: store)
        try await loadedContext.load()
        let loadedMessages = await loadedContext.messages
        XCTAssertEqual(loadedMessages.count, 1)
    }

    func testMathToolComplexExpressions() async throws {
        let tool = MathTool()

        // Test various expressions
        let testCases = [
            ("2 + 3", 5.0),
            ("10 - 4", 6.0),
            ("3 * 4", 12.0),
            ("8 / 2", 4.0),
            ("2 + 3 * 4", 14.0),
            ("(2 + 3) * 4", 20.0),
            ("-5 + 10", 5.0)
        ]

        for (expression, expected) in testCases {
            let result = try await tool.execute(input: ["expression": JSON(expression)])
            XCTAssertEqual(result.content, "Result: \(expected)")
        }
    }

    func testMathToolDivisionByZero() async throws {
        let tool = MathTool()
        do {
            _ = try await tool.execute(input: ["expression": "5 / 0"])
            XCTFail("Expected ToolError.invalidInput")
        } catch ToolError.invalidInput {
            // Expected
        }
    }

    func testMathToolMalformedExpressionsDoNotCrash() async throws {
        let tool = MathTool()
        let malformedExpressions = ["(2 + 3", "2 +", "", ")(", "()", "((1)"]

        for expression in malformedExpressions {
            do {
                _ = try await tool.execute(input: ["expression": JSON(expression)])
                XCTFail("Expected ToolError.invalidInput for expression: \(expression)")
            } catch ToolError.invalidInput {
                // Expected - the important assertion is that this doesn't crash the process
            }
        }
    }

    func testWeatherToolValidation() async throws {
        let tool = WeatherTool()

        // Valid input - hits the real Open-Meteo API (no key required)
        let result = try await tool.execute(input: ["location": "Paris"])
        XCTAssertTrue(result.content.contains("Weather in Paris"))
        XCTAssertNotNil(result.structuredOutput?["temperatureFahrenheit"].double)
        XCTAssertNotNil(result.structuredOutput?["humidityPercent"].int)
        XCTAssertNotNil(result.structuredOutput?["windSpeedKmh"].double)
        XCTAssertEqual(result.structuredOutput?["resolvedLocation"].string, "Paris")

        // Invalid input - empty location
        do {
            _ = try await tool.execute(input: ["location": ""])
            XCTFail("Expected ToolError.invalidInput")
        } catch ToolError.invalidInput {
            // Expected
        }

        // Missing location
        do {
            _ = try await tool.execute(input: [:])
            XCTFail("Expected ToolError.invalidInput")
        } catch ToolError.invalidInput {
            // Expected
        }
    }

    func testWeatherToolLocationNotFound() async throws {
        let tool = WeatherTool()
        do {
            _ = try await tool.execute(input: ["location": "zzqxwnotarealplace123"])
            XCTFail("Expected WeatherToolError.locationNotFound")
        } catch WeatherToolError.locationNotFound {
            // Expected
        }
    }

}