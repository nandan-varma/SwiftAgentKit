import Foundation
import JSONSchema

public struct WeatherTool: Tool {
    public init() {}
    public let name = "get_weather"
    public let description = "Get current weather for a location"

    public let inputSchema: JSONSchema = .object(
        description: "Input for weather queries",
        properties: [
            "location": .string(description: "City name")
        ],
        required: ["location"]
    )

    public let outputSchema: JSONSchema = .object(
        description: "Weather information",
        properties: [
            "weather": .string(description: "Weather description")
        ],
        required: ["weather"]
    )
    
    public func execute(input: [String: Any]) async throws -> ToolResult {
        guard let location = input["location"] as? String else {
            throw ToolError.invalidInput
        }
        
        // Mock weather API call - replace with real API
        let weather = "Sunny, 72°F"
        return ToolResult(content: "Weather in \(location): \(weather)", data: ["weather": weather], structuredOutput: ["weather": weather])
    }
}