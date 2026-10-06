import Foundation

struct MachineProfile: Equatable, Sendable {
    var machineModel: String
    var chipDescription: String
    var memoryBytes: UInt64
    var freeDiskBytes: UInt64
    var modelsDirectoryPath: String
    var appleIntelligenceAvailable: Bool

    var memoryGB: Double {
        Double(memoryBytes) / 1_073_741_824.0
    }

    var freeDiskGB: Double {
        Double(freeDiskBytes) / 1_073_741_824.0
    }

    var memoryLabel: String {
        String(format: "%.0f GB RAM", memoryGB.rounded())
    }

    var freeDiskLabel: String {
        String(format: "%.1f GB free", freeDiskGB)
    }
}

enum HardwareProfiler {
    static func modelsDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent("FoundationChat/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func profile(appleIntelligenceAvailable: Bool) -> MachineProfile {
        let modelsDir = modelsDirectory()
        return MachineProfile(
            machineModel: sysctlString("hw.model") ?? "Unknown Mac",
            chipDescription: chipDescription(),
            memoryBytes: sysctlUInt64("hw.memsize") ?? 0,
            freeDiskBytes: freeDiskBytes(at: modelsDir) ?? 0,
            modelsDirectoryPath: modelsDir.path,
            appleIntelligenceAvailable: appleIntelligenceAvailable
        )
    }

    private static func chipDescription() -> String {
        if let brand = sysctlString("machdep.cpu.brand_string"), !brand.isEmpty {
            return brand
        }
        // Apple Silicon often omits brand_string; hw.model still identifies the machine.
        if let model = sysctlString("hw.model") {
            return "Apple Silicon (\(model))"
        }
        return "Unknown chip"
    }

    private static func freeDiskBytes(at url: URL) -> UInt64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let capacity = values?.volumeAvailableCapacityForImportantUsage, capacity > 0 {
            return UInt64(capacity)
        }
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: url.path)
        if let free = attrs?[.systemFreeSize] as? NSNumber {
            return free.uint64Value
        }
        return nil
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
