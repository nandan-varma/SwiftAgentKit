import Foundation
import JSONSchema

// Safe math expression evaluator using NSExpression with strict validation
private struct MathEvaluator {
    static func evaluate(_ expression: String) -> Double? {
        // Additional validation: only allow basic math operations and numbers
        let allowedPattern = "^[0-9+\\-*/().\\s]+$"
        guard expression.range(of: allowedPattern, options: .regularExpression) != nil else {
            return nil
        }

        // Check for potentially dangerous patterns
        let dangerousPatterns = ["**", "import", "NS", "func", "class", "let", "var"]
        for pattern in dangerousPatterns {
            if expression.contains(pattern) {
                return nil
            }
        }

        // Use NSExpression but with very limited scope
        let expr = NSExpression(format: expression)
        return expr.expressionValue(with: nil, context: nil) as? Double
    }
}

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

        // Basic validation - only allow safe characters
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/(). ")
        guard expression.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            throw ToolError.invalidInput
        }

        let result = evaluateMath(expression)
        return ToolResult(content: "Result: \(result)", data: ["result": result], structuredOutput: ["result": result])
    }
    
    private func evaluateMath(_ expression: String) -> Double {
        // Safe math evaluator - only allows basic arithmetic operations
        return MathEvaluator.evaluate(expression) ?? 0.0
    }
}