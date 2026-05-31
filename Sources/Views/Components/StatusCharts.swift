import Charts
import SwiftUI

struct LiveSparkline: View {
    let samples: [StatusSample]
    let title: String
    let color: SwiftUI.Color
    let yDomain: ClosedRange<Double>
    let value: (StatusSample) -> Double

    var body: some View {
        Chart(samples) { sample in
            LineMark(
                x: .value("Time", sample.time),
                y: .value(title, value(sample))
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .frame(height: 44)
        .accessibilityLabel(title)
    }
}

struct PerCoreStrip: View {
    let perCore: [Double]
    let pCoreCount: Int
    let eCoreCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                coreLegend(label: "P", color: DesignTokens.Color.accent)
                coreLegend(label: "E", color: DesignTokens.Color.accentSecondary)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(perCore.enumerated()), id: \.offset) { index, usage in
                    Capsule()
                        .fill(coreColor(at: index))
                        .frame(width: 5, height: max(4, min(1, max(0, usage / 100)) * 30))
                        .frame(height: 30, alignment: .bottom)
                        .accessibilityLabel("Core \(index + 1)")
                        .accessibilityValue("\(usage.pctString)%")
                }
            }
        }
    }

    private func coreLegend(label: String, color: SwiftUI.Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(DesignTokens.Font.label)
                .foregroundStyle(DesignTokens.Color.tertiary)
        }
    }

    private func coreColor(at index: Int) -> SwiftUI.Color {
        index < pCoreCount ? DesignTokens.Color.accent : DesignTokens.Color.accentSecondary
    }
}

struct MemoryBreakdownBar: View {
    let memory: MemoryInfo

    private var cached: UInt64 { min(memory.cached ?? 0, memory.total) }
    private var activeUsed: UInt64 { memory.used > cached ? memory.used - cached : memory.used }
    private var free: UInt64 { memory.total > memory.used ? memory.total - memory.used : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(DesignTokens.Color.accentSecondary)
                        .frame(width: segmentWidth(activeUsed, in: geo.size.width))
                    Rectangle()
                        .fill(DesignTokens.Color.accentSoft)
                        .frame(width: segmentWidth(cached, in: geo.size.width))
                    Rectangle()
                        .fill(DesignTokens.Color.pageBackground)
                        .frame(width: segmentWidth(free, in: geo.size.width))
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DesignTokens.Color.separatorLight, lineWidth: 1))
            }
            .frame(height: 8)

            HStack(spacing: 10) {
                breakdownLabel("Used", activeUsed.humanReadable, color: DesignTokens.Color.accentSecondary)
                breakdownLabel("Cached", cached.humanReadable, color: DesignTokens.Color.accentSoft)
                Spacer(minLength: 0)
            }

            if let swapUsed = memory.swapUsed, let swapTotal = memory.swapTotal {
                HStack(spacing: 6) {
                    Text("Swap")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                    Text("\(swapUsed.humanReadable) / \(swapTotal.humanReadable)")
                        .font(DesignTokens.Font.mono)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
            }
        }
    }

    private func segmentWidth(_ amount: UInt64, in totalWidth: CGFloat) -> CGFloat {
        guard memory.total > 0 else { return 0 }
        return totalWidth * CGFloat(Double(amount) / Double(memory.total))
    }

    private func breakdownLabel(_ label: String, _ value: String, color: SwiftUI.Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.tertiary)
            Text(value)
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.secondary)
        }
    }
}
