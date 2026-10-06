import Foundation
import FoundationModels

@MainActor
final class AppleFoundationBackend: ChatBackend {
    let modelID: String
    private var activeModel = SystemLanguageModel.default
    private var session: LanguageModelSession?

    init(modelID: String) {
        self.modelID = LocalModelCatalog.resolvedID(modelID)
    }

    var displayName: String {
        LocalModelCatalog.descriptor(id: modelID)?.displayName ?? "Apple Foundation Model"
    }

    var provider: ModelProviderID { .appleFoundation }

    var isLive: Bool { true }

    var contextSize: Int {
        max(activeModel.contextSize, 1)
    }

    func availability(settings: GenerationSettings) -> ModelAvailabilityStatus {
        let model = makeModel(settings: settings)
        activeModel = model
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable(let reason):
            return .unknown(String(describing: reason))
        @unknown default:
            return .unknown("Unknown availability state")
        }
    }

    func prepareSession(instructions: String, messages: [ChatMessage], settings: GenerationSettings) {
        activeModel = makeModel(settings: settings)
        let entries = Self.transcriptEntries(instructions: instructions, messages: messages)
        session = LanguageModelSession(
            model: activeModel,
            transcript: Transcript(entries: entries)
        )
    }

    func streamResponse(
        to prompt: String,
        settings: GenerationSettings
    ) -> AsyncThrowingStream<String, Error> {
        let options = Self.makeGenerationOptions(settings: settings)
        guard let session else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: ChatBackendError.sessionUnavailable)
            }
        }

        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let stream = session.streamResponse(to: prompt, options: options)
                    for try await snapshot in stream {
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func tokenCount(for text: String) async throws -> Int? {
        if #available(macOS 26.4, *) {
            return try await activeModel.tokenCount(for: text)
        }
        return nil
    }

    func tokenCount(forMessages messages: [ChatMessage], instructions: String) async throws -> Int? {
        if #available(macOS 26.4, *) {
            let entries = Self.transcriptEntries(instructions: instructions, messages: messages)
            return try await activeModel.tokenCount(for: entries)
        }
        return nil
    }

    private func makeModel(settings: GenerationSettings) -> SystemLanguageModel {
        let descriptor = LocalModelCatalog.descriptor(id: modelID)
        let useCaseOption = descriptor?.appleUseCase ?? settings.useCase
        let useCase: SystemLanguageModel.UseCase = useCaseOption == .contentTagging
            ? .contentTagging
            : .general
        let guardrails: SystemLanguageModel.Guardrails = settings.guardrails == .permissiveTransformations
            ? .permissiveContentTransformations
            : .default
        return SystemLanguageModel(useCase: useCase, guardrails: guardrails)
    }

    private static func makeGenerationOptions(settings: GenerationSettings) -> GenerationOptions {
        var options = GenerationOptions()
        if settings.greedySampling {
            options.sampling = .greedy
        }
        if settings.useCustomTemperature {
            options.temperature = settings.temperature
        }
        if settings.limitResponseTokens {
            options.maximumResponseTokens = max(settings.maximumResponseTokens, 16)
        }
        return options
    }

    private static func transcriptEntries(
        instructions: String,
        messages: [ChatMessage]
    ) -> [Transcript.Entry] {
        var entries: [Transcript.Entry] = [
            .instructions(
                Transcript.Instructions(
                    segments: [.text(Transcript.TextSegment(content: instructions))],
                    toolDefinitions: []
                )
            )
        ]

        for message in messages where !message.isStreaming && !message.text.isEmpty {
            switch message.role {
            case .user:
                entries.append(
                    .prompt(
                        Transcript.Prompt(
                            segments: [.text(Transcript.TextSegment(content: message.text))]
                        )
                    )
                )
            case .assistant:
                entries.append(
                    .response(
                        Transcript.Response(
                            assetIDs: [],
                            segments: [.text(Transcript.TextSegment(content: message.text))]
                        )
                    )
                )
            case .system:
                continue
            }
        }

        return entries
    }
}

enum ChatBackendError: LocalizedError {
    case sessionUnavailable
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            "Could not create a model session."
        case .notConfigured(let provider):
            "\(provider) is not configured yet. Coming soon."
        }
    }
}
