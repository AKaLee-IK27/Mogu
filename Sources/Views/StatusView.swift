import SwiftUI

struct StatusView: View {
    let service: MoService
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool
    @State private var status: SystemStatus?
    @State private var error: String?
    @State private var lastUpdated: Date?
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            if let status {
                headerBar(status)
                Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        primaryMetrics(status)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)

                        Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)
                            .padding(.horizontal, 24)

                        secondaryMetrics(status)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 6)

                        Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)
                            .padding(.horizontal, 24)

                        processesSection(status)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 4)
                    }
                    .padding(.vertical, 24)
                }
            } else if isLoading {
                loadingView
            } else if let error {
                errorView(message: error)
            }
        }
        .background(DesignTokens.Color.pageBackground)
        .task { await refresh() }
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await refresh() }
        }
    }

    private func headerBar(_ status: SystemStatus) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Status")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text(status.hardware.displayLabel)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            healthBadge(score: status.healthScore)
            if let lastUpdated {
                Text(lastUpdated.formatted(date: .omitted, time: .shortened))
                    .font(DesignTokens.Font.label)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
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
        HStack(spacing: 0) {
            cpuSection(s.cpu).frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 24)
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(width: 1)
            memorySection(s.memory).frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 24)
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(width: 1)
            diskSection(s.disks).frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 24)
        }
    }

    private func cpuSection(_ cpu: CPUInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CPU", value: "\(cpu.usage.pctString)%", subtitle: "\(cpu.pCoreCount)P + \(cpu.eCoreCount)E cores")
            ProgressBar(value: cpu.usage / 100, color: DesignTokens.Color.accent)
            HStack(spacing: 6) {
                loadBadge(label: "1m", value: cpu.load1)
                loadBadge(label: "5m", value: cpu.load5)
                loadBadge(label: "15m", value: cpu.load15)
            }
        }
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
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }

    private func memorySection(_ mem: MemoryInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Memory", value: "\(mem.usedPercent.pctString)%", subtitle: mem.used.humanReadable)
            ProgressBar(value: mem.usedPercent / 100, color: DesignTokens.Color.accentSecondary)
            HStack {
                statLine("Used", mem.used.humanReadable)
                Spacer()
                statLine("Free", mem.free.humanReadable)
            }
        }
    }

    private func diskSection(_ disks: [DiskInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Disk")
            ForEach(disks.prefix(2)) { disk in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(disk.mount)
                            .font(DesignTokens.Font.caption)
                            .foregroundStyle(DesignTokens.Color.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(disk.usedPercent.pctString)%").font(DesignTokens.Font.mono)
                    }
                    MiniBar(value: disk.usedPercent / 100, color: DesignTokens.Color.accent)
                }
            }
        }
    }

    private func secondaryMetrics(_ s: SystemStatus) -> some View {
        HStack(spacing: 0) {
            if let battery = s.batteries?.first {
                batterySection(battery).frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 24)
                Rectangle().fill(DesignTokens.Color.separatorLight).frame(width: 1)
            }
            if let network = s.network, !network.isEmpty {
                networkSection(network).frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 24)
                Rectangle().fill(DesignTokens.Color.separatorLight).frame(width: 1)
            }
            if let thermal = s.thermal {
                thermalSection(thermal).frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 24)
            }
        }
    }

    private func batterySection(_ b: BatteryInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Battery", value: "\(b.percent)%")
            HStack(spacing: 12) {
                if let health = b.health { statLine("Health", health) }
                if let cycles = b.cycleCount { statLine("Cycles", "\(cycles)") }
                if let cap = b.capacity { statLine("Max", "\(cap)%") }
            }
        }
    }

    private func networkSection(_ interfaces: [NetworkInterface]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Network")
            ForEach(interfaces.prefix(3), id: \.name) { iface in
                HStack {
                    Text(iface.name).font(DesignTokens.Font.label).foregroundStyle(DesignTokens.Color.tertiary).frame(width: 30, alignment: .leading)
                    Spacer()
                    if let rx = iface.rxRate, rx > 0 {
                        Text(String(format: "↓ %.1f", rx)).font(DesignTokens.Font.mono).foregroundStyle(DesignTokens.Color.successText)
                    }
                    if let tx = iface.txRate, tx > 0 {
                        Text(String(format: "↑ %.1f", tx)).font(DesignTokens.Font.mono).foregroundStyle(DesignTokens.Color.accentTint)
                    }
                }
            }
        }
    }

    private func thermalSection(_ t: ThermalInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Thermal")
            if let temp = t.batteryTemp, temp > 0 { statLine("Battery", String(format: "%.1f°C", temp)) }
            if let fan = t.fanSpeed, fan > 0 { statLine("Fan", "\(fan) RPM") }
            if t.batteryTemp == nil && t.fanSpeed == nil {
                Text("No thermal data").font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.tertiary)
            }
        }
    }

    private func processesSection(_ s: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Top Processes", subtitle: "by CPU usage")
                .padding(.horizontal, 32).padding(.top, 20).padding(.bottom, 12)

            if let processes = s.topProcesses, !processes.isEmpty {
                HStack {
                    Text("Process").font(DesignTokens.Font.label).foregroundStyle(DesignTokens.Color.tertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 32)
                    Text("CPU").font(DesignTokens.Font.label).foregroundStyle(DesignTokens.Color.tertiary).frame(width: 80, alignment: .trailing).padding(.trailing, 32)
                }.padding(.bottom, 8)

                ForEach(Array(processes.prefix(8).enumerated()), id: \.offset) { i, proc in
                    HStack {
                        Text(proc.name).font(DesignTokens.Font.body).foregroundStyle(DesignTokens.Color.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 32)
                        Text("\(proc.cpu.pctString)%").font(DesignTokens.Font.mono).frame(width: 80, alignment: .trailing).padding(.trailing, 32)
                    }
                    .padding(.vertical, 8)
                    .background(i % 2 == 0 ? DesignTokens.Color.cardBackground : DesignTokens.Color.pageBackground)
                }
            }
        }
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
            }
            Spacer()
        }
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.tertiary)
            Text(value).font(DesignTokens.Font.mono).foregroundStyle(DesignTokens.Color.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Reading system data...").font(DesignTokens.Font.body).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 24)).foregroundStyle(DesignTokens.Color.danger)
            Text(message).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        isLoading = true; error = nil
        do {
            status = try await service.getStatus()
            lastUpdated = Date()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        withAnimation(DesignTokens.spring) { appear = true }
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
