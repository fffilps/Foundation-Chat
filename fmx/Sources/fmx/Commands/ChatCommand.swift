import ArgumentParser
import Foundation
import FoundationModels

struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Start an interactive chat session."
    )

    @Option(name: .shortAndLong, help: "Instructions for the model.")
    var instructions: String?

    @Option(name: .shortAndLong, help: "Model to use (system).")
    var model: String = "system"

    @Option(help: "Model use case (general, content-tagging).")
    var useCase: String = "general"

    @Option(help: "Guardrail level (default, permissive-content-transformations).")
    var guardrails: String = "default"

    @Flag(name: .shortAndLong, help: "Use greedy sampling.")
    var greedy: Bool = false

    func run() async throws {
        guard model == "system" else {
            Terminal.writeError("Unknown model '\(model)'. Only 'system' is supported.")
            throw ExitCode(2)
        }

        let systemModel = try ModelFactory.make(useCaseRaw: useCase, guardrailsRaw: guardrails)
        try ModelFactory.requireAvailable(systemModel)

        var currentInstructions = instructions
        var session = LanguageModelSession(
            model: systemModel,
            instructions: currentInstructions
        )
        let options = ModelFactory.generationOptions(greedy: greedy, temperature: nil, maxTokens: nil)

        Terminal.writeln("fmx chat — Apple on-device Foundation Model (macOS 26+)")
        Terminal.writeln("Type a message, /help for commands, /exit to quit.")
        Terminal.writeln()

        while true {
            Terminal.write("> ")
            fflush(stdout)
            guard let line = readLine(strippingNewline: true) else {
                Terminal.writeln()
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("/") {
                let handled = try handleSlash(
                    trimmed,
                    systemModel: systemModel,
                    currentInstructions: &currentInstructions,
                    session: &session
                )
                if handled == .exit { break }
                continue
            }

            do {
                var printed = ""
                let stream = session.streamResponse(to: trimmed, options: options)
                for try await snapshot in stream {
                    let text = snapshot.content
                    if text.hasPrefix(printed) {
                        Terminal.write(String(text.dropFirst(printed.count)))
                        fflush(stdout)
                        printed = text
                    } else {
                        Terminal.write(text)
                        fflush(stdout)
                        printed = text
                    }
                }
                if !printed.hasSuffix("\n") {
                    Terminal.writeln()
                }
                Terminal.writeln()
            } catch {
                Terminal.writeError("Error: \(error.localizedDescription)")
            }
        }
    }

    private enum SlashResult {
        case `continue`
        case exit
    }

    private func handleSlash(
        _ commandLine: String,
        systemModel: SystemLanguageModel,
        currentInstructions: inout String?,
        session: inout LanguageModelSession
    ) throws -> SlashResult {
        let parts = commandLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let command = String(parts.first ?? "").lowercased()
        let rest = parts.count > 1 ? String(parts[1]) : ""

        switch command {
        case "/help", "/?":
            Terminal.writeln("""
            /help              Show this help
            /clear             Reset conversation (keeps instructions)
            /system <text>     Replace instructions and reset conversation
            /model             Show model info
            /exit              Quit
            """)
            return .continue

        case "/clear":
            session = LanguageModelSession(model: systemModel, instructions: currentInstructions)
            Terminal.writeln("Conversation cleared.")
            return .continue

        case "/system":
            currentInstructions = rest.isEmpty ? nil : rest
            session = LanguageModelSession(model: systemModel, instructions: currentInstructions)
            Terminal.writeln(rest.isEmpty ? "Instructions cleared." : "Instructions updated.")
            return .continue

        case "/model":
            Terminal.writeln(ModelFactory.availabilityDescription(systemModel))
            Terminal.writeln("useCase=\(useCase) guardrails=\(guardrails) greedy=\(greedy)")
            return .continue

        case "/exit", "/quit":
            return .exit

        default:
            Terminal.writeError("Unknown command \(command). Try /help.")
            return .continue
        }
    }
}
