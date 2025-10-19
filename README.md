# SwiftAgentKit

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B%20%7C%20iOS%2018%2B-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

A Swift-native SDK for building autonomous AI agents that can interact with language models, execute tools, and maintain conversation context. Inspired by Vercel's AI SDK but designed specifically for Swift's concurrency model and type safety.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Testing](#testing)
- [Requirements](#requirements)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Features

- **🔄 Agent Loop**: Automatic tool selection and execution with configurable iteration limits
- **🧠 Multiple Providers**: Support for OpenAI, Anthropic, and Apple Foundation Models
- **🛠️ Tool System**: Extensible protocol-based tools with JSON schema validation
- **💬 Context Management**: Persistent conversation memory with pluggable storage
- **⚡ Swift Concurrency**: Full async/await support with structured concurrency
- **🔒 Type Safety**: Compile-time guarantees with Swift's type system
- **📊 Structured Output**: JSON schema-based response parsing
- **🧪 Comprehensive Testing**: Unit and integration tests with mock providers

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nandan-varma/SwiftAgentKit.git", from: "1.0.0")
]
```

Then add `"SwiftAgentKit"` to your target's dependencies.

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

## Architecture

### Core Components

- **Agent**: Orchestrates conversations between users, language models, and tools
- **LanguageModelProvider**: Protocol for LLM integrations (OpenAI, Anthropic, Foundation)
- **Tool**: Protocol for executable functions with structured input/output
- **AgentContext**: Manages conversation history with persistence support
- **Message Types**: Type-safe message representations (system, user, assistant, tool)

### Data Flow

```
User Input → Agent → Provider → LLM → Tool Calls → Tool Execution → Response
```

### Provider Support

| Provider | Status | Features |
|----------|--------|----------|
| OpenAI | ✅ Full | Text generation, tool calls, structured output |
| Anthropic | ⚠️ Partial | Text generation (tool calls planned) |
| Foundation | ✅ Basic | Text generation (Apple Intelligence) |

## API Reference

### Agent

```swift
public final class Agent {
    public init(
        provider: LanguageModelProvider,
        tools: [Tool] = [],
        instructions: String,
        context: AgentContext = .init()
    )

    public func respond(
        to input: String,
        maxIterations: Int = 10
    ) async throws -> AgentResponse
}
```

**Parameters:**
- `provider`: LLM provider implementation
- `tools`: Array of available tools for execution
- `instructions`: System prompt defining agent behavior
- `maxIterations`: Maximum tool execution loops (prevents infinite loops)

### LanguageModelProvider Protocol

```swift
public protocol LanguageModelProvider {
    func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse

    func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error>

    func generateObject<T: Decodable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T
}
```

### Tool Protocol

```swift
public protocol Tool {
    var name: String { get }
    var description: String { get }
    var inputSchema: JSONSchema { get }
    var outputSchema: JSONSchema { get }

    func execute(input: [String: Any]) async throws -> ToolResult
}
```

### Built-in Tools

- **MathTool**: Safe mathematical expression evaluation with injection prevention
- **WeatherTool**: Mock weather data (replace with real API implementation)

### Error Types

- `AgentError.maxIterationsExceeded`: Tool loop limit reached
- `ToolError.invalidInput`: Invalid tool parameters
- `OpenAIError.*`: OpenAI API specific errors

## Examples

### Basic Agent Setup

```swift
import SwiftAgentKit

// Initialize provider
let provider = OpenAIProvider(apiKey: "your-api-key")

// Create agent with tools
let agent = Agent(
    provider: provider,
    tools: [MathTool(), WeatherTool()],
    instructions: "You are a helpful assistant that can perform calculations and check weather."
)

// Use agent
let response = try await agent.respond(to: "What's 15 * 23?")
print(response.content)
// Output: "15 * 23 equals 345"
```

### Custom Tool Implementation

```swift
struct CustomTool: Tool {
    let name = "custom_function"
    let description = "Performs a custom operation"

    let inputSchema: JSONSchema = .object(
        description: "Input parameters",
        properties: [
            "value": .integer(description: "A number to process")
        ],
        required: ["value"]
    )

    let outputSchema: JSONSchema = .object(
        description: "Result",
        properties: [
            "result": .integer(description: "Processed value")
        ]
    )

    func execute(input: [String: Any]) async throws -> ToolResult {
        guard let value = input["value"] as? Int else {
            throw ToolError.invalidInput
        }

        let result = value * 2
        return ToolResult(
            content: "Result: \(result)",
            data: ["result": result],
            structuredOutput: ["result": result]
        )
    }
}

// Use custom tool
let agent = Agent(
    provider: provider,
    tools: [CustomTool()],
    instructions: "Use the custom tool when needed."
)
```

### Context Persistence

```swift
// Use custom context store
class FileStore: ContextStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func save(messages: [Message]) async throws {
        let data = try JSONEncoder().encode(messages)
        try data.write(to: fileURL)
    }

    func load() async throws -> [Message] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Message].self, from: data)
    }
}

let context = AgentContext(store: FileStore(fileURL: someURL))
let agent = Agent(
    provider: provider,
    tools: [],
    instructions: "You are a helpful assistant.",
    context: context
)
```

### Error Handling

```swift
do {
    let response = try await agent.respond(to: userInput)
    print("Response: \(response.content)")

    if let toolResults = response.toolResults {
        for result in toolResults {
            print("Tool executed: \(result.content)")
        }
    }
} catch AgentError.maxIterationsExceeded {
    print("Agent exceeded maximum tool execution iterations")
} catch ToolError.invalidInput {
    print("Invalid tool input provided")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Structured Output

```swift
import JSONSchema

let schema = JSONSchema.object(
    description: "Person information",
    properties: [
        "name": .string(description: "Person's name"),
        "age": .integer(description: "Person's age")
    ],
    required: ["name", "age"]
)

let person: Person = try await provider.generateObject(
    messages: [.user("Create a person named John who is 30 years old")],
    outputSchema: schema,
    tools: nil
)

struct Person: Codable {
    let name: String
    let age: Int
}
```

## Testing

To run the full test suite:

1. Copy `.env.local.example` to `.env.local` and add your OpenAI API key:
   ```
   OPENAI_API_KEY=your-api-key-here
   ```

2. Run `swift test` - unit tests will run with FoundationProvider.

3. Integration tests with OpenAI will run if API key is present.

Note: OpenAI tests are skipped in CI unless API key is provided as a secret.

### Test Coverage

- ✅ Agent creation and configuration
- ✅ Tool execution and validation
- ✅ Provider implementations
- ✅ Error handling scenarios
- ✅ Context persistence
- ✅ Math expression evaluation
- ✅ Input sanitization

## Requirements

- macOS 15+/iOS 18+
- Swift 6.0+
- OpenAI API key (for OpenAI provider)
- Anthropic API key (for Anthropic provider)
- Apple Intelligence enabled (for Foundation Models, optional)

## Security

- **API Keys**: Store securely using environment variables or Keychain
- **Input Validation**: All tools validate inputs to prevent injection attacks
- **MathTool**: Uses restricted expression evaluation to prevent code execution
- **Network**: Uses standard URLSession with no custom certificates
- **Data Persistence**: Context stores should encrypt sensitive conversation data

## Troubleshooting

### Common Issues

**"maxIterationsExceeded" error**
- Agent is calling tools in a loop
- Increase `maxIterations` or refine tool selection logic
- Check if tools are returning appropriate responses

**OpenAI API errors**
- Check API key validity and format
- Verify network connectivity
- Check API quota/limits in your OpenAI dashboard

**Tool execution failures**
- Validate input parameters match tool schema
- Check tool-specific error messages
- Ensure tool dependencies are available

**FoundationProvider not working**
- Requires macOS 15+ with Apple Intelligence enabled
- Check system settings for Apple Intelligence

### Debug Mode

Enable detailed logging by setting environment variable:
```bash
export DEBUG=SwiftAgentKit
```

### Getting Help

- Check existing [GitHub Issues](https://github.com/nandan-varma/SwiftAgentKit/issues)
- Create a new issue with:
  - Swift version (`swift --version`)
  - macOS/iOS version
  - Full error message and stack trace
  - Minimal code example that reproduces the issue

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Run tests: `swift test`
4. Commit changes: `git commit -am 'Add your feature'`
5. Push to branch: `git push origin feature/your-feature`
6. Submit a pull request

### Development Setup

```bash
git clone https://github.com/nandan-varma/SwiftAgentKit.git
cd SwiftAgentKit
swift build
swift test
```

### Code Style

- Follow Swift API Design Guidelines
- Use Swift 6 concurrency features
- Add comprehensive tests for new features
- Update documentation for API changes

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

Built with ❤️ using Swift's powerful type system and concurrency model.