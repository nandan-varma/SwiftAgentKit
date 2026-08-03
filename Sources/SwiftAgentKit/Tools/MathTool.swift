import Foundation
import JSONSchema
import SwiftyJSON

public struct MathTool: Tool {
    public init() {}
    public let name = "calculate"
    public let description = "Perform mathematical calculations"

    public let inputSchema: JSONSchema = .object(
        description: "Input for mathematical calculations",
        properties: [
            "expression": .string(description: "Mathematical expression to evaluate")
        ],
        required: ["expression"]
    )

    public let outputSchema: JSONSchema = .object(
        description: "Calculation result",
        properties: [
            "result": .number(description: "Computed value")
        ],
        required: ["result"]
    )
    
    public func execute(input: [String: JSON]) async throws -> ToolResult {
        guard let expression = input["expression"]?.string else {
            throw ToolError.invalidInput
        }

        let result: Double
        do {
            result = try MathExpressionEvaluator.evaluate(expression)
        } catch {
            throw ToolError.invalidInput
        }

        return ToolResult(content: "Result: \(result)", data: ["result": JSON(result)], structuredOutput: JSON(["result": result]))
    }
}