import XCTest
@testable import SwiftAgentKit
import JSONSchema

final class OpenAIProviderTests: XCTestCase {
    var provider: OpenAIProvider?

    override func setUp() async throws {
        if TestConfig.shared.hasOpenAIKey {
            provider = try OpenAIProvider(apiKey: TestConfig.shared.openAIAPIKey!)
        }
    }

    override func tearDown() {
        provider = nil
    }

    func testGenerateText() async throws {
        guard let provider = provider else {
            throw XCTSkip("OpenAI API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Say hello")]
        let response = try await provider.generateText(messages: messages, tools: nil)
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNil(response.toolCalls)
    }

    func testGenerateTextWithTools() async throws {
        guard let provider = provider else {
            throw XCTSkip("OpenAI API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "What is 5 + 3?")]
        let tools = [TestUtils.createMathTool().descriptor]
        let response = try await provider.generateText(messages: messages, tools: tools)
        // Content may be empty if tool calls are made
        if response.toolCalls == nil {
            XCTAssertFalse(response.content.isEmpty)
        }
        // May or may not have tool calls depending on model
    }

    func testGenerateObject() async throws {
        guard let provider = provider else {
            throw XCTSkip("OpenAI API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Return exactly this JSON: {\"example\": \"test\", \"value\": 123}")]
        let schema = TestUtils.createTestSchema()
        let object: TestObject = try await provider.generateObject(messages: messages, outputSchema: schema, tools: nil)
        XCTAssertEqual(object.example, "test")
        XCTAssertEqual(object.value, 123)
    }

    func testToolExecutionIntegration() async throws {
        guard let provider = provider else {
            throw XCTSkip("OpenAI API key not available")
        }
        let messages = [TestUtils.createTestMessage(content: "Calculate 10 * 2")]
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

    func testStreamText() async throws {
        guard let provider = provider else {
            throw XCTSkip("OpenAI API key not available")
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
        let invalidProvider = try OpenAIProvider(apiKey: "invalid")
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
            throw XCTSkip("OpenAI API key not available")
        }
        // OpenAI's json_schema response format constrains the model to valid,
        // schema-conformant JSON regardless of what the prompt asks for, so a
        // model can no longer be talked into emitting literally malformed
        // JSON. This instead exercises a real, reachable mismatch: TestUtils'
        // schema only marks "example" as required, so the API may legitimately
        // omit "value" — which TestObject.value (a non-optional Int) can't decode.
        let messages = [TestUtils.createTestMessage(content: "Return JSON with only the \"example\" field set to \"test\". Do not include a \"value\" field at all.")]
        let schema = TestUtils.createTestSchema()
        do {
            let _: TestObject = try await provider.generateObject(messages: messages, outputSchema: schema, tools: nil)
            XCTFail("Expected decoding error")
        } catch {
            // Expected - TestObject.value is non-optional but the schema allows omitting it
        }
    }
}