import Foundation

public protocol ContextStore {
    func save(messages: [Message]) async throws
    func load() async throws -> [Message]
}

public class InMemoryStore: ContextStore {
    private var messages: [Message] = []
    
    public init() {}
    
    public func save(messages: [Message]) async throws {
        self.messages = messages
    }
    
    public func load() async throws -> [Message] {
        return messages
    }
}

public class AgentContext {
    private let store: ContextStore
    public private(set) var messages: [Message] = []
    
    public init(store: ContextStore = InMemoryStore()) {
        self.store = store
    }
    
    public func addMessage(_ message: Message) {
        messages.append(message)
        // TODO: Implement async saving without data races
        // Task.detached { [messages = self.messages, store = self.store] in
        //     try? await store.save(messages: messages)
        // }
    }
    
    public func load() async throws {
        messages = try await store.load()
    }
}