import Foundation
@preconcurrency import JSONSchema
@preconcurrency import SwiftyJSON

/// A function an `Agent` can call, described by a JSON schema so any
/// `LanguageModelProvider` can offer it to the model.
public protocol Tool: Sendable {
    /// A short, stable identifier the model uses to invoke this tool.
    var name: String { get }
    /// A description of what the tool does, shown to the model to help it
    /// decide when to call this tool.
    var description: String { get }
    /// The JSON schema `execute(input:)`'s `input` dictionary must satisfy.
    var inputSchema: JSONSchema { get }
    /// The JSON schema of the tool's result, for documentation/validation
    /// purposes (not currently enforced on `execute(input:)`'s return value).
    var outputSchema: JSONSchema { get }

    /// Executes the tool with the given input, validated against `inputSchema`.
    /// - Throws: `ToolError.invalidInput` (or a tool-specific error) if `input`
    ///   doesn't contain what the tool needs.
    func execute(input: [String: JSON]) async throws -> ToolResult
}

extension Tool {
    /// The schema-only description of this tool, as sent to a
    /// `LanguageModelProvider`.
    public var descriptor: ToolDescriptor {
        ToolDescriptor(name: name, description: description, inputSchema: inputSchema, outputSchema: outputSchema)
    }
}
