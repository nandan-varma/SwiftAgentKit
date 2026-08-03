import XCTest
@testable import SwiftAgentKit
import JSONSchema
import SwiftyJSON

/// A synchronous, lock-protected box for capturing the outgoing `URLRequest` from
/// inside `MockURLProtocol`'s handler (which runs synchronously in `startLoading`,
/// so no actor-hop race is possible here).
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: URLRequest?
    var request: URLRequest? {
        get { lock.lock(); defer { lock.unlock() }; return _request }
        set { lock.lock(); defer { lock.unlock() }; _request = newValue }
    }
}

private func anthropicSuccessBody() -> [String: Any] {
    ["content": [["type": "text", "text": "ok"]]]
}

final class AnthropicProviderTests: XCTestCase {
    private func decodedBody(_ request: URLRequest?) throws -> [String: Any] {
        let data = try XCTUnwrap(requestBodyData(request))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEmptyAPIKeyThrowsAnthropicError() {
        XCTAssertThrowsError(try AnthropicProvider(apiKey: "")) { error in
            XCTAssertEqual(error as? AnthropicError, .invalidAPIKey)
        }
    }

    func testHeaderUsesRawAPIKey() async throws {
        let box = RequestBox()
        let session = mockSession { request in
            box.request = request
            return jsonResponse(request.url!, body: anthropicSuccessBody())
        }
        let provider = try AnthropicProvider(apiKey: "sk-test-key", session: session)
        _ = try await provider.generateText(messages: [.user("hi")], tools: nil)

        XCTAssertEqual(box.request?.value(forHTTPHeaderField: "x-api-key"), "sk-test-key")
    }

    func testDefaultModelIsClaudeSonnet5() async throws {
        let box = RequestBox()
        let session = mockSession { request in
            box.request = request
            return jsonResponse(request.url!, body: anthropicSuccessBody())
        }
        let provider = try AnthropicProvider(apiKey: "sk-test-key", session: session)
        _ = try await provider.generateText(messages: [.user("hi")], tools: nil)

        let body = try decodedBody(box.request)
        XCTAssertEqual(body["model"] as? String, "claude-sonnet-5")
    }

    func testSystemMessageIsTopLevelField() async throws {
        let box = RequestBox()
        let session = mockSession { request in
            box.request = request
            return jsonResponse(request.url!, body: anthropicSuccessBody())
        }
        let provider = try AnthropicProvider(apiKey: "sk-test-key", session: session)
        _ = try await provider.generateText(messages: [.system("be nice"), .user("hi")], tools: nil)

        let body = try decodedBody(box.request)
        XCTAssertEqual(body["system"] as? String, "be nice")

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertFalse(messages.contains { ($0["role"] as? String) == "system" })
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
    }

    func testToolResultRoundTrip() async throws {
        let box = RequestBox()
        let session = mockSession { request in
            box.request = request
            return jsonResponse(request.url!, body: anthropicSuccessBody())
        }
        let provider = try AnthropicProvider(apiKey: "sk-test-key", session: session)

        let messages: [Message] = [
            .system("s"),
            .user("Calculate 1+1"),
            .assistant(content: "", toolCalls: [ToolCall(id: "call-1", name: "calculate", arguments: ["expression": JSON("1+1")])]),
            .tool(id: "call-1", content: "2")
        ]
        _ = try await provider.generateText(messages: messages, tools: nil)

        let body = try decodedBody(box.request)
        let messagesOut = try XCTUnwrap(body["messages"] as? [[String: Any]])

        let assistantMessage = try XCTUnwrap(messagesOut.first { ($0["role"] as? String) == "assistant" })
        let assistantBlocks = try XCTUnwrap(assistantMessage["content"] as? [[String: Any]])
        let toolUseBlock = try XCTUnwrap(assistantBlocks.first { ($0["type"] as? String) == "tool_use" })
        XCTAssertEqual(toolUseBlock["id"] as? String, "call-1")
        XCTAssertEqual(toolUseBlock["name"] as? String, "calculate")

        let userToolResultMessage = try XCTUnwrap(messagesOut.last { message in
            guard (message["role"] as? String) == "user" else { return false }
            guard let blocks = message["content"] as? [[String: Any]] else { return false }
            return blocks.contains { ($0["type"] as? String) == "tool_result" }
        })
        let userBlocks = try XCTUnwrap(userToolResultMessage["content"] as? [[String: Any]])
        let toolResultBlock = try XCTUnwrap(userBlocks.first { ($0["type"] as? String) == "tool_result" })
        XCTAssertEqual(toolResultBlock["tool_use_id"] as? String, "call-1")
        XCTAssertEqual(toolResultBlock["content"] as? String, "2")
    }

    func testAnthropicErrorResponseParses() async throws {
        let session = mockSession { request in
            jsonResponse(request.url!, status: 400, body: [
                "type": "error",
                "error": ["type": "invalid_request_error", "message": "boom"]
            ])
        }
        let provider = try AnthropicProvider(apiKey: "sk-test-key", session: session)

        do {
            _ = try await provider.generateText(messages: [.user("hi")], tools: nil)
            XCTFail("Expected AnthropicError.apiError")
        } catch AnthropicError.apiError(let message) {
            XCTAssertEqual(message, "boom")
        }
    }
}
