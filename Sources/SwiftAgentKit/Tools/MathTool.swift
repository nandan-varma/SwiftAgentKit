import Foundation

public struct MathTool: Tool {
    public let name = "calculate"
    public let description = "Perform mathematical calculations"
    
    public let inputSchema: JSONSchema = .object([
        "expression": .string(description: "Mathematical expression to evaluate")
    ])
    
    public func execute(input: [String: Any]) async throws -> ToolResult {
        guard let expression = input["expression"] as? String else {
            throw ToolError.invalidInput
        }
        
        // Simple evaluation - in practice, use a proper math library
        let result = evaluateMath(expression)
        return ToolResult(content: "Result: \(result)", data: ["result": result])
    }
    
    private func evaluateMath(_ expression: String) -> Double {
        // Simplified - use NSExpression or a proper evaluator
        let expr = NSExpression(format: expression)
        return expr.expressionValue(with: nil, context: nil) as? Double ?? 0.0
    }
}

enum ToolError: Error {
    case invalidInput
}