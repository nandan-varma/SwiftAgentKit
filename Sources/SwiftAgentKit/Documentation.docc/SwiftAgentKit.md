# ``SwiftAgentKit``

A Swift-native SDK for building autonomous AI agents that call language models
and execute tools, with first-class support for OpenAI, Anthropic, and Apple's
on-device Foundation Models.

## Overview

``Agent`` orchestrates a conversation: it sends the current message history to a
``LanguageModelProvider``, executes any ``Tool``s the model wants to call, feeds
the results back, and repeats until the model produces a final answer (or
``AgentError/maxIterationsExceeded(partial:)`` is hit). ``AgentContext`` holds
the conversation history behind a pluggable ``ContextStore``.

```swift
import SwiftAgentKit

let provider = try OpenAIProvider(apiKey: "your-api-key")
let agent = Agent(
    provider: provider,
    tools: [WeatherTool(), MathTool()],
    instructions: "You are a helpful assistant."
)

let result = try await agent.respond(to: "What's 5 times 7?")
print(result.content)
```

## Topics

### Core

- ``Agent``
- ``AgentContext``
- ``AgentResponse``
- ``LanguageModelProvider``
- ``Tool``
- ``Message``
- ``ToolCall``
- ``ToolDescriptor``
- ``ToolResult``
- ``LLMResponse``
- ``LLMStreamChunk``

### Providers

- ``OpenAIProvider``
- ``AnthropicProvider``
- ``FoundationProvider``

### Built-in Tools

- ``MathTool``
- ``WeatherTool``

### Errors

- ``AgentError``
- ``ToolError``
- ``OpenAIError``
- ``AnthropicError``
- ``FoundationModelsError``
- ``WeatherToolError``
