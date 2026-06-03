import Foundation

// MARK: - System Status Models (matching actual `mo status --json` output)

struct SystemStatus: Codable {
    let host: String
    let healthScore: Int
    let hardware: HardwareInfo
    let cpu: CPUInfo
    let memory: MemoryInfo
    let disks: [DiskInfo]
    let uptime: String
    let batteries: [BatteryInfo]?
    let network: [NetworkInterface]?
    let topProcesses: [ProcessInfo]?
    let thermal: ThermalInfo?
    let proxy: ProxyInfo?
    let diskIO: DiskIO?
    let collectedAt: String?
    let procs: Int?

    enum CodingKeys: String, CodingKey {
        case host
        case healthScore = "health_score"
        case hardware, cpu, memory, disks, uptime
        case batteries
        case network
        case topProcesses = "top_processes"
        case thermal
        case proxy
        case diskIO = "disk_io"
        case collectedAt = "collected_at"
        case procs
    }
}

struct HardwareInfo: Codable {
    let model: String
    let cpuModel: String
    let totalRam: String
    let diskSize: String
    let osVersion: String

    enum CodingKeys: String, CodingKey {
        case model
        case cpuModel = "cpu_model"
        case totalRam = "total_ram"
        case diskSize = "disk_size"
        case osVersion = "os_version"
    }

    var displayLabel: String {
        "\(model) \u{00B7} \(cpuModel) \u{00B7} \(totalRam) \u{00B7} \(osVersion)"
    }
}

struct CPUInfo: Codable {
    let usage: Double
    let perCore: [Double]
    let load1: Double
    let load5: Double
    let load15: Double
    let logicalCpu: Int
    let pCoreCount: Int
    let eCoreCount: Int

    enum CodingKeys: String, CodingKey {
        case usage
        case perCore = "per_core"
        case load1, load5, load15
        case logicalCpu = "logical_cpu"
        case pCoreCount = "p_core_count"
        case eCoreCount = "e_core_count"
    }

    var loads: [Double] { [load1, load5, load15] }
}

struct MemoryInfo: Codable {
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let swapUsed: UInt64?
    let swapTotal: UInt64?
    let cached: UInt64?

    enum CodingKeys: String, CodingKey {
        case used, total
        case usedPercent = "used_percent"
        case swapUsed = "swap_used"
        case swapTotal = "swap_total"
        case cached
    }

    var free: UInt64 {
        total > used ? total - used : 0
    }
}

struct DiskInfo: Codable, Identifiable {
    var id: String { mount }
    let mount: String
    let device: String?
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let fsType: String?
    let external: Bool?

    enum CodingKeys: String, CodingKey {
        case mount, device, used, total
        case usedPercent = "used_percent"
        case fsType = "fstype"
        case external
    }

    var free: UInt64 {
        total > used ? total - used : 0
    }
}

struct BatteryInfo: Codable {
    let percent: Int
    let status: String?
    let timeLeft: String?
    let health: String?
    let cycleCount: Int?
    let capacity: Int?

    enum CodingKeys: String, CodingKey {
        case percent, status
        case timeLeft = "time_left"
        case health
        case cycleCount = "cycle_count"
        case capacity
    }
}

struct NetworkInterface: Codable {
    let name: String
    let rxRate: Double?
    let txRate: Double?
    let ip: String?

    enum CodingKeys: String, CodingKey {
        case name
        case rxRate = "rx_rate_mbs"
        case txRate = "tx_rate_mbs"
        case ip
    }
}

struct ProcessInfo: Codable, Identifiable {
    var id: Int { pid }
    let pid: Int
    let name: String
    let command: String?
    let cpu: Double
    let memory: Double
}

struct ThermalInfo: Codable {
    let cpuTemp: Double?
    let gpuTemp: Double?
    let batteryTemp: Double?
    let fanSpeed: Int?
    let fanCount: Int?

    enum CodingKeys: String, CodingKey {
        case cpuTemp = "cpu_temp"
        case gpuTemp = "gpu_temp"
        case batteryTemp = "battery_temp"
        case fanSpeed = "fan_speed"
        case fanCount = "fan_count"
    }
}

struct ProxyInfo: Codable {
    let enabled: Bool
    let type: String?
    let host: String?
}

struct DiskIO: Codable {
    let readRate: Double
    let writeRate: Double

    enum CodingKeys: String, CodingKey {
        case readRate = "read_rate"
        case writeRate = "write_rate"
    }
}

// MARK: - Clean Result

// One discovered location inside a clean category — a real path Mole would
// remove, with its size and (when Mole reports it) an item count.
struct CleanItem: Codable, Identifiable {
    var id: String { path }
    let path: String
    let size: UInt64
    let itemCount: Int?
}

struct CleanCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let size: UInt64
    let selected: Bool?
    // The locations parsed under this section. Drives the drill-down tree.
    // Defaulted so older call sites and decoded JSON without items stay valid.
    var items: [CleanItem] = []
}

struct CleanResult: Codable {
    let categories: [CleanCategory]
    let totalFreed: UInt64
    let freeSpaceAfter: UInt64?

    enum CodingKeys: String, CodingKey {
        case categories, totalFreed = "total_freed"
        case freeSpaceAfter = "free_space_after"
    }
}

// MARK: - App Uninstall

struct AppInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let size: UInt64
    let bundleID: String?
    let status: String?
    let relatedFiles: Int?
    let uninstallName: String?
    // From `uninstall --list`: "App" or "Homebrew", and the on-disk bundle path.
    var source: String?
    var path: String?
    // Computed at list time (MoService.getUninstallList) from the bundle's owner
    // and parent-dir writability + Homebrew source — mirrors Mole's own
    // `needs_sudo` check. Root-owned/non-writable apps can be previewed and
    // uninstalled in an admin-only batch; Homebrew casks remain locked.
    var requiresAdmin: Bool = false
}

// Raw JSON format from `mo uninstall --list`
struct RawAppInfo: Codable {
    let name: String
    let size: String
    let bundleID: String?
    let source: String?
    let uninstallName: String?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case name, size
        case bundleID = "bundle_id"
        case source
        case uninstallName = "uninstall_name"
        case path
    }
}

struct UninstallResult: Codable {
    let apps: [AppInfo]
    let totalSize: UInt64?

    enum CodingKeys: String, CodingKey {
        case apps
        case totalSize = "total_size"
    }
}

// One app in a parsed `uninstall --dry-run` preview: the bundle plus the exact
// leftover paths Mole would remove, and the true total (bundle + leftovers,
// which is larger than the list size that counts only the bundle).
struct UninstallPreviewApp: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let size: UInt64
    let paths: [String]
}

// Result of parsing a `uninstall <names…> --dry-run` preview. Built by
// MoOutputParser.parseUninstallPreview; shown in the confirmation sheet.
struct UninstallPreview: Equatable {
    let apps: [UninstallPreviewApp]
    let totalSize: UInt64
    var isEmpty: Bool { apps.isEmpty }
}

// MARK: - Disk Analysis

struct DiskEntry: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let size: UInt64
    let isDir: Bool?   // `mo analyze` omits is_dir for large_files entries
    let modified: String?

    enum CodingKeys: String, CodingKey {
        case name, path, size, modified
        case isDir = "is_dir"
    }
}

struct AnalysisResult: Codable {
    let path: String
    let entries: [DiskEntry]
    let largeFiles: [DiskEntry]?
    let totalSize: UInt64
    let totalFiles: Int

    enum CodingKeys: String, CodingKey {
        case path, entries
        case largeFiles = "large_files"
        case totalSize = "total_size"
        case totalFiles = "total_files"
    }
}

// MARK: - Purge

struct PurgeProject: Codable, Identifiable {
    var id: String { name }
    let name: String
    let size: UInt64
    let type: String
    let isRecent: Bool?
    let selected: Bool?
}

struct PurgeResult: Codable {
    let projects: [PurgeProject]
    let totalSize: UInt64?

    enum CodingKeys: String, CodingKey {
        case projects
        case totalSize = "total_size"
    }
}

// MARK: - Helpers

extension UInt64 {
    var humanReadable: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
}

extension Double {
    var pctString: String {
        String(format: "%.1f", self)
    }
}

// MARK: - Installer

struct InstallerFile: Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let size: UInt64
    let location: String  // e.g. "Downloads"
}

struct InstallerResult: Equatable {
    let files: [InstallerFile]
    var totalSize: UInt64 { files.reduce(UInt64(0)) { $0 + $1.size } }
}

// MARK: - History

struct HistoryActions: Codable {
    let removed: Int
    let trashed: Int
    let skipped: Int
    let failed: Int
    let rebuilt: Int
    let other: Int

    var freedItemCount: Int { removed + trashed }
}

struct HistorySession: Codable, Identifiable {
    var id: String { startedAt }
    let command: String
    let startedAt: String
    let endedAt: String
    let items: Int
    let size: String  // human-readable like "7.75GB"
    let operationCount: Int
    let actions: HistoryActions

    enum CodingKeys: String, CodingKey {
        case command
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case items
        case size
        case operationCount = "operation_count"
        case actions
    }
}

struct HistoryLogs: Codable {
    let operations: String
    let deletions: String
}

struct HistoryResult: Codable {
    let logs: HistoryLogs
    let limit: Int
    let sessions: [HistorySession]

    // Total bytes actually freed across destructive sessions. Mole logs dry-run
    // previews as sessions with a size estimate but zero removed/trashed actions;
    // do not count those as recovered space.
    var totalFreedBytes: UInt64 {
        sessions.reduce(UInt64(0)) { total, session in
            guard session.actions.freedItemCount > 0 else { return total }
            return total + (MoOutputParser.parseHumanSize(session.size) ?? 0)
        }
    }
}
