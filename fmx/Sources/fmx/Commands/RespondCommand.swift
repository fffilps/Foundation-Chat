import ArgumentParser
import Foundation
import FoundationModels

struct RespondCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "respond",
        abstract: "Generate a response to a prompt."
    )

    @Argument(help: "Prompt for the model to respond to.")
    var prompt: String?

    @Option(name: .shortAndLong, help: "Instructions for the model to follow.")
    var instructions: String?

    @Option(name: .shortAndLong, help: "Model to use (system).")
    var model: String = "system"

    @Option(help: "Model use case (general, content-tagging).")
    var useCase: String = "general"

    @Option(help: "Guardrail level (default, permissive-content-transformations).")
    var guardrails: String = "default"

    @Option(help: "Path to a JSON schema file produced by `fmx schema object`.")
    var schema: String?

    @Flag(name: .customLong("stream"), inversion: .prefixedNo, help: "Stream output as it’s generated (default: on).")
    var stream: Bool = true

    @Flag(name: .shortAndLong, help: "Use greedy sampling.")
    var greedy: Bool = false

    @Option(help: "Sampling temperature (0–2).")
    var temperature: Double?

    @Option(help: "Maximum response tokens.")
    var maxTokens: Int?

    @Flag(name: .shortAndLong, help: "Print verbose diagnostics.")
    var verbose: Bool = false

    func run() async throws {
        guard model == "system" else {
            Terminal.writeError("Unknown model '\(model)'. Only 'system' is supported.")
            throw ExitCode(2)
        }

        let promptText = try PromptIO.readPrompt(argument: prompt)
        let systemModel = try ModelFactory.make(useCaseRaw: useCase, guardrailsRaw: guardrails)
        try ModelFactory.requireAvailable(systemModel)

        let session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
        let options = ModelFactory.generationOptions(
            greedy: greedy,
            temperature: temperature,
            maxTokens: maxTokens
        )

        if verbose {
            Terminal.writeError("contextSize=\(systemModel.contextSize) stream=\(stream) greedy=\(greedy)")
        }

        if let schemaPath = schema {
            try await respondWithSchema(
                session: session,
                prompt: promptText,
                schemaPath: schemaPath,
                options: options
            )
            return
        }

        if stream {
            var printed = ""
            let responseStream = session.streamResponse(to: promptText, options: options)
            for try await snapshot in responseStream {
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
        } else {
            let response = try await session.respond(to: promptText, options: options)
            Terminal.writeln(response.content)
        }
    }

    private func respondWithSchema(
        session: LanguageModelSession,
        prompt: String,
        schemaPath: String,
        options: GenerationOptions
    ) async throws {
        let url = URL(fileURLWithPath: schemaPath)
        let data = try Data(contentsOf: url)
        let definition = try JSONDecoder().decode(SchemaDefinition.self, from: data)
        let generationSchema = try definition.makeGenerationSchema()

        let response = try await session.respond(
            to: prompt,
            schema: generationSchema,
            options: options
        )
        Terminal.writeln(response.content.jsonString)
    }
}
