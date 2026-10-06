import Foundation

@MainActor
private final class PlaceholderBackend: ChatBackend {
    let modelID: String
    let provider: ModelProviderID
    let displayName: String

    init(modelID: String, provider: ModelProviderID, displayName: String) {
        self.modelID = modelID
        self.provider = provider
        self.displayName = displayName
    }

    var isLive: Bool { false }

    var contextSize: Int { 4096 }

    func availability(settings: GenerationSettings) -> ModelAvailabilityStatus {
        .providerComingSoon
    }

    func prepareSession(instructions: String, messages: [ChatMessage], settings: GenerationSettings) {
        // No-op until Phase 2 wiring.
    }

    func streamResponse(
        to prompt: String,
        settings: GenerationSettings
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ChatBackendError.notConfigured(provider.title))
        }
    }

    func tokenCount(for text: String) async throws -> Int? { nil }

    func tokenCount(forMessages messages: [ChatMessage], instructions: String) async throws -> Int? {
        nil
    }
}

@MainActor
final class OllamaBackendStub: ChatBackend {
    private let inner: PlaceholderBackend

    init(modelID: String) {
        let name = LocalModelCatalog.descriptor(id: modelID)?.displayName ?? "Ollama"
        inner = PlaceholderBackend(modelID: modelID, provider: .ollama, displayName: name)
    }

    var modelID: String { inner.modelID }
    var displayName: String { inner.displayName }
    var provider: ModelProviderID { inner.provider }
    var isLive: Bool { inner.isLive }
    var contextSize: Int { inner.contextSize }

    func availability(settings: GenerationSettings) -> ModelAvailabilityStatus {
        inner.availability(settings: settings)
    }

    func prepareSession(instructions: String, messages: [ChatMessage], settings: GenerationSettings) {
        inner.prepareSession(instructions: instructions, messages: messages, settings: settings)
    }

    func streamResponse(
        to prompt: String,
        settings: GenerationSettings
    ) -> AsyncThrowingStream<String, Error> {
        inner.streamResponse(to: prompt, settings: settings)
    }

    func tokenCount(for text: String) async throws -> Int? {
        try await inner.tokenCount(for: text)
    }

    func tokenCount(forMessages messages: [ChatMessage], instructions: String) async throws -> Int? {
        try await inner.tokenCount(forMessages: messages, instructions: instructions)
    }
}

@MainActor
final class HuggingFaceBackendStub: ChatBackend {
    private let inner: PlaceholderBackend

    init(modelID: String) {
        let name = LocalModelCatalog.descriptor(id: modelID)?.displayName ?? "Hugging Face"
        inner = PlaceholderBackend(modelID: modelID, provider: .huggingFace, displayName: name)
    }

    var modelID: String { inner.modelID }
    var displayName: String { inner.displayName }
    var provider: ModelProviderID { inner.provider }
    var isLive: Bool { inner.isLive }
    var contextSize: Int { inner.contextSize }

    func availability(settings: GenerationSettings) -> ModelAvailabilityStatus {
        inner.availability(settings: settings)
    }

    func prepareSession(instructions: String, messages: [ChatMessage], settings: GenerationSettings) {
        inner.prepareSession(instructions: instructions, messages: messages, settings: settings)
    }

    func streamResponse(
        to prompt: String,
        settings: GenerationSettings
    ) -> AsyncThrowingStream<String, Error> {
        inner.streamResponse(to: prompt, settings: settings)
    }

    func tokenCount(for text: String) async throws -> Int? {
        try await inner.tokenCount(for: text)
    }

    func tokenCount(forMessages messages: [ChatMessage], instructions: String) async throws -> Int? {
        try await inner.tokenCount(forMessages: messages, instructions: instructions)
    }
}

@MainActor
final class UnslothBackendStub: ChatBackend {
    private let inner: PlaceholderBackend

    init(modelID: String) {
        let name = LocalModelCatalog.descriptor(id: modelID)?.displayName ?? "Unsloth"
        inner = PlaceholderBackend(modelID: modelID, provider: .unsloth, displayName: name)
    }

    var modelID: String { inner.modelID }
    var displayName: String { inner.displayName }
    var provider: ModelProviderID { inner.provider }
    var isLive: Bool { inner.isLive }
    var contextSize: Int { inner.contextSize }

    func availability(settings: GenerationSettings) -> ModelAvailabilityStatus {
        inner.availability(settings: settings)
    }

    func prepareSession(instructions: String, messages: [ChatMessage], settings: GenerationSettings) {
        inner.prepareSession(instructions: instructions, messages: messages, settings: settings)
    }

    func streamResponse(
        to prompt: String,
        settings: GenerationSettings
    ) -> AsyncThrowingStream<String, Error> {
        inner.streamResponse(to: prompt, settings: settings)
    }

    func tokenCount(for text: String) async throws -> Int? {
        try await inner.tokenCount(for: text)
    }

    func tokenCount(forMessages messages: [ChatMessage], instructions: String) async throws -> Int? {
        try await inner.tokenCount(forMessages: messages, instructions: instructions)
    }
}
