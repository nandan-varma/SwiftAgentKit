import XCTest
@testable import SwiftAgentKit
import JSONSchema
import SwiftyJSON

private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: URLRequest?
    var request: URLRequest? {
        get { lock.lock(); defer { lock.unlock() }; return _request }
        set { lock.lock(); defer { lock.unlock() }; _request = newValue }
    }
}

/// Offline coverage of OpenAIProvider's request shape (headers, tool serialization),
/// exercised without a live API key via an injected mock `URLSession`.
private func openAISuccessBody() -> [String: Any] {
    ["choices": [["message": ["role": "assistant", "content": "ok"]]]]
}

final class OpenAIProviderRequestShapeTests: XCTestCase {
    func testAuthorizationHeader() async throws {
        let box = RequestBox()
        let session = mockSession { request in
            box.request = request
            return jsonResponse(request.url!, body: openAISuccessBody())
        }
        let provider = try OpenAIProvider(apiKey: "sk-test-key", session: session)
        _ = try await provider.generateText(messages: [.user("hi")], tools: nil)

        XCTAssertEqual(box.request?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key")
    }

    func testRequestBodyIncludesTools() async throws {
        let box = RequestBox()
        let session = mockSession { request in
            box.request = request
            return jsonResponse(request.url!, body: openAISuccessBody())
        }
        let provider = try OpenAIProvider(apiKey: "sk-test-key", session: session)
        let descriptor = MathTool().descriptor

        _ = try await provider.generateText(messages: [.user("Calculate 1+1")], tools: [descriptor])

        let data = try XCTUnwrap(requestBodyData(box.request))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        let function = try XCTUnwrap(tools.first?["function"] as? [String: Any])

        XCTAssertEqual(function["name"] as? String, "calculate")
        let parameters = try XCTUnwrap(function["parameters"] as? [String: Any])
        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        XCTAssertNotNil(properties["expression"])
    }
}
