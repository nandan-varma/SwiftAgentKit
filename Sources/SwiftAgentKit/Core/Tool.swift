import Foundation
import JSONSchema

public protocol Tool {
    var name: String { get }
    var description: String { get }
    var inputSchema: JSONSchema { get }
    var outputSchema: JSONSchema { get }

    func execute(input: [String: Any]) async throws -> ToolResult
}

extension Tool {
    public var descriptor: ToolDescriptor {
        ToolDescriptor(name: name, description: description, inputSchema: inputSchema, outputSchema: outputSchema)
    }
}