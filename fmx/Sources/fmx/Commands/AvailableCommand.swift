import ArgumentParser
import Foundation
import FoundationModels

struct AvailableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "available",
        abstract: "Check model availability."
    )

    @Option(name: .shortAndLong, help: "Model to check (system).")
    var model: String = "system"

    @Flag(name: .shortAndLong, help: "Print only exit status (0 = available).")
    var quiet: Bool = false

    func run() async throws {
        guard model == "system" else {
            Terminal.writeError("Unknown model '\(model)'. Only 'system' is supported.")
            throw ExitCode(2)
        }

        let system = SystemLanguageModel.default
        let available = system.isAvailable

        if quiet {
            if !available {
                throw ExitCode(1)
            }
            return
        }

        Terminal.writeln(ModelFactory.availabilityDescription(system))
        if !available {
            throw ExitCode(1)
        }
    }
}
