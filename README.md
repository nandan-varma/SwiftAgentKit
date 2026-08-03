# SwiftAgentKit

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B%20%7C%20iOS%2026%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A Swift-native SDK for building autonomous AI agents that can interact with language models, execute tools, and maintain conversation context. Inspired by Vercel's AI SDK but designed specifically for Swift's concurrency model and type safety.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Streaming](#streaming)
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
let openAIProvider = try OpenAIProvider(apiKey: "your-api-key")
let agent = Agent(
    provider: openAIProvider,
    tools: [WeatherTool(), MathTool()],
    instructions: "You are a helpful assistant."
)

let result = try await agent.respond(to: "What's 5 times 7?")
print(result.content)

// Using Foundation Models (real on-device Apple Intelligence, macOS/iOS 26+).
// Tools must be registered with the provider as well as the agent — see
// FoundationProvider's docs for why.
let foundationProvider = try FoundationProvider(tools: [WeatherTool(), MathTool()])
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
| Anthropic | ✅ Full | Text generation, tool calls (Messages API), structured output |
| Foundation | ✅ Full | Real on-device Apple Intelligence (macOS/iOS 26+), tool calls, structured output |

Notes:
- `FoundationProvider` builds a fresh model session per call and flattens prior
  conversation turns into the prompt text, since it bridges SwiftAgentKit's
  stateless provider calls onto Apple's stateful `LanguageModelSession` — this
  is a deliberate simplification, not a bug. It also requires tools to be
  registered with the provider itself, not just the `Agent` — see its docs.
- Streaming (`streamText`/`Agent.streamResponse`) is text-only for every
  provider — incremental tool-call deltas aren't currently surfaced.

## API Reference

### Agent

```swift
public actor Agent {
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

    public func streamResponse(
        to input: String,
        maxIterations: Int = 10
    ) -> AsyncThrowingStream<LLMStreamChunk, Error>
}
```

**Parameters:**
- `provider`: LLM provider implementation
- `tools`: Array of available tools for execution
- `instructions`: System prompt defining agent behavior
- `maxIterations`: Maximum tool execution loops (prevents infinite loops)

`Agent` is an actor — calls from outside need `await` even where `respond`/`streamResponse` aren't otherwise asynchronous (e.g. `await agent.streamResponse(to:)`).

### LanguageModelProvider Protocol

```swift
public protocol LanguageModelProvider: Sendable {
    func generateText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) async throws -> LLMResponse

    func streamText(
        messages: [Message],
        tools: [ToolDescriptor]?
    ) -> AsyncThrowingStream<LLMStreamChunk, Error>

    func generateObject<T: Decodable & Sendable>(
        messages: [Message],
        outputSchema: JSONSchema,
        tools: [ToolDescriptor]?
    ) async throws -> T
}
```

### Tool Protocol

```swift
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: JSONSchema { get }
    var outputSchema: JSONSchema { get }

    func execute(input: [String: JSON]) async throws -> ToolResult
}
```

`JSON` is [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON)'s dynamic JSON value type, re-exported by SwiftAgentKit's dependencies.

### Built-in Tools

- **MathTool**: Safe mathematical expression evaluation with injection prevention
- **WeatherTool**: Real current weather via the free, keyless [Open-Meteo](https://open-meteo.com) API

### Error Types

All error types are public and can be caught by name from outside the module:

- `AgentError.maxIterationsExceeded(partial:)`: Tool loop limit reached — carries whatever content/tool results were already produced, so you don't lose completed work
- `ToolError.invalidInput`: Invalid tool parameters
- `OpenAIError.*`: OpenAI API specific errors
- `AnthropicError.*`: Anthropic API specific errors
- `FoundationModelsError.*`: On-device model unavailable, unsupported platform, or structured-output decode failures

## Examples

### Basic Agent Setup

```swift
import SwiftAgentKit

// Initialize provider
let provider = try OpenAIProvider(apiKey: "your-api-key")

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

    func execute(input: [String: JSON]) async throws -> ToolResult {
        guard let value = input["value"]?.int else {
            throw ToolError.invalidInput
        }

        let result = value * 2
        return ToolResult(
            content: "Result: \(result)",
            data: ["result": JSON(result)],
            structuredOutput: JSON(["result": result])
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
} catch AgentError.maxIterationsExceeded(let partial) {
    print("Agent exceeded maximum tool execution iterations")
    print("Partial content so far: \(partial.content)")
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

## Streaming

`Agent.streamResponse(to:)` streams the model's reply incrementally:

```swift
for try await chunk in await agent.streamResponse(to: "Tell me a short story") {
    print(chunk.text, terminator: "")
}
```

- If the agent has **no tools registered**, this streams token-by-token as the
  model generates them.
- If tools **are** registered, a tool call can only be detected by inspecting a
  complete response, so tool calls are resolved the same way as `respond(to:)`
  and the final answer is delivered as a single completing chunk rather than
  re-streamed — a deliberate latency/cost tradeoff, not a bug.
- On hitting `maxIterations`, the stream fails with
  `AgentError.maxIterationsExceeded(partial:)`, same as `respond(to:)`.

## Testing

Most of the test suite requires no OpenAI/Anthropic credentials:

- `MathExpressionEvaluator`, `MathTool`, and the `Agent` tool-execution/streaming
  loop are tested against mock providers.
- `WeatherTool` is tested against the real, keyless Open-Meteo API (no mocks —
  it's the actual service the tool calls in production).
- `AnthropicProviderRequestShapeTests` and `OpenAIProviderRequestShapeTests`
  verify actual request shape (headers, body JSON, tool/error round-tripping)
  against an injected `URLProtocol`-backed mock `URLSession`, without hitting a
  live LLM API.

To also run the live-API and on-device integration tests:

1. Copy `.env.local.example` to `.env.local` and add your API keys:
   ```
   OPENAI_API_KEY=your-openai-api-key-here
   ANTHROPIC_API_KEY=your-anthropic-api-key-here
   ```
2. Run `swift test` on a Mac with Apple Intelligence enabled — `FoundationProviderTests`
   exercises the real on-device model and self-skips (`XCTSkip`) if it's unavailable.
3. `OpenAIProviderTests`, `AnthropicProviderTests`, and the corresponding cases
   in `AgentIntegrationTests` self-skip (`XCTSkip`) when their respective API
   key is absent — each exercises real text generation, tool calling
   (including the full multi-turn tool-result round trip), structured output,
   and streaming against the live API.

Note: live-API and on-device tests are skipped in CI (no API key secrets, no
Apple Intelligence on hosted runners) — CI still validates that the package
builds against the real `FoundationModels` SDK.

### Test Coverage

- ✅ Agent creation, tool execution loop, streaming, and max-iterations handling
- ✅ Provider request-shape correctness (headers, JSON body, tool/error round-tripping) via offline mocks
- ✅ Provider implementations, and full `Agent` integration, against live APIs/on-device model (when credentials/Apple Intelligence available)
- ✅ WeatherTool against the real Open-Meteo API (success and location-not-found cases)
- ✅ Error handling scenarios
- ✅ Context persistence
- ✅ Math expression evaluation, including malformed-input safety
- ✅ Input sanitization

## Requirements

- macOS 26+/iOS 26+ (see `Package.swift`, the source of truth — required for the real `FoundationModels` framework)
- Swift 6.2+
- OpenAI API key (for OpenAI provider)
- Anthropic API key (for Anthropic provider)
- Apple Intelligence enabled (for the Foundation provider; optional if you're only using OpenAI/Anthropic)

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
- Requires macOS 26+/iOS 26+ with Apple Intelligence enabled — throws `FoundationModelsError.modelUnavailable` otherwise
- Check system settings for Apple Intelligence
- Make sure tools are passed to `FoundationProvider(tools:)` as well as `Agent(tools:)` — the provider only calls tools it has been explicitly given

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