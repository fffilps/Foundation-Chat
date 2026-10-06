import Foundation
import FoundationModels

enum FMXError: Error, LocalizedError {
    case modelUnavailable(String)
    case missingPrompt
    case invalidUseCase(String)
    case invalidGuardrails(String)
    case schemaBuildFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            "System model unavailable: \(reason)"
        case .missingPrompt:
            "Provide a prompt argument, or pipe text on stdin."
        case .invalidUseCase(let value):
            "Unknown use case '\(value)'. Use general or content-tagging."
        case .invalidGuardrails(let value):
            "Unknown guardrails '\(value)'. Use default or permissive-content-transformations."
        case .schemaBuildFailed(let reason):
            "Could not build schema: \(reason)"
        }
    }
}

enum ModelFactory {
    static func make(
        useCaseRaw: String,
        guardrailsRaw: String
    ) throws -> SystemLanguageModel {
        let useCase: SystemLanguageModel.UseCase
        switch useCaseRaw.lowercased() {
        case "general":
            useCase = .general
        case "content-tagging", "contenttagging", "tagging":
            useCase = .contentTagging
        default:
            throw FMXError.invalidUseCase(useCaseRaw)
        }

        let guardrails: SystemLanguageModel.Guardrails
        switch guardrailsRaw.lowercased() {
        case "default":
            guardrails = .default
        case "permissive-content-transformations", "permissive", "permissive-content":
            guardrails = .permissiveContentTransformations
        default:
            throw FMXError.invalidGuardrails(guardrailsRaw)
        }

        return SystemLanguageModel(useCase: useCase, guardrails: guardrails)
    }

    static func requireAvailable(_ model: SystemLanguageModel) throws {
        switch model.availability {
        case .available:
            return
        case .unavailable(.deviceNotEligible):
            throw FMXError.modelUnavailable("deviceNotEligible")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw FMXError.modelUnavailable("appleIntelligenceNotEnabled")
        case .unavailable(.modelNotReady):
            throw FMXError.modelUnavailable("modelNotReady")
        case .unavailable(let reason):
            throw FMXError.modelUnavailable(String(describing: reason))
        @unknown default:
            throw FMXError.modelUnavailable("unknown")
        }
    }

    static func availabilityDescription(_ model: SystemLanguageModel = .default) -> String {
        switch model.availability {
        case .available:
            return "System model available (contextSize=\(model.contextSize))"
        case .unavailable(.deviceNotEligible):
            return "System model unavailable: deviceNotEligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "System model unavailable: appleIntelligenceNotEnabled"
        case .unavailable(.modelNotReady):
            return "System model unavailable: modelNotReady"
        case .unavailable(let reason):
            return "System model unavailable: \(reason)"
        @unknown default:
            return "System model unavailable: unknown"
        }
    }

    static func generationOptions(greedy: Bool, temperature: Double?, maxTokens: Int?) -> GenerationOptions {
        var options = GenerationOptions()
        if greedy {
            options.sampling = .greedy
        }
        if let temperature {
            options.temperature = temperature
        }
        if let maxTokens {
            options.maximumResponseTokens = maxTokens
        }
        return options
    }
}

enum PromptIO {
    static func readPrompt(argument: String?) throws -> String {
        if let argument {
            let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        if isatty(STDIN_FILENO) == 0 {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
        }

        throw FMXError.missingPrompt
    }
}

enum Terminal {
    static func write(_ text: String, to fileHandle: FileHandle = .standardOutput) {
        if let data = text.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    static func writeln(_ text: String = "", to fileHandle: FileHandle = .standardOutput) {
        write(text + "\n", to: fileHandle)
    }

    static func writeError(_ text: String) {
        writeln(text, to: .standardError)
    }
}
