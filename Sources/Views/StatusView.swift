import SwiftUI

struct StatusView: View {
    let service: MoService
    let isActive: Bool
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var status: SystemStatus?
    @State private var error: String?
    @State private var history = StatusHistory()
    @State private var stableProcessIDs: [Int] = []
    @State private var requestInFlight = false
    @State private var appear = false

    private var pollingEnabled: Bool {
        isActive && scenePhase == .active
    }

    var body: some View {
        VStack(spacing: 0) {
            if let status {
                headerBar(status)
                Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        primaryMetrics(status)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)

                        ioMetrics(status)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 6)

                        processesSection(status)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 4)
                    }
                    .padding(24)
                }
            } else if isLoading || requestInFlight {
                loadingView
            } else if let error {
                ErrorStateView(message: error) { Task { await refresh() } }
            } else {
                loadingView
            }
        }
        .background(DesignTokens.Color.pageBackground)
        .task(id: pollingEnabled) { await pollingLoop(active: pollingEnabled) }
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue, pollingEnabled else { return }
            Task { await refresh() }
        }
    }

    private func pollingLoop(active: Bool) async {
        guard active else {
            if status == nil && !requestInFlight { isLoading = false }
            return
        }

        while !Task.isCancelled {
            let startedAt = Date()
            await refresh()
            guard !Task.isCancelled else { break }

            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = max(0, 3 - elapsed)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
    }

    private func headerBar(_ status: SystemStatus) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("System Status")
                        .font(DesignTokens.Font.page)
                        .foregroundStyle(DesignTokens.Color.primary)
                    liveBadge
                    proxyBadge(status.proxy)
                }

                Text("\(status.hardware.cpuModel) · \(status.hardware.totalRam) · \(status.hardware.osVersion) · up \(status.uptime)")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .lineLimit(1)
            }

            Spacer()
            healthBadge(score: status.healthScore)
            if let collectedAt = StatusTimestamp.displayTime(from: status.collectedAt) {
                Text("Updated \(collectedAt)")
                    .font(DesignTokens.Font.label)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Refresh", disabled: requestInFlight) {
                Task { await refresh() }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(pollingEnabled ? DesignTokens.Color.successText : DesignTokens.Color.tertiary)
                .frame(width: 6, height: 6)
            Text(pollingEnabled ? "live" : "paused")
                .font(DesignTokens.Font.label)
                .foregroundStyle(pollingEnabled ? DesignTokens.Color.successText : DesignTokens.Color.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(pollingEnabled ? DesignTokens.Color.successSoft : DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }

    @ViewBuilder
    private func proxyBadge(_ proxy: ProxyInfo?) -> some View {
        if let proxy {
            HStack(spacing: 5) {
                Image(systemName: proxy.enabled ? "network" : "network.slash")
                    .font(.system(size: 10, weight: .semibold))
                Text(proxy.enabled ? (proxy.type ?? "proxy") : "direct")
                    .font(DesignTokens.Font.label)
            }
            .foregroundStyle(proxy.enabled ? DesignTokens.Color.accentTint : DesignTokens.Color.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(proxy.enabled ? DesignTokens.Color.accentSoft : DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
        }
    }

    private func healthBadge(score: Int) -> some View {
        let color = DesignTokens.healthColor(score: score)
        let bg = DesignTokens.healthBgColor(score: score)
        return HStack(spacing: 6) {
            Image(systemName: DesignTokens.healthIcon(score: score))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text("\(score)")
                .font(DesignTokens.Font.monoLarge)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }

    private func primaryMetrics(_ s: SystemStatus) -> some View {
        HStack(alignment: .top, spacing: 18) {
            metricCard { cpuSection(s.cpu) }
            metricCard { memorySection(s.memory) }
            metricCard { diskSection(s.disks) }
        }
    }

    private func cpuSection(_ cpu: CPUInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("CPU", value: "\(cpu.usage.pctString)%", subtitle: "\(cpu.pCoreCount)P + \(cpu.eCoreCount)E cores")
            ProgressBar(value: cpu.usage / 100, color: DesignTokens.Color.accent)
            LiveSparkline(
                samples: history.samples,
                title: "CPU usage",
                color: DesignTokens.Color.accent,
                yDomain: 0...100,
                value: { $0.cpuUsage }
            )
            PerCoreStrip(perCore: cpu.perCore, pCoreCount: cpu.pCoreCount, eCoreCount: cpu.eCoreCount)
            HStack(spacing: 6) {
                loadBadge(label: "1m", value: cpu.load1)
                loadBadge(label: "5m", value: cpu.load5)
                loadBadge(label: "15m", value: cpu.load15)
            }
        }
    }

    private func memorySection(_ mem: MemoryInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Memory", value: "\(mem.usedPercent.pctString)%", subtitle: mem.used.humanReadable)
            ProgressBar(value: mem.usedPercent / 100, color: DesignTokens.Color.accentSecondary)
            MemoryBreakdownBar(memory: mem)
            HStack {
                statLine("Total", mem.total.humanReadable)
                Spacer()
                statLine("Free", mem.free.humanReadable)
            }
        }
    }

    private func diskSection(_ disks: [DiskInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Disk")
            ForEach(disks.prefix(3)) { disk in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(disk.mount)
                            .font(DesignTokens.Font.caption)
                            .foregroundStyle(DesignTokens.Color.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(disk.usedPercent.pctString)%")
                            .font(DesignTokens.Font.mono)
                            .foregroundStyle(DesignTokens.Color.secondary)
                    }
                    MiniBar(value: disk.usedPercent / 100, color: DesignTokens.Color.accent)
                    HStack {
                        statLine("Used", disk.used.humanReadable)
                        Spacer()
                        statLine("Free", disk.free.humanReadable)
                    }
                }
            }
        }
    }

    private func ioMetrics(_ s: SystemStatus) -> some View {
        HStack(alignment: .top, spacing: 18) {
            metricCard { diskIOSection(s.diskIO) }
            metricCard { networkSection(s.primaryNetworkInterface) }
            metricCard { secondaryStatusSection(s) }
        }
    }

    private func diskIOSection(_ diskIO: DiskIO?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Disk I/O")
            HStack(spacing: 14) {
                rateSparkline(
                    label: "Read",
                    value: diskIO?.readRate ?? 0,
                    symbol: "↓",
                    color: DesignTokens.Color.successText,
                    domain: 0...history.maxValue(\.diskReadRate),
                    sampleValue: { $0.diskReadRate }
                )
                rateSparkline(
                    label: "Write",
                    value: diskIO?.writeRate ?? 0,
                    symbol: "↑",
                    color: DesignTokens.Color.accentTint,
                    domain: 0...history.maxValue(\.diskWriteRate),
                    sampleValue: { $0.diskWriteRate }
                )
            }
        }
    }

    private func networkSection(_ iface: NetworkInterface?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Network", subtitle: iface?.name ?? "No interface")
            HStack(spacing: 14) {
                rateSparkline(
                    label: "Down",
                    value: iface?.rxRate ?? 0,
                    symbol: "↓",
                    color: DesignTokens.Color.successText,
                    domain: 0...history.maxValue(\.networkRxRate),
                    sampleValue: { $0.networkRxRate }
                )
                rateSparkline(
                    label: "Up",
                    value: iface?.txRate ?? 0,
                    symbol: "↑",
                    color: DesignTokens.Color.accentTint,
                    domain: 0...history.maxValue(\.networkTxRate),
                    sampleValue: { $0.networkTxRate }
                )
            }
            if let ip = iface?.ip {
                statLine("IP", ip)
            }
        }
    }

    private func secondaryStatusSection(_ s: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("System", subtitle: s.procs.map { "\($0) processes" })
            if let battery = s.batteries?.first {
                HStack(spacing: 12) {
                    statLine("Battery", "\(battery.percent)%")
                    if let health = battery.health { statLine("Health", health) }
                    if let cycles = battery.cycleCount { statLine("Cycles", "\(cycles)") }
                }
            } else {
                statLine("Battery", "No battery data")
            }

            if let thermal = s.thermal {
                HStack(spacing: 12) {
                    if let cpuTemp = thermal.cpuTemp, cpuTemp > 0 { statLine("CPU", String(format: "%.1f°C", cpuTemp)) }
                    if let gpuTemp = thermal.gpuTemp, gpuTemp > 0 { statLine("GPU", String(format: "%.1f°C", gpuTemp)) }
                    if let fan = thermal.fanSpeed, fan > 0 { statLine("Fan", "\(fan) RPM") }
                }
            }
        }
    }

    private func rateSparkline(
        label: String,
        value: Double,
        symbol: String,
        color: SwiftUI.Color,
        domain: ClosedRange<Double>,
        sampleValue: @escaping (StatusSample) -> Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(symbol)
                    .font(DesignTokens.Font.monoBold)
                    .foregroundStyle(color)
                Text(formatRate(value))
                    .font(DesignTokens.Font.monoBold)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .monospacedDigit()
            }
            Text(label)
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.tertiary)
            LiveSparkline(samples: history.samples, title: label, color: color, yDomain: domain, value: sampleValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func processesSection(_ s: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Top Processes", subtitle: "stable order · live CPU")
                Spacer()
            }
            .padding(.bottom, 12)

            if !orderedProcesses(for: s).isEmpty {
                HStack {
                    Text("Process")
                        .font(DesignTokens.Font.label)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU")
                        .font(DesignTokens.Font.label)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(width: 80, alignment: .trailing)
                    Text("MEM")
                        .font(DesignTokens.Font.label)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(orderedProcesses(for: s).prefix(8).enumerated()), id: \.element.id) { i, proc in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(proc.name)
                                    .font(DesignTokens.Font.body)
                                    .foregroundStyle(DesignTokens.Color.primary)
                                    .lineLimit(1)
                                if let command = proc.command, !command.isEmpty {
                                    Text(command)
                                        .font(DesignTokens.Font.caption)
                                        .foregroundStyle(DesignTokens.Color.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(proc.cpu.pctString)%")
                                .font(DesignTokens.Font.mono)
                                .foregroundStyle(DesignTokens.Color.secondary)
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)
                            Text("\(proc.memory.pctString)%")
                                .font(DesignTokens.Font.mono)
                                .foregroundStyle(DesignTokens.Color.secondary)
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(i % 2 == 0 ? DesignTokens.Color.cardBackground : DesignTokens.Color.pageBackground)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).stroke(DesignTokens.Color.separatorLight, lineWidth: 1))
            }
        }
        .padding(18)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private func metricCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
            .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private func loadBadge(label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label).font(DesignTokens.Font.label).foregroundStyle(DesignTokens.Color.tertiary)
            Text(String(format: "%.2f", value)).font(DesignTokens.Font.mono).foregroundStyle(DesignTokens.Color.secondary)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(DesignTokens.Color.pageBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }

    private func sectionHeader(_ title: String, value: String? = nil, subtitle: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(DesignTokens.Font.labelUppercase)
                .foregroundStyle(DesignTokens.Color.secondary)
            if let value {
                Text(value)
                    .font(DesignTokens.Font.displayNumber)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .monospacedDigit()
            }
            if let subtitle {
                Text(subtitle)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.tertiary)
            Text(value).font(DesignTokens.Font.mono).foregroundStyle(DesignTokens.Color.secondary).lineLimit(1)
        }
    }

    private func formatRate(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f MB/s", value)
        }
        if value >= 10 {
            return String(format: "%.1f MB/s", value)
        }
        return String(format: "%.2f MB/s", value)
    }

    private func orderedProcesses(for status: SystemStatus) -> [ProcessInfo] {
        let current = status.topProcesses ?? []
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let ordered = stableProcessIDs.compactMap { byID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        let additions = current.filter { !orderedIDs.contains($0.id) }
        return ordered + additions
    }

    private func updateStableProcessOrder(with processes: [ProcessInfo]?) {
        let current = Array((processes ?? []).prefix(12))
        let currentIDs = Set(current.map(\.id))
        stableProcessIDs = stableProcessIDs.filter { currentIDs.contains($0) }
        let existingIDs = Set(stableProcessIDs)
        stableProcessIDs.append(contentsOf: current.map(\.id).filter { !existingIDs.contains($0) })
        if stableProcessIDs.count > 8 {
            stableProcessIDs = Array(stableProcessIDs.prefix(8))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Reading system data...").font(DesignTokens.Font.body).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        guard !requestInFlight else { return }
        requestInFlight = true
        isLoading = true
        error = nil
        defer {
            requestInFlight = false
            isLoading = false
        }

        do {
            let nextStatus = try await service.getStatus()
            guard !Task.isCancelled else { return }
            withAnimation(DesignTokens.spring) {
                status = nextStatus
                history.append(nextStatus)
                updateStableProcessOrder(with: nextStatus.topProcesses)
                appear = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

struct ProgressBar: View {
    let value: Double
    let color: SwiftUI.Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.Color.pageBackground).frame(height: 6)
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1), height: 6)
            }
        }.frame(height: 6)
    }
}

struct MiniBar: View {
    let value: Double
    let color: SwiftUI.Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.Color.pageBackground).frame(height: 4)
                Capsule().fill(color.opacity(0.6)).frame(width: geo.size.width * min(max(value, 0), 1), height: 4)
            }
        }.frame(height: 4)
    }
}
