import Foundation

/// A `URLProtocol` stub that routes requests through a handler closure instead of
/// the network, so provider request-shape (headers, body JSON) can be verified
/// offline without hitting a live API.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    // Test-only global, set synchronously before each request is issued and never
    // mutated concurrently with a request in flight.
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("MockURLProtocol.requestHandler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func mockSession(handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    MockURLProtocol.requestHandler = handler
    return URLSession(configuration: config)
}

func jsonResponse(_ url: URL, status: Int = 200, body: [String: Any]) -> (HTTPURLResponse, Data) {
    let data = try! JSONSerialization.data(withJSONObject: body, options: [])
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, data)
}

/// `URLSession` moves a request's body into `httpBodyStream` rather than
/// `httpBody` for tasks intercepted by a custom `URLProtocol`, so tests must read
/// whichever one is populated.
func requestBodyData(_ request: URLRequest?) -> Data? {
    if let body = request?.httpBody {
        return body
    }
    guard let stream = request?.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        guard read > 0 else { break }
        data.append(buffer, count: read)
    }
    return data
}
