import AppKit
import Foundation
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
    @Published private(set) var machineProfile = HardwareProfiler.profile(appleIntelligenceAvailable: false)
    @Published private(set) var selectedFit = FitResult(
        verdict: .unsupported,
        summary: "Checking…",
        detail: ""
    )
    @Published var showHelp = false
    @Published var showChatOptions = false
    @Published var showInstructions = false
    @Published var helpTopic: HelpTopic = .overview

    private var activeBackend: any ChatBackend
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
        activeBackend = ChatBackendFactory.make(modelID: LocalModelCatalog.appleGeneralID)

        loadSettings()
        activeBackend = ChatBackendFactory.make(modelID: settings.selectedModelID)
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

    var activeModelDisplayName: String {
        activeBackend.displayName
    }

    var selectedModelDescriptor: LocalModelDescriptor {
        LocalModelCatalog.descriptor(id: settings.selectedModelID)
            ?? LocalModelCatalog.descriptor(id: LocalModelCatalog.appleGeneralID)!
    }

    var showsAppleControls: Bool {
        selectedModelDescriptor.provider == .appleFoundation && selectedModelDescriptor.isLive
    }

    func updateSettings(_ mutate: (inout GenerationSettings) -> Void) {
        var next = settings
        let previous = settings
        mutate(&next)
        next.selectedModelID = LocalModelCatalog.resolvedID(next.selectedModelID)

        if next.selectedModelID != previous.selectedModelID {
            if let useCase = LocalModelCatalog.descriptor(id: next.selectedModelID)?.appleUseCase {
                next.useCase = useCase
            }
        } else if next.useCase != previous.useCase,
                  LocalModelCatalog.descriptor(id: next.selectedModelID)?.provider == .appleFoundation {
            next.selectedModelID = LocalModelCatalog.descriptor(forUseCase: next.useCase).id
        }

        let modelChanged = next.selectedModelID != settings.selectedModelID
        settings = next
        saveSettings()
        if modelChanged {
            activeBackend = ChatBackendFactory.make(modelID: settings.selectedModelID)
        }
        if hasFinishedLaunching {
            refreshAvailability()
            recreateSession()
            refreshContextUsage()
        }
    }

    func selectModel(id: String) {
        updateSettings { settings in
            settings.selectedModelID = LocalModelCatalog.resolvedID(id)
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
            && selectedFit.canAttemptChat
            && activeBackend.isLive
            && !isGenerating
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !contextUsage.isOverLimit
    }

    var sendBlockedReason: String? {
        if isGenerating { return nil }
        if !activeBackend.isLive || selectedFit.verdict == .comingSoon {
            return selectedFit.detail.isEmpty ? availability.detail : selectedFit.detail
        }
        if !selectedFit.canAttemptChat {
            return selectedFit.detail
        }
        if !availability.isReady {
            return availability.detail
        }
        if contextUsage.isOverLimit {
            return "Context window is full. Start a new chat to continue."
        }
        return nil
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
        availability = activeBackend.availability(settings: settings)
        let appleReady = availability.isReady
            || (activeBackend.provider != .appleFoundation && probeAppleReady())
        machineProfile = HardwareProfiler.profile(appleIntelligenceAvailable: appleReady)
        // For Apple backends, fit should use the real availability signal.
        var profile = machineProfile
        if activeBackend.provider == .appleFoundation {
            profile.appleIntelligenceAvailable = availability.isReady
        }
        machineProfile = profile
        selectedFit = ModelRequirementsSheet.evaluate(
            model: selectedModelDescriptor,
            profile: machineProfile
        )
        refreshContextUsage()
    }

    func refreshMachineProfile() {
        refreshAvailability()
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
            selectModel(id: LocalModelCatalog.appleTaggingID)
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
        NSPasteboard.general.setString(
            conversation.exportedTranscript(assistantName: activeModelDisplayName),
            forType: .string
        )
    }

    func exportSelectedTranscript() {
        guard let conversation = selectedConversation else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.utf8PlainText]
        panel.nameFieldStringValue = "\(sanitizeFilename(conversation.title)).md"
        panel.title = "Export Chat"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? conversation.exportedTranscript(assistantName: activeModelDisplayName)
            .write(to: url, atomically: true, encoding: .utf8)
    }

    func openHelp(topic: HelpTopic = .overview) {
        helpTopic = topic
        showHelp = true
    }

    func refreshContextUsage() {
        contextTask?.cancel()
        let conversation = selectedConversation
        let draftText = draft
        let contextSize = max(activeBackend.contextSize, 1)
        let settingsSnapshot = settings
        let backend = activeBackend

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

            if self.availability.isReady, backend.isLive {
                do {
                    if let exact = try await backend.tokenCount(
                        forMessages: conversation?.messages ?? [],
                        instructions: conversation?.instructions ?? ChatConversation.defaultInstructions
                    ) {
                        used = exact
                        isEstimate = false
                    }
                    if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        draftCount = 0
                    } else if let draftExact = try await backend.tokenCount(for: draftText) {
                        draftCount = draftExact
                        isEstimate = false
                    }
                } catch {
                    // Keep estimate if token counting isn't ready yet.
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
        guard availability.isReady, activeBackend.isLive, selectedFit.canAttemptChat else {
            errorMessage = sendBlockedReason ?? availability.detail
            return
        }

        guard let index = selectedConversationIndex else { return }

        errorMessage = nil
        recreateSession()

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

        let stream = activeBackend.streamResponse(to: prompt, settings: settings)

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await content in stream {
                    if Task.isCancelled { break }
                    self.updateAssistantMessage(assistantID, text: content, streaming: true)
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
        let conversation = selectedConversation
        activeBackend.prepareSession(
            instructions: conversation?.instructions ?? ChatConversation.defaultInstructions,
            messages: conversation?.messages ?? [],
            settings: settings
        )
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

    private func probeAppleReady() -> Bool {
        let probe = AppleFoundationBackend(modelID: LocalModelCatalog.appleGeneralID)
        return probe.availability(settings: settings).isReady
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
        if lower.contains("coming soon") || lower.contains("not configured") {
            return text
        }
        return text.isEmpty ? "Something went wrong while generating a response." : text
    }
}
