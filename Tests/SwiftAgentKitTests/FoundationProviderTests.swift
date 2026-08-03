import XCTest
@testable import SwiftAgentKit
import JSONSchema
#if canImport(FoundationModels)
import FoundationModels
#endif

/// `FoundationProvider` is backed by Apple's real on-device model, so these are
/// smoke tests (does it respond, does it call the expected tool) rather than
/// exact-value assertions — a live model's exact wording isn't deterministic,
/// and CI runners generally won't have Apple Intelligence enabled at all.
final class FoundationProviderTests: XCTestCase {
    override func setUp() async throws {
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else {
            throw XCTSkip("Apple Intelligence is not available on this system")
        }
        #else
        throw XCTSkip("FoundationModels is not available on this platform")
        #endif
    }

    func testGenerateText() async throws {
        let provider = try FoundationProvider()
        let messages = [TestUtils.createTestMessage(content: "Say hello in one short sentence.")]
        let response = try await provider.generateText(messages: messages, tools: nil)
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNil(response.toolCalls)
    }

    func testGenerateTextWithTools() async throws {
        let weatherTool = TestUtils.createWeatherTool()
        let provider = try FoundationProvider(tools: [weatherTool])
        let messages = [TestUtils.createTestMessage(content: "What's the weather in Paris? Use the get_weather tool.")]
        let response = try await provider.generateText(messages: messages, tools: [weatherTool.descriptor])

        XCTAssertFalse(response.content.isEmpty)
        // Tools the provider calls are executed internally and surfaced via
        // `executedToolResults`, not `toolCalls` (which stays nil for this provider).
        XCTAssertNil(response.toolCalls)
        if let executed = response.executedToolResults {
            XCTAssertFalse(executed.isEmpty)
            XCTAssertTrue(executed.allSatisfy { $0.content.contains("Weather") })
        }
    }

    func testGenerateObject() async throws {
        let provider = try FoundationProvider()
        let schema = TestUtils.createTestSchema()
        let object: TestObject = try await provider.generateObject(
            messages: [TestUtils.createTestMessage(content: "Return a JSON object with \"example\" set to \"data\" and \"value\" set to 42.")],
            outputSchema: schema,
            tools: nil
        )
        XCTAssertFalse(object.example.isEmpty)
    }

    func testStreamText() async throws {
        let provider = try FoundationProvider()
        let messages = [TestUtils.createTestMessage(content: "Say hello in one short sentence.")]
        let stream = provider.streamText(messages: messages, tools: nil)
        var fullText = ""
        for try await chunk in stream {
            fullText += chunk.text
        }
        XCTAssertFalse(fullText.isEmpty)
    }
}
