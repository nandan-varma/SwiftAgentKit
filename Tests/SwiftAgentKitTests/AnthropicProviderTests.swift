import XCTest
@testable import SwiftAgentKit
import JSONSchema

/// Live-API coverage of `AnthropicProvider` against Anthropic's real servers —
/// requires `ANTHROPIC_API_KEY` (see `.env.local.example`) and self-skips
/// otherwise. For offline request-shape coverage see `AnthropicProviderRequestShapeTests`.
final class AnthropicProviderTests: XCTestCase {
    var provider: AnthropicProvider?

    override func setUp() async throws {
        if TestConfig.shared.hasAnthropicKey {
            provider = try AnthropicProvider(apiKey: TestConfig.shared.anthropicAPIKey!)
        }
    }

    override func tearDown() {
        provider = nil
    }

    func testGenerateText() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Say hello")]
        let response = try await provider.generateText(messages: messages, tools: nil)
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNil(response.toolCalls)
    }

    func testGenerateTextWithTools() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "What is 5 + 3? Use the calculate tool.")]
        let tools = [TestUtils.createMathTool().descriptor]
        let response = try await provider.generateText(messages: messages, tools: tools)
        // Content may be empty if tool calls are made
        if response.toolCalls == nil {
            XCTAssertFalse(response.content.isEmpty)
        }
    }

    func testGenerateObject() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Return exactly this JSON and nothing else: {\"example\": \"test\", \"value\": 123}")]
        let schema = TestUtils.createTestSchema()
        let object: TestObject = try await provider.generateObject(messages: messages, outputSchema: schema, tools: nil)
        XCTAssertEqual(object.example, "test")
        XCTAssertEqual(object.value, 123)
    }

    func testToolExecutionIntegration() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Calculate 10 * 2 using the calculate tool.")]
        let tools = [TestUtils.createMathTool().descriptor]
        let response = try await provider.generateText(messages: messages, tools: tools)

        if let toolCalls = response.toolCalls {
            for call in toolCalls {
                if call.name == "calculate" {
                    let tool = TestUtils.createMathTool()
                    let result = try await tool.execute(input: call.arguments)
                    XCTAssertTrue(result.content.contains("Result"))
                }
            }
        }
    }

    func testMultiTurnToolRoundTrip() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let tool = TestUtils.createMathTool()
        var messages: [Message] = [TestUtils.createTestMessage(content: "What is 7 * 8? Use the calculate tool and tell me the final number.")]

        let first = try await provider.generateText(messages: messages, tools: [tool.descriptor])
        guard let toolCalls = first.toolCalls, let call = toolCalls.first(where: { $0.name == "calculate" }) else {
            // The model answered without needing the tool — acceptable, nothing further to round-trip.
            return
        }

        let result = try await tool.execute(input: call.arguments)
        messages.append(.assistant(content: first.content, toolCalls: toolCalls))
        messages.append(.tool(id: call.id, content: result.content))

        let second = try await provider.generateText(messages: messages, tools: [tool.descriptor])
        XCTAssertFalse(second.content.isEmpty)
    }

    func testStreamText() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Tell me a short story")]
        let stream = provider.streamText(messages: messages, tools: nil)
        var fullText = ""
        for try await chunk in stream {
            fullText += chunk.text
        }
        XCTAssertFalse(fullText.isEmpty)
    }

    func testInvalidAPIKey() async throws {
        let invalidProvider = try AnthropicProvider(apiKey: "invalid-key")
        let messages = [TestUtils.createTestMessage(content: "Hello")]
        do {
            _ = try await invalidProvider.generateText(messages: messages, tools: nil)
            XCTFail("Expected error with invalid API key")
        } catch {
            // Expected
        }
    }

    func testGenerateObjectErrorHandling() async throws {
        guard let provider = provider else {
            throw XCTSkip("Anthropic API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Return invalid JSON")]
        let schema = TestUtils.createTestSchema()
        do {
            let _: TestObject = try await provider.generateObject(messages: messages, outputSchema: schema, tools: nil)
            XCTFail("Expected decoding error")
        } catch {
            // Expected - invalid JSON should cause decode error
        }
    }
}
