import ArgumentParser
import Foundation
import FoundationModels

struct CountTokensCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "count-tokens",
        abstract: "Count tokens in a prompt or instructions."
    )

    @Argument(help: "Prompt to count tokens for.")
    var prompt: String?

    @Option(name: .shortAndLong, help: "Instructions to include in the count.")
    var instructions: String?

    @Flag(name: .shortAndLong, help: "Print only the integer count.")
    var quiet: Bool = false

    func run() async throws {
        let model = SystemLanguageModel.default
        try ModelFactory.requireAvailable(model)

        var total = 0

        if let instructions, !instructions.isEmpty {
            if #available(macOS 26.4, *) {
                total += try await model.tokenCount(for: Instructions(instructions))
            } else {
                total += max(instructions.count / 4, 1)
            }
        }

        let promptText: String?
        do {
            promptText = try PromptIO.readPrompt(argument: prompt)
        } catch FMXError.missingPrompt {
            promptText = nil
        }

        if let promptText {
            if #available(macOS 26.4, *) {
                total += try await model.tokenCount(for: promptText)
            } else {
                total += max(promptText.count / 4, 1)
            }
        }

        if instructions == nil && promptText == nil {
            throw FMXError.missingPrompt
        }

        if quiet {
            Terminal.writeln("\(total)")
        } else {
            Terminal.writeln("Token count: \(total)")
        }
    }
}
