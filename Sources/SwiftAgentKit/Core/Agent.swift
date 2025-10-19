import Foundation

public struct AgentResponse {
    public let content: String
    public let toolResults: [ToolResult]?
}

public final class Agent {
    private let provider: LanguageModelProvider
    private let tools: [Tool]
    private let instructions: String
    private var context: AgentContext
    
    public init(
        provider: LanguageModelProvider,
        tools: [Tool] = [],
        instructions: String,
        context: AgentContext = .init()
    ) {
        self.provider = provider
        self.tools = tools
        self.instructions = instructions
        self.context = context
    }
    
    public func respond(to input: String) async throws -> AgentResponse {
        context.addMessage(.user(input))
        
        var toolResults: [ToolResult] = []
        
        while true {
            let systemMessage = Message.system(instructions)
            let messages = [systemMessage] + context.messages
            
            let response = try await provider.generateText(
                messages: messages,
                tools: tools.map { $0.descriptor }
            )
            
            if let toolCalls = response.toolCalls {
                for call in toolCalls {
                    if let tool = tools.first(where: { $0.name == call.name }) {
                        let result = try await tool.execute(input: call.arguments)
                        toolResults.append(result)
                        context.addMessage(.tool(name: call.name, content: result.content))
                    }
                }
            } else {
                context.addMessage(.assistant(response.content))
                return AgentResponse(content: response.content, toolResults: toolResults.isEmpty ? nil : toolResults)
            }
        }
    }
    

}