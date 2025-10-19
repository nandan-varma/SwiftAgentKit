import XCTest
@testable import SwiftAgentKit
import JSONSchema

final class FoundationProviderTests: XCTestCase {
    var provider: FoundationProvider!

    override func setUp() async throws {
        provider = try FoundationProvider()
    }

    override func tearDown() {
        provider = nil
    }

    func testGenerateText() async throws {
        let messages = [TestUtils.createTestMessage(content: "Hello")]
        let response = try await provider.generateText(messages: messages, tools: nil)
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNil(response.toolCalls)
    }

    func testGenerateTextWithTools() async throws {
        let messages = [TestUtils.createTestMessage(content: "Calculate 2+2")]
        let tools = [TestUtils.createMathTool().descriptor]
        let response = try await provider.generateText(messages: messages, tools: tools)
        XCTAssertFalse(response.content.isEmpty)
        // FoundationProvider doesn't simulate tool calls, so toolCalls should be nil
        XCTAssertNil(response.toolCalls)
    }

    func testGenerateObject() async throws {
        let messages = [TestUtils.createTestMessage(content: "Generate a test object")]
        let schema = TestUtils.createTestSchema()
        let object: TestObject = try await provider.generateObject(messages: messages, outputSchema: schema, tools: nil)
        XCTAssertEqual(object.example, "data")
        XCTAssertEqual(object.value, 42)
    }

    func testStreamText() async throws {
        let messages = [TestUtils.createTestMessage(content: "Stream hello")]
        let stream = provider.streamText(messages: messages, tools: nil)
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk.text)
        }
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.contains { $0.contains("helpful AI assistant") })
    }

    func testStreamObject() async throws {
        let messages = [TestUtils.createTestMessage(content: "Stream object")]
        let schema = TestUtils.createTestSchema()
        let stream: AsyncThrowingStream<TestObject, Error> = provider.streamObject(messages: messages, outputSchema: schema, tools: nil)
        var objects: [TestObject] = []
        for try await object in stream {
            objects.append(object)
        }
        // Currently stubbed, so should be empty
        XCTAssertTrue(objects.isEmpty)
    }
}