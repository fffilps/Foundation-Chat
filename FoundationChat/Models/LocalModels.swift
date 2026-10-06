import Foundation

enum ModelProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleFoundation
    case ollama
    case huggingFace
    case unsloth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleFoundation: "Apple Foundation"
        case .ollama: "Ollama"
        case .huggingFace: "Hugging Face"
        case .unsloth: "Unsloth"
        }
    }
}

enum LocalModelKind: String, Codable, Sendable {
    case foundation
    case specialty
    case smallLocal
}

struct LocalModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var displayName: String
    var provider: ModelProviderID
    var kind: LocalModelKind
    /// Approximate download / install size in bytes (0 when managed by the OS).
    var approximateInstallBytes: UInt64
    var minRAMGB: Double
    var recommendedRAMGB: Double
    var requiresAppleIntelligence: Bool
    /// False for Phase 1 stubs (Ollama / Hugging Face / Unsloth).
    var isLive: Bool
    var notes: String
    /// Optional Apple use-case mapping for live Foundation Models entries.
    var appleUseCase: ModelUseCaseOption?

    var providerTitle: String { provider.title }
}

enum LocalModelCatalog {
    static let appleGeneralID = "apple-fm-general"
    static let appleTaggingID = "apple-fm-content-tagging"
    static let ollamaPlaceholderID = "ollama-placeholder"
    static let huggingFacePlaceholderID = "huggingface-placeholder"
    static let unslothPlaceholderID = "unsloth-placeholder"

    static let all: [LocalModelDescriptor] = [
        LocalModelDescriptor(
            id: appleGeneralID,
            displayName: "Apple Foundation Model — General",
            provider: .appleFoundation,
            kind: .foundation,
            approximateInstallBytes: 0,
            minRAMGB: 8,
            recommendedRAMGB: 16,
            requiresAppleIntelligence: true,
            isLive: true,
            notes: "On-device Apple Intelligence general chat model.",
            appleUseCase: .general
        ),
        LocalModelDescriptor(
            id: appleTaggingID,
            displayName: "Apple Foundation Model — Content Tagging",
            provider: .appleFoundation,
            kind: .specialty,
            approximateInstallBytes: 0,
            minRAMGB: 8,
            recommendedRAMGB: 16,
            requiresAppleIntelligence: true,
            isLive: true,
            notes: "Specialty adapter for tags, topics, and short structured labels.",
            appleUseCase: .contentTagging
        ),
        LocalModelDescriptor(
            id: ollamaPlaceholderID,
            displayName: "Ollama (coming soon)",
            provider: .ollama,
            kind: .smallLocal,
            approximateInstallBytes: 4_294_967_296,
            minRAMGB: 8,
            recommendedRAMGB: 16,
            requiresAppleIntelligence: false,
            isLive: false,
            notes: "Placeholder for local Ollama models via localhost:11434.",
            appleUseCase: nil
        ),
        LocalModelDescriptor(
            id: huggingFacePlaceholderID,
            displayName: "Hugging Face (coming soon)",
            provider: .huggingFace,
            kind: .smallLocal,
            approximateInstallBytes: 4_294_967_296,
            minRAMGB: 8,
            recommendedRAMGB: 16,
            requiresAppleIntelligence: false,
            isLive: false,
            notes: "Placeholder for cached GGUF / MLX weights from Hugging Face Hub.",
            appleUseCase: nil
        ),
        LocalModelDescriptor(
            id: unslothPlaceholderID,
            displayName: "Unsloth export (coming soon)",
            provider: .unsloth,
            kind: .smallLocal,
            approximateInstallBytes: 2_147_483_648,
            minRAMGB: 8,
            recommendedRAMGB: 16,
            requiresAppleIntelligence: false,
            isLive: false,
            notes: "Placeholder for importing Unsloth-exported local weights.",
            appleUseCase: nil
        )
    ]

    static func descriptor(id: String) -> LocalModelDescriptor? {
        all.first { $0.id == id }
    }

    static func descriptor(forUseCase useCase: ModelUseCaseOption) -> LocalModelDescriptor {
        switch useCase {
        case .general:
            return descriptor(id: appleGeneralID)!
        case .contentTagging:
            return descriptor(id: appleTaggingID)!
        }
    }

    static func resolvedID(_ id: String?) -> String {
        if let id, descriptor(id: id) != nil {
            return id
        }
        return appleGeneralID
    }
}
