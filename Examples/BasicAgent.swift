import SwiftAgentKit

// Example usage of SwiftAgentKit

do {
    let provider = try FoundationProvider()
    let agent = Agent(
        provider: provider,
        tools: [WeatherTool(), MathTool()],
        instructions: "You are a helpful assistant."
    )

    let result = try await agent.respond(to: "What's 5 times 7?")
    print("Agent response: \(result.content)")

    if let toolResults = result.toolResults {
        for result in toolResults {
            print("Tool result: \(result.content)")
        }
    }
} catch {
    print("Error: \(error)")
}