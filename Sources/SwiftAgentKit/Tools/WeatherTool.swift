import Foundation

public struct WeatherTool: Tool {
    public let name = "get_weather"
    public let description = "Get current weather for a location"
    
    public let inputSchema: JSONSchema = .object([
        "location": .string(description: "City name")
    ])
    
    public func execute(input: [String: Any]) async throws -> ToolResult {
        guard let location = input["location"] as? String else {
            throw ToolError.invalidInput
        }
        
        // Mock weather API call - replace with real API
        let weather = "Sunny, 72°F"
        return ToolResult(content: "Weather in \(location): \(weather)", data: ["weather": weather])
    }
}