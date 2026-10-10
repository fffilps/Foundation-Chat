import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            ChatDetailView()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { store.refreshAvailability() }
        .sheet(isPresented: $store.showHelp) {
            HelpSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showChatOptions) {
            ChatOptionsSheet()
                .environmentObject(store)
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedConversationID },
            set: { id in
                if let id { store.selectConversation(id) }
            }
        )) {
            Section("Chats") {
                ForEach(store.conversations) { conversation in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(conversation.id)
                    .contextMenu {
                        Button("Export…") {
                            store.selectConversation(conversation.id)
                            store.exportSelectedTranscript()
                        }
                        Button("Copy Transcript") {
                            store.selectConversation(conversation.id)
                            store.copySelectedTranscript()
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            store.deleteConversation(conversation.id)
                        }
                    }
                }
            }

            Section("Learn") {
                Button {
                    store.openHelp(topic: .overview)
                } label: {
                    Label("Help & Features", systemImage: "questionmark.circle")
                }
                Button {
                    store.openHelp(topic: .context)
                } label: {
                    Label("Context Window", systemImage: "gauge.with.dots.needle.67percent")
                }
                Button {
                    store.openHelp(topic: .cli)
                } label: {
                    Label("CLI Cheat Sheet", systemImage: "terminal")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Foundation Chat")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.startNewChat()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .help("Start a new chat (⌘N)")
            }
        }
    }
}

struct ChatDetailView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showRename = false
    @State private var renameDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            AvailabilityBanner()

            if store.settings.showContextMeter {
                ContextMeterBar()
            }

            if let warning = store.contextWarning {
                ContextWarningBanner(text: warning)
            }

            if let conversation = store.selectedConversation {
                if conversation.messages.isEmpty {
                    EmptyChatHero()
                } else {
                    MessageListView(messages: conversation.messages)
                }

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }

                ComposerView()
            } else {
                ContentUnavailableView("No Chat Selected", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .navigationTitle(store.selectedConversation?.title ?? "Foundation Chat")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.showInstructions = true
                } label: {
                    Label("Instructions", systemImage: "text.alignleft")
                }
                .help("Edit system instructions for this chat")

                Button {
                    store.showChatOptions = true
                } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                }
                .help("Generation options, use case, and guardrails")

                Button {
                    store.openHelp()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .help("Feature guide and tips")

                Menu {
                    Button("Rename Chat…") {
                        renameDraft = store.selectedConversation?.title ?? ""
                        showRename = true
                    }
                    Button("Clear Messages", role: .destructive) {
                        store.clearSelectedChatMessages()
                    }
                    Divider()
                    Button("Copy Transcript") { store.copySelectedTranscript() }
                    Button("Export Transcript…") { store.exportSelectedTranscript() }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }

            if store.isGenerating {
                ToolbarItem(placement: .automatic) {
                    Button("Stop", role: .destructive) {
                        store.stopGenerating()
                    }
                }
            }
        }
        .sheet(isPresented: $store.showInstructions) {
            InstructionsSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showRename) {
            RenameChatSheet(title: $renameDraft) { newTitle in
                store.renameSelectedChat(newTitle)
            }
        }
    }
}

struct EmptyChatHero: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 40)
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                Text("Foundation Chat")
                    .font(.largeTitle.weight(.semibold))
                Text("Talk to Apple’s on-device Foundation Model. Private, offline, no API key.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(PromptSuggestion.all) { suggestion in
                        Button {
                            store.applySuggestion(suggestion)
                        } label: {
                            Text(suggestion.title)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: 520)

                HStack(spacing: 12) {
                    Button("Open Help") { store.openHelp() }
                    Button("Chat Options") { store.showChatOptions = true }
                }
                .buttonStyle(.borderless)

                Spacer(minLength: 40)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}

struct MessageListView: View {
    @EnvironmentObject private var store: ChatStore
    let messages: [ChatMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .contextMenu {
                                if !message.text.isEmpty {
                                    Button("Copy") { store.copyMessage(message) }
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .onChange(of: messages.last?.text) { _, _ in
                if let lastID = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    @EnvironmentObject private var store: ChatStore
    let message: ChatMessage
    @State private var previewPayload: CodePreviewPayload?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 80) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(isUser ? "You" : "Foundation Model")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !message.text.isEmpty {
                        Button {
                            store.copyMessage(message)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .help("Copy message")
                    }
                }

                Group {
                    if message.text.isEmpty && message.isStreaming {
                        Text("Thinking…")
                            .font(.body)
                    } else if isUser {
                        Text(message.text)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        MessageBodyView(
                            text: message.text,
                            isStreaming: message.isStreaming,
                            onPreview: { previewPayload = $0 }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isUser ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: 640, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 80) }
        }
        .sheet(item: $previewPayload) { payload in
            CodePreviewSheet(payload: payload)
        }
    }
}

struct ComposerView: View {
    @EnvironmentObject private var store: ChatStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PromptSuggestion.all) { suggestion in
                        Button(suggestion.title) {
                            store.applySuggestion(suggestion)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask anything…", text: $store.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .focused($focused)
                    .onSubmit { store.sendDraft() }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                Button {
                    store.sendDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
                .disabled(!store.canSend)
                .help("Send message")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .padding(.top, 2)

            if store.contextUsage.draftTokens > 0 {
                Text("Draft ≈ \(store.contextUsage.draftTokens) token\(store.contextUsage.draftTokens == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .background(.bar)
        .onAppear { focused = true }
    }
}

struct AvailabilityBanner: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        if !store.availability.isReady {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.availability.title)
                        .font(.headline)
                    Text(store.availability.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Why can’t I chat?") {
                        store.openHelp(topic: .overview)
                    }
                    .buttonStyle(.link)
                }

                Spacer()

                Button("Check Again") {
                    store.refreshAvailability()
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
            .background(Color.orange.opacity(0.12))
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private var iconName: String {
        switch store.availability {
        case .appleIntelligenceNotEnabled: "switch.2"
        case .modelNotReady: "arrow.down.circle"
        case .deviceNotEligible: "laptopcomputer.trianglebadge.exclamationmark"
        default: "exclamationmark.triangle"
        }
    }
}

struct ContextMeterBar: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Context", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(store.contextUsage.statusLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if store.contextUsage.draftTokens > 0 {
                    Text("+\(store.contextUsage.draftTokens) draft")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Button {
                    store.openHelp(topic: .context)
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("What is the context window?")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(meterColor.opacity(0.35))
                        .frame(width: max(4, geo.size.width * store.contextUsage.projectedRatio))
                    Capsule()
                        .fill(meterColor)
                        .frame(width: max(4, geo.size.width * store.contextUsage.fillRatio))
                }
            }
            .frame(height: 6)

            Text("\(store.contextUsage.remainingTokens) tokens remaining · window \(store.contextUsage.contextSize)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var meterColor: Color {
        if store.contextUsage.isOverLimit { return .red }
        if store.contextUsage.isNearLimit { return .orange }
        return .accentColor
    }
}

struct ContextWarningBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(text)
                .font(.callout)
            Spacer()
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}

#Preview {
    ContentView()
        .environmentObject(ChatStore())
}
