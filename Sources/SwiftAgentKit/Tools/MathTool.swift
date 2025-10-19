import Foundation
import JSONSchema

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
    
    public func execute(input: [String: Any]) async throws -> ToolResult {
        guard let expression = input["expression"] as? String else {
            throw ToolError.invalidInput
        }

        // Basic validation to prevent injection
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/(). ")
        guard expression.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            throw ToolError.invalidInput
        }

        let result = evaluateMath(expression)
        return ToolResult(content: "Result: \(result)", data: ["result": result], structuredOutput: ["result": result])
    }
    
    private func evaluateMath(_ expression: String) -> Double {
        // Simplified - use NSExpression or a proper evaluator
        let expr = NSExpression(format: expression)
        return expr.expressionValue(with: nil, context: nil) as? Double ?? 0.0
    }
}