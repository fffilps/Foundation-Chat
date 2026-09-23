import AppKit
import Foundation
import FoundationModels
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [ChatConversation] = []
    @Published var selectedConversationID: ChatConversation.ID?
    @Published var draft = "" {
        didSet { scheduleDraftTokenRefresh() }
    }
    @Published var availability: ModelAvailabilityStatus = .modelNotReady
    @Published var errorMessage: String?
    @Published private(set) var isGenerating = false
    @Published var settings: GenerationSettings = .default
    @Published private(set) var contextUsage = ContextUsage(
        usedTokens: 0,
        contextSize: 4096,
        draftTokens: 0,
        isEstimate: true
    )
    @Published var showHelp = false
    @Published var showChatOptions = false
    @Published var showInstructions = false
    @Published var helpTopic: HelpTopic = .overview

    private var session: LanguageModelSession?
    private var activeModel = SystemLanguageModel.default
    private var generationTask: Task<Void, Never>?
    private var contextTask: Task<Void, Never>?
    private var draftTokenTask: Task<Void, Never>?
    private var hasFinishedLaunching = false
    private let persistenceURL: URL
    private let settingsURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent("FoundationChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        persistenceURL = folder.appendingPathComponent("conversations.json")
        settingsURL = folder.appendingPathComponent("settings.json")

        loadSettings()
        load()
        if conversations.isEmpty {
            startNewChat()
        } else if selectedConversationID == nil {
            selectedConversationID = conversations.first?.id
        }

        refreshAvailability()
        recreateSession()
        refreshContextUsage()
        hasFinishedLaunching = true
    }

    func updateSettings(_ mutate: (inout GenerationSettings) -> Void) {
        var next = settings
        mutate(&next)
        settings = next
        saveSettings()
        if hasFinishedLaunching {
            recreateSession()
            refreshContextUsage()
        }
    }

    var selectedConversation: ChatConversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    var selectedConversationIndex: Int? {
        guard let selectedConversationID else { return nil }
        return conversations.firstIndex { $0.id == selectedConversationID }
    }

    var canSend: Bool {
        availability.isReady
            && !isGenerating
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !contextUsage.isOverLimit
    }

    var contextWarning: String? {
        guard settings.warnNearContextLimit else { return nil }
        if contextUsage.isOverLimit {
            return "Context window is full. Start a new chat to continue."
        }
        if contextUsage.isNearLimit {
            return "Context is nearly full. Consider starting a new chat soon."
        }
        return nil
    }

    func refreshAvailability() {
        let model = makeModel()
        activeModel = model
        switch model.availability {
        case .available:
            availability = .available
        case .unavailable(.deviceNotEligible):
            availability = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            availability = .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            availability = .modelNotReady
        case .unavailable(let reason):
            availability = .unknown(String(describing: reason))
        @unknown default:
            availability = .unknown("Unknown availability state")
        }
        refreshContextUsage()
    }

    func startNewChat() {
        cancelGeneration()
        let conversation = ChatConversation()
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        draft = ""
        errorMessage = nil
        recreateSession()
        refreshContextUsage()
        save()
    }

    func selectConversation(_ id: ChatConversation.ID) {
        guard id != selectedConversationID else { return }
        cancelGeneration()
        selectedConversationID = id
        draft = ""
        errorMessage = nil
        recreateSession()
        refreshContextUsage()
    }

    func deleteConversation(_ id: ChatConversation.ID) {
        cancelGeneration()
        conversations.removeAll { $0.id == id }
        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
            recreateSession()
            refreshContextUsage()
        }
        if conversations.isEmpty {
            startNewChat()
        } else {
            save()
        }
    }

    func renameSelectedChat(_ title: String) {
        guard let index = selectedConversationIndex else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversations[index].title = trimmed
        conversations[index].updatedAt = .now
        objectWillChange.send()
        save()
    }

    func clearSelectedChatMessages() {
        guard let index = selectedConversationIndex else { return }
        cancelGeneration()
        conversations[index].messages = []
        conversations[index].updatedAt = .now
        objectWillChange.send()
        recreateSession()
        refreshContextUsage()
        save()
    }

    func updateInstructions(_ instructions: String) {
        guard let index = selectedConversationIndex else { return }
        conversations[index].instructions = instructions
        conversations[index].updatedAt = .now
        objectWillChange.send()
        recreateSession()
        refreshContextUsage()
        save()
    }

    func applyPreset(_ preset: InstructionPreset) {
        updateInstructions(preset.instructions)
        if preset.id == "tags" {
            updateSettings { $0.useCase = .contentTagging }
        }
    }

    func applySuggestion(_ suggestion: PromptSuggestion) {
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = suggestion.prompt + " "
        } else {
            draft = suggestion.prompt + "\n\n" + draft
        }
    }

    func sendDraft() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !prompt.isEmpty else { return }
        draft = ""
        send(prompt)
    }

    func stopGenerating() {
        cancelGeneration()
        if let index = selectedConversationIndex,
           let lastIndex = conversations[index].messages.indices.last,
           conversations[index].messages[lastIndex].role == .assistant {
            conversations[index].messages[lastIndex].isStreaming = false
            if conversations[index].messages[lastIndex].text.isEmpty {
                conversations[index].messages[lastIndex].text = "Stopped."
            }
            objectWillChange.send()
        }
        isGenerating = false
        refreshContextUsage()
        save()
    }

    func copyMessage(_ message: ChatMessage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
    }

    func copySelectedTranscript() {
        guard let conversation = selectedConversation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(conversation.exportedTranscript, forType: .string)
    }

    func exportSelectedTranscript() {
        guard let conversation = selectedConversation else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.utf8PlainText]
        panel.nameFieldStringValue = "\(sanitizeFilename(conversation.title)).md"
        panel.title = "Export Chat"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? conversation.exportedTranscript.write(to: url, atomically: true, encoding: .utf8)
    }

    func openHelp(topic: HelpTopic = .overview) {
        helpTopic = topic
        showHelp = true
    }

    func refreshContextUsage() {
        contextTask?.cancel()
        let conversation = selectedConversation
        let draftText = draft
        let contextSize = max(activeModel.contextSize, 1)
        let settingsSnapshot = settings

        contextTask = Task { [weak self] in
            guard let self else { return }

            let estimate = Self.estimateTokens(
                instructions: conversation?.instructions ?? "",
                messages: conversation?.messages ?? [],
                draft: draftText
            )

            var used = estimate.used
            var draftCount = estimate.draft
            var isEstimate = true

            if self.availability.isReady {
                if #available(macOS 26.4, *) {
                    do {
                        let entries = self.transcriptEntries(for: conversation)
                        used = try await self.activeModel.tokenCount(for: entries)
                        if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draftCount = 0
                        } else {
                            draftCount = try await self.activeModel.tokenCount(for: draftText)
                        }
                        isEstimate = false
                    } catch {
                        // Keep estimate if token counting isn't ready yet.
                    }
                }
            }

            if Task.isCancelled { return }
            self.contextUsage = ContextUsage(
                usedTokens: used,
                contextSize: contextSize,
                draftTokens: draftCount,
                isEstimate: isEstimate
            )

            if settingsSnapshot.warnNearContextLimit,
               used >= contextSize,
               self.errorMessage == nil,
               !self.isGenerating {
                self.errorMessage = "Context window is full. Start a new chat to continue."
            }
        }
    }

    private func scheduleDraftTokenRefresh() {
        draftTokenTask?.cancel()
        draftTokenTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshContextUsage()
        }
    }

    private func send(_ prompt: String) {
        refreshAvailability()
        guard availability.isReady else {
            errorMessage = availability.detail
            return
        }

        guard let index = selectedConversationIndex else { return }

        errorMessage = nil

        if session == nil {
            recreateSession()
        }

        conversations[index].messages.append(ChatMessage(role: .user, text: prompt))
        conversations[index].updatedAt = .now
        if conversations[index].title == "New Chat" {
            conversations[index].title = String(prompt.prefix(42))
        }

        let assistantID = UUID()
        conversations[index].messages.append(
            ChatMessage(id: assistantID, role: .assistant, text: "", isStreaming: true)
        )
        objectWillChange.send()
        isGenerating = true
        save()
        refreshContextUsage()

        guard let session else {
            errorMessage = "Could not create a model session."
            markAssistantFinished(assistantID, text: "Session unavailable.")
            return
        }

        let options = makeGenerationOptions()

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = session.streamResponse(to: prompt, options: options)
                for try await snapshot in stream {
                    if Task.isCancelled { break }
                    self.updateAssistantMessage(assistantID, text: snapshot.content, streaming: true)
                }
                self.updateAssistantMessage(assistantID, text: nil, streaming: false)
                self.isGenerating = false
                self.refreshContextUsage()
                self.save()
            } catch is CancellationError {
                self.isGenerating = false
            } catch {
                let message = Self.friendlyError(error)
                self.errorMessage = message
                self.markAssistantFinished(assistantID, text: message)
                self.refreshContextUsage()
            }
        }
    }

    private func makeGenerationOptions() -> GenerationOptions {
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

    private func makeModel() -> SystemLanguageModel {
        let useCase: SystemLanguageModel.UseCase = settings.useCase == .contentTagging
            ? .contentTagging
            : .general
        let guardrails: SystemLanguageModel.Guardrails = settings.guardrails == .permissiveTransformations
            ? .permissiveContentTransformations
            : .default
        return SystemLanguageModel(useCase: useCase, guardrails: guardrails)
    }

    private func updateAssistantMessage(_ id: UUID, text: String?, streaming: Bool) {
        guard let conversationIndex = selectedConversationIndex,
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == id })
        else { return }

        if let text {
            conversations[conversationIndex].messages[messageIndex].text = text
        }
        conversations[conversationIndex].messages[messageIndex].isStreaming = streaming
        conversations[conversationIndex].updatedAt = .now
        objectWillChange.send()
    }

    private func markAssistantFinished(_ id: UUID, text: String) {
        updateAssistantMessage(id, text: text, streaming: false)
        isGenerating = false
        save()
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    private func recreateSession() {
        activeModel = makeModel()

        guard let conversation = selectedConversation else {
            session = LanguageModelSession(
                model: activeModel,
                instructions: ChatConversation.defaultInstructions
            )
            return
        }

        let entries = transcriptEntries(for: conversation)
        session = LanguageModelSession(
            model: activeModel,
            transcript: Transcript(entries: entries)
        )
    }

    private func transcriptEntries(for conversation: ChatConversation?) -> [Transcript.Entry] {
        guard let conversation else {
            return [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: ChatConversation.defaultInstructions))],
                        toolDefinitions: []
                    )
                )
            ]
        }

        var entries: [Transcript.Entry] = [
            .instructions(
                Transcript.Instructions(
                    segments: [.text(Transcript.TextSegment(content: conversation.instructions))],
                    toolDefinitions: []
                )
            )
        ]

        for message in conversation.messages where !message.isStreaming && !message.text.isEmpty {
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

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let decoded = try? JSONDecoder().decode([ChatConversation].self, from: data)
        else { return }
        conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
        selectedConversationID = conversations.first?.id
    }

    private func save() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: persistenceURL, options: [.atomic])
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsURL),
              let decoded = try? JSONDecoder().decode(GenerationSettings.self, from: data)
        else { return }
        settings = decoded
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: [.atomic])
    }

    private func sanitizeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "chat" : cleaned
    }

    private static func estimateTokens(
        instructions: String,
        messages: [ChatMessage],
        draft: String
    ) -> (used: Int, draft: Int) {
        let messageText = messages
            .filter { !$0.isStreaming && !$0.text.isEmpty }
            .map(\.text)
            .joined(separator: "\n")
        let usedSource = instructions + "\n" + messageText
        let used = max(usedSource.count / 4, usedSource.isEmpty ? 0 : 1)
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftCount = trimmedDraft.isEmpty ? 0 : max(trimmedDraft.count / 4, 1)
        return (used, draftCount)
    }

    private static func friendlyError(_ error: Error) -> String {
        let text = error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("guardrail") {
            return "The model declined that request because of safety guardrails. Try rephrasing, or use Permissive transforms for rewriting your own text."
        }
        if lower.contains("context") {
            return "This chat ran out of context. Start a new chat to continue."
        }
        if lower.contains("rate") {
            return "The model is rate limited right now. Wait a moment and try again."
        }
        return text.isEmpty ? "Something went wrong while generating a response." : text
    }
}
