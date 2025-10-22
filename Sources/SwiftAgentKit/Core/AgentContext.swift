import Foundation

public protocol ContextStore: Sendable {
    func save(messages: [Message]) async throws
    func load() async throws -> [Message]
}

public class InMemoryStore: @unchecked Sendable, ContextStore {
    private var messages: [Message] = []

    public init() {}

    public func save(messages: [Message]) async throws {
        self.messages = messages
    }

    public func load() async throws -> [Message] {
        return messages
    }
}

public actor AgentContext {
    private let store: ContextStore
    public private(set) var messages: [Message] = []
    
    public init(store: ContextStore = InMemoryStore()) {
        self.store = store
    }
    
    public func addMessage(_ message: Message) async {
        messages.append(message)
        try? await store.save(messages: messages)
    }
    
    public func load() async throws {
        messages = try await store.load()
    }
}