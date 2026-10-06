import Foundation

enum FitVerdict: String, Codable, Sendable {
    case runnable
    case tight
    case needsRAM
    case needsDisk
    case comingSoon
    case unsupported

    var badgeTitle: String {
        switch self {
        case .runnable: "Runnable"
        case .tight: "Tight"
        case .needsRAM: "Needs RAM"
        case .needsDisk: "Needs space"
        case .comingSoon: "Coming soon"
        case .unsupported: "Unsupported"
        }
    }
}

struct FitResult: Equatable, Sendable {
    var verdict: FitVerdict
    var summary: String
    var detail: String

    var canAttemptChat: Bool {
        switch verdict {
        case .runnable, .tight:
            return true
        case .needsRAM, .needsDisk, .comingSoon, .unsupported:
            return false
        }
    }
}

private struct RequirementsFile: Codable, Sendable {
    var version: Int
    var defaults: RequirementsDefaults
    var models: [String: RequirementsRow]
}

private struct RequirementsDefaults: Codable, Sendable {
    var tightRAMHeadroomGB: Double
    var diskSafetyMarginBytes: UInt64
}

private struct RequirementsRow: Codable, Sendable {
    var minRAMGB: Double
    var recommendedRAMGB: Double
    var approximateInstallBytes: UInt64
    var requiresAppleIntelligence: Bool
    var isLive: Bool
}

enum ModelRequirementsSheet {
    private static let fallbackDefaults = RequirementsDefaults(
        tightRAMHeadroomGB: 2,
        diskSafetyMarginBytes: 1_073_741_824
    )

    private static let cached: RequirementsFile = {
        loadFromBundle() ?? RequirementsFile(version: 1, defaults: fallbackDefaults, models: [:])
    }()

    static func evaluate(
        model: LocalModelDescriptor,
        profile: MachineProfile
    ) -> FitResult {
        let row = cached.models[model.id].map {
            RequirementsRow(
                minRAMGB: $0.minRAMGB,
                recommendedRAMGB: $0.recommendedRAMGB,
                approximateInstallBytes: $0.approximateInstallBytes,
                requiresAppleIntelligence: $0.requiresAppleIntelligence,
                isLive: $0.isLive
            )
        } ?? RequirementsRow(
            minRAMGB: model.minRAMGB,
            recommendedRAMGB: model.recommendedRAMGB,
            approximateInstallBytes: model.approximateInstallBytes,
            requiresAppleIntelligence: model.requiresAppleIntelligence,
            isLive: model.isLive
        )

        let defaults = cached.defaults

        // IF not live → Coming soon (Phase 2 providers)
        if !row.isLive || !model.isLive {
            return FitResult(
                verdict: .comingSoon,
                summary: "Coming soon",
                detail: "\(model.provider.title) will plug into this catalog later. Requirements below are estimates for planning."
            )
        }

        // IF Apple Intelligence required AND unavailable → unsupported for chat right now
        if row.requiresAppleIntelligence && !profile.appleIntelligenceAvailable {
            return FitResult(
                verdict: .unsupported,
                summary: "Apple Intelligence unavailable",
                detail: "This Foundation Model needs Apple Intelligence enabled and the on-device model ready on this Mac."
            )
        }

        // IF RAM below minimum → needs RAM
        if profile.memoryGB + 0.05 < row.minRAMGB {
            let shortfall = row.minRAMGB - profile.memoryGB
            return FitResult(
                verdict: .needsRAM,
                summary: String(format: "Needs %.0f GB more RAM", shortfall.rounded(.up)),
                detail: String(
                    format: "Estimated minimum %.0f GB; this Mac reports %.0f GB.",
                    row.minRAMGB,
                    profile.memoryGB.rounded()
                )
            )
        }

        // IF disk short for install size → needs disk
        let neededDisk = row.approximateInstallBytes + defaults.diskSafetyMarginBytes
        if row.approximateInstallBytes > 0 && profile.freeDiskBytes < neededDisk {
            let needGB = Double(neededDisk) / 1_073_741_824.0
            let haveGB = profile.freeDiskGB
            return FitResult(
                verdict: .needsDisk,
                summary: String(format: "Needs ~%.1f GB free", needGB),
                detail: String(
                    format: "You have %.1f GB free on the models volume. Free more space before installing this model.",
                    haveGB
                )
            )
        }

        // IF RAM below recommended (but above min) → tight
        if profile.memoryGB + 0.05 < row.recommendedRAMGB {
            return FitResult(
                verdict: .tight,
                summary: "Runnable (tight RAM)",
                detail: String(
                    format: "Meets the %.0f GB minimum, but %.0f GB is recommended for smoother runs.",
                    row.minRAMGB,
                    row.recommendedRAMGB
                )
            )
        }

        // ELSE runnable
        return FitResult(
            verdict: .runnable,
            summary: "Runnable on this Mac",
            detail: model.notes
        )
    }

    private static func loadFromBundle() -> RequirementsFile? {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "ModelRequirements", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RequirementsFile.self, from: data)
        else {
            return nil
        }
        return decoded
    }
}
