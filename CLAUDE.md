# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                                          # build the library
swift test                                           # run the full test suite
swift test --filter AnthropicProviderRequestShapeTests  # run one test suite
swift test --filter testHeaderUsesRawAPIKey          # run one test by name
swift package generate-documentation                 # build the DocC catalog (requires swift-docc-plugin, already a dependency)
```

Live-API/on-device tests are opt-in and self-skip otherwise:
- Copy `.env.local.example` to `.env.local` and set `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` to run the live-integration tests (`TestConfig.hasOpenAIKey`/`hasAnthropicKey` gate them with `XCTSkip`) — `OpenAIProviderTests`, `AnthropicProviderTests`, and the corresponding `AgentIntegrationTests` cases.
- `FoundationProviderTests` exercises the real on-device model and self-skips via `XCTSkip` unless run on a Mac with Apple Intelligence enabled.
- `AnthropicProviderRequestShapeTests`/`OpenAIProviderRequestShapeTests` (note the naming: *RequestShapeTests* = offline, the bare `AnthropicProviderTests`/`OpenAIProviderTests` = live) run fully offline against a mocked `URLSession` (see `Tests/SwiftAgentKitTests/MockURLProtocol.swift`) — no key needed, and this is where provider protocol-correctness bugs should be caught.
- `WeatherTool` is tested against the real Open-Meteo API (no key needed, no gating — it's free and always available).

Requires macOS 26+/Xcode 26+ (see `Package.swift`) — this is not a preference, it's a hard requirement for the real `FoundationModels` framework used by `FoundationProvider`.

## Architecture

`Agent` (an actor) is the orchestrator: it holds a `LanguageModelProvider`, an array of `Tool`s, and an `AgentContext` (conversation history behind a pluggable `ContextStore`). `respond(to:)` and `streamResponse(to:)` both funnel through a private `resolveTurn` loop in `Sources/SwiftAgentKit/Core/Agent.swift` that repeatedly calls `provider.generateText`, executes any returned tool calls, feeds results back into the context, and loops until a tool-call-free response or `maxIterations` is hit (`AgentError.maxIterationsExceeded(partial:)` carries whatever was produced so far). Because `Agent` is an actor, external callers need `await` even on `streamResponse`, which isn't itself `async`.

### Two different ways a provider can report tool use

`LanguageModelProvider.generateText` returns an `LLMResponse` with two distinct, non-overlapping channels — this split exists because of how Apple's Foundation Models framework works, and reading only `Agent.swift` won't make it obvious you need to check both:
- `toolCalls`: calls the provider wants the `Agent` loop to execute itself (OpenAI, Anthropic — the REST APIs hand control back to the caller).
- `executedToolResults`: calls the provider already executed internally before returning (`FoundationProvider` — `LanguageModelSession.respond(to:)` runs its own tool loop and only returns once fully resolved). `Agent.resolveTurn` short-circuits and returns immediately when this is populated.

### Provider implementations

- `OpenAIProvider` / `AnthropicProvider` (`Sources/SwiftAgentKit/Providers/`): thin REST clients over `URLSession`, injectable via the `session:` init parameter specifically so `Tests/SwiftAgentKitTests/MockURLProtocol.swift` can verify request shape offline. Anthropic's message model requires care: `system` is a top-level request field (not a message), and tool round-tripping needs `tool_use`/`tool_result` content blocks, not plain text — see the private `AnthropicContentBlock` enum and `splitForAnthropic` in `AnthropicProvider.swift`.
- `FoundationProvider` (`Sources/SwiftAgentKit/Providers/FoundationProvider.swift` + `FoundationModelsToolAdapter.swift`, the latter entirely guarded by `#if canImport(FoundationModels)`): bridges SwiftAgentKit's stateless, full-history-per-call provider protocol onto Apple's stateful `LanguageModelSession` by creating a fresh session per call and flattening prior turns into plain prompt text (`FoundationModelsBridge.renderPrompt`) — a deliberate simplification, not a bug, since reconstructing a `Transcript` from an arbitrary `[Message]` array isn't a supported mapping. **Tools must be registered twice**: once in `Agent(tools:)` (for the descriptor sent to the model) and once in `FoundationProvider(tools:)` (the actual executable `Tool` the framework calls back into via `FoundationModelsToolAdapter`) — if the two lists diverge, a tool silently becomes uncallable. Structured output (`generateObject`) uses the real `session.respond(to:schema:)` API rather than the prose-JSON-and-hope-it-parses trick the other two providers use.

### JSONSchema introspection

The `JSONSchema` type (from the `swift-json-schema` dependency) only exposes `Codable` conformance and static factories publicly — its case storage is internal to that package, so there's no way to `switch` on a schema's shape from this module. `Sources/SwiftAgentKit/Core/JSONSchema+RawJSON.swift` provides the one sanctioned workaround (`JSONSchema.asJSON()`: encode → `JSONSerialization` → `SwiftyJSON.JSON`), reused by the OpenAI/Anthropic tool-descriptor converters and by `FoundationModelsToolAdapter`'s `DynamicGenerationSchema` builder (which walks the raw JSON to construct Apple's runtime schema type, since our tool schemas aren't known at compile time the way `@Generable` macro types are).

### Tool protocol

`Tool` (`Sources/SwiftAgentKit/Core/Tool.swift`) describes both its schema (`inputSchema`/`outputSchema` as `JSONSchema`) and its executable body (`execute(input: [String: JSON])`) — `JSON` is SwiftyJSON's dynamic value type, used throughout instead of `Any` for `Sendable` safety. `MathTool` (`Sources/SwiftAgentKit/Tools/MathTool.swift`) delegates actual expression evaluation to `MathExpressionEvaluator`, a hand-written recursive-descent parser — this exists specifically because `NSExpression` raises an uncatchable Objective-C exception on malformed input, which is unacceptable for something an LLM's output feeds into. `WeatherTool` (`Sources/SwiftAgentKit/Tools/WeatherTool.swift`) calls the real, keyless Open-Meteo API — geocoding the location, then fetching current conditions — and throws `WeatherToolError.locationNotFound` for unresolvable locations.

Every domain gets its own public `Error` enum rather than overloading `ToolError`/a shared catch-all — `AgentError`, `OpenAIError`, `AnthropicError`, `FoundationModelsError`, `WeatherToolError` (all in `Sources/SwiftAgentKit/Core/Errors.swift`) — follow this pattern for anything new.
