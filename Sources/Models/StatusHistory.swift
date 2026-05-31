import Foundation

struct StatusSample: Identifiable, Equatable {
    let id: Date
    let time: Date
    let cpuUsage: Double
    let memoryUsedPercent: Double
    let diskReadRate: Double
    let diskWriteRate: Double
    let networkRxRate: Double
    let networkTxRate: Double

    init(status: SystemStatus) {
        let collected = StatusTimestamp.date(from: status.collectedAt) ?? Date()
        self.id = collected
        self.time = collected
        self.cpuUsage = status.cpu.usage
        self.memoryUsedPercent = status.memory.usedPercent
        self.diskReadRate = status.diskIO?.readRate ?? 0
        self.diskWriteRate = status.diskIO?.writeRate ?? 0
        self.networkRxRate = status.primaryNetworkInterface?.rxRate ?? 0
        self.networkTxRate = status.primaryNetworkInterface?.txRate ?? 0
    }
}

struct StatusHistory: Equatable {
    private(set) var samples: [StatusSample] = []
    let capacity: Int

    init(capacity: Int = 60) {
        self.capacity = max(1, capacity)
    }

    mutating func append(_ status: SystemStatus) {
        let sample = StatusSample(status: status)
        if samples.last?.time == sample.time {
            samples[samples.count - 1] = sample
        } else {
            samples.append(sample)
        }

        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    func maxValue(_ value: (StatusSample) -> Double, minimum: Double = 1) -> Double {
        max(samples.map(value).max() ?? minimum, minimum)
    }
}

enum StatusTimestamp {
    static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let isoWithFractionalSeconds = ISO8601DateFormatter()
        isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractionalSeconds.date(from: value) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }
        return nil
    }

    static func displayTime(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if let date = date(from: value) {
            return date.formatted(date: .omitted, time: .standard)
        }
        return value
    }
}

extension SystemStatus {
    var primaryNetworkInterface: NetworkInterface? {
        network?.first { $0.name == "en0" }
            ?? network?.first { ($0.rxRate ?? 0) > 0 || ($0.txRate ?? 0) > 0 }
            ?? network?.first
    }
}
