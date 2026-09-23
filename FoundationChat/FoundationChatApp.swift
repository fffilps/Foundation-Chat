import SwiftUI

@main
struct FoundationChatApp: App {
    @StateObject private var chatStore = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatStore)
                .frame(minWidth: 780, minHeight: 520)
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    chatStore.startNewChat()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Chat Options…") {
                    chatStore.showChatOptions = true
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])

                Button("Instructions…") {
                    chatStore.showInstructions = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandMenu("Chat") {
                Button("Copy Transcript") {
                    chatStore.copySelectedTranscript()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Export Transcript…") {
                    chatStore.exportSelectedTranscript()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Clear Messages") {
                    chatStore.clearSelectedChatMessages()
                }
            }

            CommandGroup(replacing: .help) {
                Button("Foundation Chat Help") {
                    chatStore.openHelp(topic: .overview)
                }
                .keyboardShortcut("?", modifiers: .command)

                Button("Context Window Help") {
                    chatStore.openHelp(topic: .context)
                }

                Button("CLI Cheat Sheet") {
                    chatStore.openHelp(topic: .cli)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(chatStore)
                .frame(width: 480, height: 420)
        }
    }
}
