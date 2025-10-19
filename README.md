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

// Using Foundation Models (macOS 15+)
let foundationProvider = try FoundationProvider()
let agent2 = Agent(
    provider: foundationProvider,
    tools: [WeatherTool(), MathTool()],
    instructions: "You are a helpful assistant."
)
```

## Features

- **Agent Loop**: Automatic tool selection and execution
- **Multiple Providers**: OpenAI, Foundation Models, Anthropic, etc.
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

- iOS 15+/macOS 12+
- Swift 6.0+
- OpenAI API key (for OpenAI provider)
- Apple Intelligence enabled (for Foundation Models, optional)
