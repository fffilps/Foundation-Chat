import ArgumentParser
import Foundation

@main
struct FMX: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fmx",
        abstract: "fm-style CLI for Apple’s on-device Foundation Models on macOS 26+.",
        discussion: """
        Apple ships the system `fm` CLI with macOS 27. `fmx` brings the same core \
        workflow to macOS 26 (Tahoe) and later using the FoundationModels framework.

        On macOS 27 you can keep using `/usr/bin/fm`; use `fmx` when you need a \
        portable CLI that also works on macOS 26 for earlier machines and teammates.
        """,
        version: "1.0.0",
        subcommands: [
            AvailableCommand.self,
            RespondCommand.self,
            ChatCommand.self,
            CountTokensCommand.self,
            SchemaCommand.self
        ],
        defaultSubcommand: nil
    )
}
