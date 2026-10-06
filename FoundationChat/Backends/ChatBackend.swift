import Foundation

@MainActor
protocol ChatBackend: AnyObject {
    var modelID: String { get }
    var displayName: String { get }
    var provider: ModelProviderID { get }
    /// Live backends can chat; stubs return false until wired in Phase 2.
    var isLive: Bool { get }
    var contextSize: Int { get }

    func availability(settings: GenerationSettings) -> ModelAvailabilityStatus
    func prepareSession(instructions: String, messages: [ChatMessage], settings: GenerationSettings)
    func streamResponse(
        to prompt: String,
        settings: GenerationSettings
    ) -> AsyncThrowingStream<String, Error>
    func tokenCount(for text: String) async throws -> Int?
    func tokenCount(forMessages messages: [ChatMessage], instructions: String) async throws -> Int?
}

enum ChatBackendFactory {
    @MainActor
    static func make(modelID: String) -> any ChatBackend {
        let resolved = LocalModelCatalog.resolvedID(modelID)
        guard let descriptor = LocalModelCatalog.descriptor(id: resolved) else {
            return AppleFoundationBackend(modelID: LocalModelCatalog.appleGeneralID)
        }

        switch descriptor.provider {
        case .appleFoundation:
            return AppleFoundationBackend(modelID: descriptor.id)
        case .ollama:
            return OllamaBackendStub(modelID: descriptor.id)
        case .huggingFace:
            return HuggingFaceBackendStub(modelID: descriptor.id)
        case .unsloth:
            return UnslothBackendStub(modelID: descriptor.id)
        }
    }
}
