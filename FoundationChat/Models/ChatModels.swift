import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    var text: String
    let createdAt: Date
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        createdAt: Date = .now,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
}

enum ModelUseCaseOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case general
    case contentTagging

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .contentTagging: "Content Tagging"
        }
    }

    var detail: String {
        switch self {
        case .general:
            "Everyday chat, writing, Q&A, and brainstorming."
        case .contentTagging:
            "Best for labels, categories, topics, and short structured tags."
        }
    }
}

enum GuardrailOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case permissiveTransformations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .permissiveTransformations: "Permissive transforms"
        }
    }

    var detail: String {
        switch self {
        case .standard:
            "Default Apple Intelligence safety guardrails."
        case .permissiveTransformations:
            "Looser rules for rewriting/transforming content you already have."
        }
    }
}

struct GenerationSettings: Codable, Equatable, Sendable {
    var selectedModelID: String = LocalModelCatalog.appleGeneralID
    var useCase: ModelUseCaseOption = .general
    var guardrails: GuardrailOption = .standard
    var temperature: Double = 0.7
    var useCustomTemperature: Bool = false
    var maximumResponseTokens: Int = 1024
    var limitResponseTokens: Bool = false
    var greedySampling: Bool = false
    var showContextMeter: Bool = true
    var warnNearContextLimit: Bool = true

    static let `default` = GenerationSettings()

    enum CodingKeys: String, CodingKey {
        case selectedModelID
        case useCase
        case guardrails
        case temperature
        case useCustomTemperature
        case maximumResponseTokens
        case limitResponseTokens
        case greedySampling
        case showContextMeter
        case warnNearContextLimit
    }

    init(
        selectedModelID: String = LocalModelCatalog.appleGeneralID,
        useCase: ModelUseCaseOption = .general,
        guardrails: GuardrailOption = .standard,
        temperature: Double = 0.7,
        useCustomTemperature: Bool = false,
        maximumResponseTokens: Int = 1024,
        limitResponseTokens: Bool = false,
        greedySampling: Bool = false,
        showContextMeter: Bool = true,
        warnNearContextLimit: Bool = true
    ) {
        self.selectedModelID = LocalModelCatalog.resolvedID(selectedModelID)
        self.useCase = useCase
        self.guardrails = guardrails
        self.temperature = temperature
        self.useCustomTemperature = useCustomTemperature
        self.maximumResponseTokens = maximumResponseTokens
        self.limitResponseTokens = limitResponseTokens
        self.greedySampling = greedySampling
        self.showContextMeter = showContextMeter
        self.warnNearContextLimit = warnNearContextLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModelID = LocalModelCatalog.resolvedID(
            try container.decodeIfPresent(String.self, forKey: .selectedModelID)
        )
        useCase = try container.decodeIfPresent(ModelUseCaseOption.self, forKey: .useCase) ?? .general
        guardrails = try container.decodeIfPresent(GuardrailOption.self, forKey: .guardrails) ?? .standard
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.7
        useCustomTemperature = try container.decodeIfPresent(Bool.self, forKey: .useCustomTemperature) ?? false
        maximumResponseTokens = try container.decodeIfPresent(Int.self, forKey: .maximumResponseTokens) ?? 1024
        limitResponseTokens = try container.decodeIfPresent(Bool.self, forKey: .limitResponseTokens) ?? false
        greedySampling = try container.decodeIfPresent(Bool.self, forKey: .greedySampling) ?? false
        showContextMeter = try container.decodeIfPresent(Bool.self, forKey: .showContextMeter) ?? true
        warnNearContextLimit = try container.decodeIfPresent(Bool.self, forKey: .warnNearContextLimit) ?? true

        // Keep Apple model ID and use case aligned when loading older settings.
        if let descriptor = LocalModelCatalog.descriptor(id: selectedModelID),
           let appleUseCase = descriptor.appleUseCase {
            useCase = appleUseCase
        } else if selectedModelID == LocalModelCatalog.appleGeneralID
            || selectedModelID == LocalModelCatalog.appleTaggingID {
            selectedModelID = LocalModelCatalog.descriptor(forUseCase: useCase).id
        }
    }
}

struct InstructionPreset: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let instructions: String
}

enum PromptSuggestion: Identifiable, Sendable {
    case summarize
    case rewrite
    case explain
    case brainstorm
    case codeReview
    case outline

    var id: String { title }

    var title: String {
        switch self {
        case .summarize: "Summarize"
        case .rewrite: "Rewrite clearly"
        case .explain: "Explain simply"
        case .brainstorm: "Brainstorm"
        case .codeReview: "Review code"
        case .outline: "Make an outline"
        }
    }

    var prompt: String {
        switch self {
        case .summarize:
            "Summarize the key points clearly and briefly:"
        case .rewrite:
            "Rewrite this so it’s clearer and more natural, without changing the meaning:"
        case .explain:
            "Explain this in plain language for a smart beginner:"
        case .brainstorm:
            "Brainstorm 8 useful ideas for:"
        case .codeReview:
            "Review this code for bugs, clarity, and simpler alternatives:"
        case .outline:
            "Create a clean outline for:"
        }
    }

    static let all: [PromptSuggestion] = [
        .summarize, .rewrite, .explain, .brainstorm, .codeReview, .outline
    ]
}

struct ChatConversation: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var instructions: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        instructions: String = ChatConversation.defaultInstructions,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.instructions = instructions
        self.updatedAt = updatedAt
    }

    func exportedTranscript(assistantName: String = "Assistant") -> String {
        var lines: [String] = ["# \(title)", ""]
        if !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Instructions: \(instructions)")
            lines.append("")
        }
        for message in messages where !message.text.isEmpty {
            let speaker = message.role == .user ? "You" : assistantName
            lines.append("\(speaker):")
            lines.append(message.text)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static let defaultInstructions = """
    You are a helpful on-device assistant powered by Apple Foundation Models. \
    Be clear, concise, and practical. Prefer short paragraphs and bullet lists when useful. \
    Format replies in Markdown (headings, bold, lists, and fenced code blocks) when it improves readability.
    """

    static let presets: [InstructionPreset] = [
        InstructionPreset(
            id: "default",
            title: "Default",
            subtitle: "Balanced everyday assistant",
            instructions: defaultInstructions
        ),
        InstructionPreset(
            id: "concise",
            title: "Concise",
            subtitle: "Short answers only",
            instructions: """
            Be extremely concise. Prefer one short paragraph or a tight bullet list. \
            Skip filler and disclaimers unless safety-critical.
            """
        ),
        InstructionPreset(
            id: "coding",
            title: "Coding",
            subtitle: "Practical engineering help",
            instructions: """
            You are a senior software engineer. Focus on correct, idiomatic code. \
            Explain briefly, then provide code in fenced Markdown code blocks with a language tag. \
            Call out edge cases and tradeoffs.
            """
        ),
        InstructionPreset(
            id: "writing",
            title: "Writing",
            subtitle: "Editing and drafting",
            instructions: """
            You are a careful writing coach. Improve clarity, flow, and tone. \
            Preserve the author’s meaning. Offer a revised version first, then short notes.
            """
        ),
        InstructionPreset(
            id: "teacher",
            title: "Teacher",
            subtitle: "Step-by-step explanations",
            instructions: """
            Teach patiently. Break ideas into steps, use simple examples, and check understanding. \
            Avoid jargon unless you define it.
            """
        ),
        InstructionPreset(
            id: "tags",
            title: "Tagger",
            subtitle: "Labels and categories",
            instructions: """
            Extract compact tags, categories, topics, and entities. \
            Prefer short lists. Do not invent facts that aren’t in the input.
            """
        )
    ]
}

struct ContextUsage: Equatable, Sendable {
    var usedTokens: Int
    var contextSize: Int
    var draftTokens: Int
    var isEstimate: Bool

    var remainingTokens: Int { max(contextSize - usedTokens, 0) }

    var fillRatio: Double {
        guard contextSize > 0 else { return 0 }
        return min(Double(usedTokens) / Double(contextSize), 1)
    }

    var projectedRatio: Double {
        guard contextSize > 0 else { return 0 }
        return min(Double(usedTokens + draftTokens) / Double(contextSize), 1)
    }

    var statusLabel: String {
        if isEstimate {
            return "~\(usedTokens) / \(contextSize) tokens (estimate)"
        }
        return "\(usedTokens) / \(contextSize) tokens"
    }

    var isNearLimit: Bool { fillRatio >= 0.85 }
    var isOverLimit: Bool { usedTokens >= contextSize }
}

enum ModelAvailabilityStatus: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case providerComingSoon
    case unknown(String)

    var isReady: Bool {
        self == .available
    }

    var title: String {
        switch self {
        case .available:
            "On-device model ready"
        case .deviceNotEligible:
            "This Mac can’t run Foundation Models"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off"
        case .modelNotReady:
            "Model is still downloading"
        case .providerComingSoon:
            "Provider coming soon"
        case .unknown:
            "Model unavailable"
        }
    }

    var detail: String {
        switch self {
        case .available:
            "Responses stay on this Mac. No account or API key needed."
        case .deviceNotEligible:
            "Foundation Models needs Apple Silicon and Apple Intelligence support."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in System Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            "Apple is preparing the on-device model. Keep the Mac awake and connected until it finishes."
        case .providerComingSoon:
            "This provider is stubbed for a future local plug-in. Pick an Apple Foundation Model to chat now."
        case .unknown(let message):
            message
        }
    }
}

enum HelpTopic: String, CaseIterable, Identifiable {
    case overview
    case context
    case instructions
    case options
    case tips
    case cli
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .context: "Context window"
        case .instructions: "Instructions"
        case .options: "Generation options"
        case .tips: "Tips"
        case .cli: "Related to `fm`"
        case .privacy: "Privacy"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "sparkles"
        case .context: "gauge.with.dots.needle.67percent"
        case .instructions: "text.alignleft"
        case .options: "slider.horizontal.3"
        case .tips: "lightbulb"
        case .cli: "terminal"
        case .privacy: "lock.shield"
        }
    }

    var body: String {
        switch self {
        case .overview:
            """
            Foundation Chat is a Mac GUI for local models, starting with Apple’s on-device Foundation Models — the same SystemLanguageModel used by the `fm` CLI.

            Use it to chat, rewrite, summarize, brainstorm, and get coding help without leaving a normal Mac app. Assistant replies that include Markdown are rendered in the chat bubble.
            """
        case .context:
            """
            The model remembers this chat’s instructions plus earlier messages inside a fixed context window (often 4,096–8,192 tokens depending on your Mac/OS).

            The context meter shows how full that window is. When it gets high, start a new chat or shorten earlier turns. Long chats can fail with a context-size error.
            """
        case .instructions:
            """
            Instructions are the system guidance for a chat (like `fm chat --instructions`).

            They steer tone and behavior for the whole conversation. Changing instructions rebuilds the session while keeping your visible messages.
            """
        case .options:
            """
            Generation options mirror what power users tweak in the CLI:

            • Model — pick Apple Foundation Models now; Ollama / Hugging Face / Unsloth are stubbed for later
            • Fit badge — uses this Mac’s RAM, free disk, and Apple Intelligence readiness
            • Temperature — higher is more varied, lower is more focused
            • Max tokens — caps how long a reply can be
            • Greedy sampling — more deterministic answers
            • Use case — General chat or Content Tagging (Apple models)
            • Guardrails — Standard safety, or permissive transforms for rewriting your own text
            """
        case .tips:
            """
            • Be specific: paste the text you want changed
            • Use presets for coding, writing, or concise mode
            • Model replies render as Markdown (bold, lists, headings, code blocks)
            • Copy any reply from the message menu
            • Export a chat when you want a Markdown transcript
            • If answers drift, start a new chat with fresh context
            """
        case .cli:
            """
            Terminal equivalents:

            • `fm available` → model status in the app
            • `fm chat` → this chat window
            • `fm respond` → send one message
            • `fm count-tokens` → context meter / token counts
            • `--instructions` → Instructions sheet
            • `--greedy` / sampling options → Settings
            """
        case .privacy:
            """
            Inference runs on-device with Apple Intelligence. This app does not send your chats to a third-party API and does not require an account or API key.

            Chats are saved locally in your Mac’s Application Support folder for Foundation Chat.
            """
        }
    }
}
