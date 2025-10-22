import Foundation
@preconcurrency import JSONSchema
@preconcurrency import SwiftyJSON

public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: JSONSchema { get }
    var outputSchema: JSONSchema { get }

    func execute(input: [String: JSON]) async throws -> ToolResult
}

extension Tool {
    public var descriptor: ToolDescriptor {
        ToolDescriptor(name: name, description: description, inputSchema: inputSchema, outputSchema: outputSchema)
    }
}