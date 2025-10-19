# SwiftAgentKit

A Swift-native SDK for building LLM-based autonomous AI agents, inspired by Vercel's AI SDK.

## Installation

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/nandan-varma/SwiftAgentKit.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SwiftAgentKit

// Using OpenAI
let openAIProvider = OpenAIProvider(apiKey: "your-api-key")
let agent = Agent(
    provider: openAIProvider,
    tools: [WeatherTool(), MathTool()],
    instructions: "You are a helpful assistant."
)

let result = try await agent.respond(to: "What's 5 times 7?")
print(result.content)

// Using Anthropic
let anthropicProvider = AnthropicProvider(apiKey: "your-anthropic-key")
let agent2 = Agent(
    provider: anthropicProvider,
    tools: [WeatherTool(), MathTool()],
    instructions: "You are a helpful assistant."
)

// Using Foundation Models (macOS 15+)
let foundationProvider = try FoundationProvider()
let agent3 = Agent(
    provider: foundationProvider,
    tools: [WeatherTool(), MathTool()],
    instructions: "You are a helpful assistant."
)
```

## Features

- **Agent Loop**: Automatic tool selection and execution
- **Multiple Providers**: OpenAI, Anthropic, Foundation Models, etc.
- **Tool Integration**: Extensible tool system with structured I/O
- **Streaming**: Real-time text generation
- **Context Management**: Persistent conversation memory
- **Swift Concurrency**: Full async/await support

## API Documentation

### Agent
Main class for creating AI agents.

### LanguageModelProvider
Protocol for LLM providers.

### Tool
Protocol for agent tools.

## Requirements

- macOS 15+/iOS 18+
- Swift 6.0+
- OpenAI API key (for OpenAI provider)
- Anthropic API key (for Anthropic provider)
- Apple Intelligence enabled (for Foundation Models, optional)

## Testing

To run the full test suite:

1. Copy `.env.local.example` to `.env.local` and add your OpenAI API key.
2. Run `swift test` - unit tests will run with FoundationProvider.
3. Integration tests with OpenAI will run if API key is present.

Note: OpenAI tests are skipped in CI unless API key is provided as a secret.
