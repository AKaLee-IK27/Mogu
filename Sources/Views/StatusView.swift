import AppKit
import SwiftUI

struct StatusView: View {
    let service: MoService
    let isActive: Bool
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool

    @State private var appIsActive = NSApplication.shared.isActive
    @State private var status: SystemStatus?
    @State private var error: String?
    @State private var history = StatusHistory()
    @State private var stableProcessIDs: [Int] = []
    @State private var requestInFlight = false
    @State private var appear = false

    private var pollingEnabled: Bool {
        isActive && appIsActive
    }

    var body: some View {
        VStack(spacing: 0) {
            if let status {
                headerBar(status)
                Rectangle().fill(DesignTokens.Color.separator).frame(height: 1)

                ScrollView {
                    content(status)
                }
                .padding(viewPadding)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appIsActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            appIsActive = false
        }
        .onAppear {
            appIsActive = NSApplication.shared.isActive
            withAnimation(DesignTokens.spring) { appear = true }
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue, pollingEnabled else { return }
            Task { await refresh() }
        }
    }

    // MARK: - Polling

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

    // MARK: - Responsive content

    private var viewPadding: CGFloat {
        24
    }

    @ViewBuilder
    private func content(_ s: SystemStatus) -> some View {
        // ViewThatFits picks the first child that fits, enabling adaptive column counts
        VStack(alignment: .leading, spacing: 20) {
            heroSection(s)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)

            metricsGrid3(s)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 6)

            ioGrid3(s)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 4)

            processesSection(s)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 2)
        }
    }

    // Adaptive metric rows: each row is an HStack where both cards
    // are stretched to equal height via maxHeight: .infinity.
    // ViewThatFits picks the first layout that fits horizontally.
    @ViewBuilder
    private func metricsGrid3(_ s: SystemStatus) -> some View {
        ViewThatFits(in: .horizontal) {
            // 3 in a row
            metricsRow3(
                AnyView(metricCard { cpuSection(s.cpu) }),
                AnyView(metricCard { memorySection(s.memory) }),
                AnyView(metricCard { diskSection(s.disks) })
            )
            // 2+1 split
            VStack(spacing: 16) {
                metricsRow2(
                    AnyView(metricCard { cpuSection(s.cpu) }),
                    AnyView(metricCard { memorySection(s.memory) })
                )
                metricCard { diskSection(s.disks) }
            }
            // stacked
            VStack(spacing: 16) {
                metricCard { cpuSection(s.cpu) }
                metricCard { memorySection(s.memory) }
                metricCard { diskSection(s.disks) }
            }
        }
    }

    @ViewBuilder
    private func ioGrid3(_ s: SystemStatus) -> some View {
        ViewThatFits(in: .horizontal) {
            ioRow3(
                AnyView(metricCard { diskIOSection(s.diskIO) }),
                AnyView(metricCard { networkSection(s.primaryNetworkInterface) }),
                AnyView(metricCard { secondaryStatusSection(s) })
            )
            VStack(spacing: 16) {
                ioRow2(
                    AnyView(metricCard { diskIOSection(s.diskIO) }),
                    AnyView(metricCard { networkSection(s.primaryNetworkInterface) })
                )
                metricCard { secondaryStatusSection(s) }
            }
            VStack(spacing: 16) {
                metricCard { diskIOSection(s.diskIO) }
                metricCard { networkSection(s.primaryNetworkInterface) }
                metricCard { secondaryStatusSection(s) }
            }
        }
    }

    // HStack rows where all cards stretch to equal height
    private func metricsRow3(_ a: AnyView, _ b: AnyView, _ c: AnyView) -> some View {
        HStack(spacing: 16) {
            a.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            b.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            c.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func metricsRow2(_ a: AnyView, _ b: AnyView) -> some View {
        HStack(spacing: 16) {
            a.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            b.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func ioRow3(_ a: AnyView, _ b: AnyView, _ c: AnyView) -> some View {
        HStack(spacing: 16) {
            a.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            b.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            c.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func ioRow2(_ a: AnyView, _ b: AnyView) -> some View {
        HStack(spacing: 16) {
            a.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            b.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Header

    private func headerBar(_ status: SystemStatus) -> some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 10) {
                Text("Status")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                liveBadge
                proxyBadge(status.proxy)
            }

            Spacer()

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
        .padding(.vertical, 16)
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

    // MARK: - Hero Section: health score + hardware summary

    private func heroSection(_ s: SystemStatus) -> some View {
        ViewThatFits(in: .horizontal) {
            heroRow(s)
            VStack(spacing: 16) {
                heroRow(s)
            }
        }
    }

    private func heroRow(_ s: SystemStatus) -> some View {
        HStack(spacing: 20) {
            healthGauge(score: s.healthScore)
            VStack(alignment: .leading, spacing: 5) {
                Text(s.hardware.cpuModel)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)
                Text("\(s.hardware.totalRam) RAM · \(s.hardware.osVersion) · up \(s.uptime)")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private func healthGauge(score: Int) -> some View {
        let color = DesignTokens.healthColor(score: score)
        let bg = DesignTokens.healthBgColor(score: score)
        let ringProgress = Double(score) / 100.0

        return HStack(spacing: 14) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(DesignTokens.Color.pageBackground, lineWidth: 4)
                    .frame(width: 56, height: 56)
                // Progress ring (270-degree arc starting from top-left)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(DesignTokens.spring, value: score)
                // Score number
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Health Score")
                    .font(DesignTokens.Font.labelUppercase)
                    .foregroundStyle(DesignTokens.Color.secondary)
                Text(healthLabel(score: score))
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func healthLabel(score: Int) -> String {
        switch score {
        case 90...100: return "Excellent"
        case 80..<90: return "Good"
        case 70..<80: return "Fair"
        case 60..<70: return "Needs attention"
        default: return "Critical"
        }
    }

    private func cpuSection(_ cpu: CPUInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CPU", value: "\(cpu.usage.pctString)%", subtitle: "\(cpu.pCoreCount)P + \(cpu.eCoreCount)E cores")

            // Wider progress bar
            ProgressBar(value: cpu.usage / 100, color: cpuColor(cpu.usage), height: 8)

            // Sparkline: taller for readability
            LiveSparkline(
                samples: history.samples,
                title: "CPU usage",
                color: DesignTokens.Color.accent,
                yDomain: 0...100,
                value: { $0.cpuUsage }
            )
            .frame(height: 56)

            // Per-core strip, compact
            PerCoreStrip(perCore: cpu.perCore, pCoreCount: cpu.pCoreCount, eCoreCount: cpu.eCoreCount)

            // Load averages in a single compact row
            HStack(spacing: 8) {
                loadBadge(label: "1m", value: cpu.load1)
                loadBadge(label: "5m", value: cpu.load5)
                loadBadge(label: "15m", value: cpu.load15)
            }
        }
    }

    private func cpuColor(_ usage: Double) -> SwiftUI.Color {
        switch usage {
        case 0..<50: return DesignTokens.Color.accent
        case 50..<80: return DesignTokens.Color.warning
        default: return DesignTokens.Color.dangerText
        }
    }

    private func memorySection(_ mem: MemoryInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Memory", value: "\(mem.usedPercent.pctString)%", subtitle: mem.used.humanReadable)

            ProgressBar(value: mem.usedPercent / 100, color: DesignTokens.Color.accentSecondary, height: 8)

            MemoryBreakdownBar(memory: mem)

            // Compact total/free/swap line
            HStack {
                statLine("Total", mem.total.humanReadable)
                Spacer()
                statLine("Free", mem.free.humanReadable)
                if let swapUsed = mem.swapUsed, swapUsed > 0 {
                    Spacer()
                    statLine("Swap", swapUsed.humanReadable)
                }
            }
        }
    }

    private func diskSection(_ disks: [DiskInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Storage")
            ForEach(disks.prefix(3)) { disk in
                diskRow(disk)
            }
        }
    }

    private func diskRow(_ disk: DiskInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(disk.mount)
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(disk.used.humanReadable)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                Text("/")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.placeholder)
                Text(disk.total.humanReadable)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                Text("\(disk.usedPercent.pctString)%")
                    .font(DesignTokens.Font.monoBold)
                    .foregroundStyle(diskColor(disk.usedPercent))
                    .monospacedDigit()
            }
            MiniBar(value: disk.usedPercent / 100, color: diskColor(disk.usedPercent))
        }
    }

    private func diskColor(_ pct: Double) -> SwiftUI.Color {
        switch pct {
        case 0..<70: return DesignTokens.Color.accent
        case 70..<85: return DesignTokens.Color.warning
        default: return DesignTokens.Color.dangerText
        }
    }

    private func diskIOSection(_ diskIO: DiskIO?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Disk I/O")
            HStack(spacing: 16) {
                ioRateDisplay(
                    label: "Read",
                    value: diskIO?.readRate ?? 0,
                    symbol: "arrow.down",
                    color: DesignTokens.Color.successText,
                    domain: 0...history.maxValue(\.diskReadRate),
                    sampleValue: { $0.diskReadRate }
                )
                Divider().frame(height: 50)
                ioRateDisplay(
                    label: "Write",
                    value: diskIO?.writeRate ?? 0,
                    symbol: "arrow.up",
                    color: DesignTokens.Color.accentTint,
                    domain: 0...history.maxValue(\.diskWriteRate),
                    sampleValue: { $0.diskWriteRate }
                )
            }
        }
    }

    private func networkSection(_ iface: NetworkInterface?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Network", subtitle: iface?.name)
            HStack(spacing: 16) {
                ioRateDisplay(
                    label: "Down",
                    value: iface?.rxRate ?? 0,
                    symbol: "arrow.down",
                    color: DesignTokens.Color.successText,
                    domain: 0...history.maxValue(\.networkRxRate),
                    sampleValue: { $0.networkRxRate }
                )
                Divider().frame(height: 50)
                ioRateDisplay(
                    label: "Up",
                    value: iface?.txRate ?? 0,
                    symbol: "arrow.up",
                    color: DesignTokens.Color.accentTint,
                    domain: 0...history.maxValue(\.networkTxRate),
                    sampleValue: { $0.networkTxRate }
                )
            }
            if let ip = iface?.ip {
                statLine("IP", ip)
                    .padding(.top, 2)
            }
        }
    }

    private func ioRateDisplay(
        label: String,
        value: Double,
        symbol: String,
        color: SwiftUI.Color,
        domain: ClosedRange<Double>,
        sampleValue: @escaping (StatusSample) -> Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
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
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func secondaryStatusSection(_ s: SystemStatus) -> some View {
        let battery = s.batteries?.first
        let thermalReadings = s.thermal.map { self.thermalReadings($0) } ?? []

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("System")

            if let battery {
                batteryWidget(battery)
            }

            if !thermalReadings.isEmpty {
                thermalLine(thermalReadings)
            }

            if battery == nil && thermalReadings.isEmpty {
                statLine("Sensors", "No battery or thermal data")
            }
        }
    }

    private func batteryWidget(_ battery: BatteryInfo) -> some View {
        let color = batteryColor(battery.percent)
        let bg = batteryBgColor(battery.percent)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                // Large battery icon with percentage inside
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(color, lineWidth: 2)
                        .frame(width: 44, height: 22)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(3, CGFloat(battery.percent) / 100 * 36), height: 16)
                        .offset(x: 2)
                    // Terminal nub
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 3, height: 8)
                        .offset(x: 24)
                    // Percentage centered
                    Text("\(battery.percent)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery")
                        .font(DesignTokens.Font.labelUppercase)
                        .foregroundStyle(DesignTokens.Color.secondary)
                    Text(batteryDetailLine(battery))
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            // Stats row: time left, cycles, health
            batteryStatsRow(battery)
        }
        .padding(12)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func batteryBgColor(_ percent: Int) -> SwiftUI.Color {
        switch percent {
        case 0..<20: return DesignTokens.Color.dangerSoft
        case 20..<50: return DesignTokens.Color.warningSoft
        default: return DesignTokens.Color.successSoft
        }
    }

    private func batteryDetailLine(_ battery: BatteryInfo) -> String {
        if let timeLeft = battery.timeLeft, !timeLeft.isEmpty {
            return timeLeft
        }
        if let status = battery.status, !status.isEmpty {
            return status
        }
        return "Charged"
    }

    @ViewBuilder
    private func batteryStatsRow(_ battery: BatteryInfo) -> some View {
        let items = batteryStatItems(battery)
        if !items.isEmpty {
            HStack(spacing: 12) {
                ForEach(items.indices, id: \.self) { i in
                    statLine(items[i].label, items[i].value)
                }
            }
        }
    }

    private func batteryStatItems(_ battery: BatteryInfo) -> [(label: String, value: String)] {
        var items: [(String, String)] = []
        if let cycles = battery.cycleCount {
            items.append(("Cycles", "\(cycles)"))
        }
        if let health = battery.health, !health.isEmpty {
            items.append(("Health", health))
        }
        if let capacity = battery.capacity {
            items.append(("Capacity", "\(capacity) mAh"))
        }
        return items
    }

    private func batteryColor(_ percent: Int) -> SwiftUI.Color {
        switch percent {
        case 0..<20: return DesignTokens.Color.dangerText
        case 20..<50: return DesignTokens.Color.warningText
        default: return DesignTokens.Color.successText
        }
    }

    private func thermalLine(_ readings: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(readings.indices, id: \.self) { i in
                Text(readings[i])
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.secondary)
            }
        }
    }

    private func thermalReadings(_ t: ThermalInfo) -> [String] {
        var out: [String] = []
        if let v = t.cpuTemp, v > 0 { out.append("CPU \(String(format: "%.1f", v))°") }
        if let v = t.gpuTemp, v > 0 { out.append("GPU \(String(format: "%.1f", v))°") }
        if let v = t.fanSpeed, v > 0 { out.append("Fan \(v) RPM") }
        return out
    }

    // MARK: - Processes Section

    private func processesSection(_ s: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("Top Processes", subtitle: "stable order · live CPU")
                Spacer()
            }
            .padding(.bottom, 10)

            let processes = orderedProcesses(for: s)
            if !processes.isEmpty {
                // Column headers
                HStack {
                    Text("Process")
                        .font(DesignTokens.Font.label)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU")
                        .font(DesignTokens.Font.label)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(width: 70, alignment: .trailing)
                    Text("MEM")
                        .font(DesignTokens.Font.label)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

                VStack(spacing: 0) {
                    ForEach(Array(processes.prefix(8).enumerated()), id: \.element.id) { i, proc in
                        processRow(proc, index: i)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).stroke(DesignTokens.Color.separatorLight, lineWidth: 1))
            } else {
                Text("No process data")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
        }
        .padding(18)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private func processRow(_ proc: ProcessInfo, index: Int) -> some View {
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
                .foregroundStyle(cpuColor(proc.cpu))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text("\(proc.memory.pctString)%")
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.secondary)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(index % 2 == 0 ? DesignTokens.Color.cardBackground : DesignTokens.Color.pageBackground)
    }

    // MARK: - Reusable Components

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
        FeatureLoadingView(
            icon: "gauge.medium",
            tint: DesignTokens.Color.accent,
            title: "Reading system status",
            subtitle: "Gathering memory, disk, and battery metrics"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Progress Bars

struct ProgressBar: View {
    let value: Double
    let color: SwiftUI.Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.Color.pageBackground).frame(height: height)
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1), height: height)
            }
        }.frame(height: height)
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
