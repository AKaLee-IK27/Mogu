import SwiftUI

struct OptimizeView: View {
    let service: MoService
    @Binding var previewTrigger: UUID
    @Binding var runTrigger: UUID
    @Binding var isRunning: Bool
    @Binding var isComplete: Bool
    @State private var steps: [OptimizeStep] = []
    @State private var error: String?
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                if isRunning { runningView }
                else if isComplete { completeView }
                else if let error { errorView(message: error) }
                else { readyView }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .onChange(of: previewTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await runOptimizePreview() }
        }
        .onChange(of: runTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await runOptimizeRun() }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Optimization")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Rebuild caches, refresh services, optimize performance")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var readyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(SwiftUI.Color(hex: "ff9f0a").opacity(0.8))

            VStack(spacing: 6) {
                Text("Ready to optimize")
                    .font(DesignTokens.Font.section)
                Text("Preview what will be optimized, then run all tasks")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.defaultSteps, id: \.self) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(DesignTokens.Color.tertiary.opacity(0.25))
                            .frame(width: 6, height: 6)
                        Text(step)
                            .font(DesignTokens.Font.body)
                            .foregroundStyle(DesignTokens.Color.secondary)
                    }
                }
            }
            .padding(16)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var runningView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.2)
            Text("Optimizing system...").font(DesignTokens.Font.section)

            if !steps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignTokens.Color.successText)
                            Text(step.description)
                                .font(DesignTokens.Font.bodyStrong)
                                .foregroundStyle(DesignTokens.Color.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        if i < steps.count - 1 {
                            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 34)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(DesignTokens.Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(DesignTokens.Color.successText.opacity(0.8))

            VStack(spacing: 6) {
                Text("Optimization Complete")
                    .font(DesignTokens.Font.section)
                Text("\(steps.count) steps completed")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }

            if !steps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(steps) { step in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignTokens.Color.successText)
                            Text(step.description)
                                .font(DesignTokens.Font.bodyStrong)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 16)
                .background(DesignTokens.Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
            }

            Button("Optimize Again") {
                withAnimation(DesignTokens.spring) { isComplete = false; steps = [] }
                Task { await runOptimizePreview() }
            }
            .buttonStyle(.bordered)
            .tint(DesignTokens.Color.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 24)).foregroundStyle(DesignTokens.Color.danger)
            Text(message).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runOptimizePreview() async {
        isRunning = true
        isComplete = false
        error = nil
        steps = []
        do {
            let result = try await service.executeOptimize()
            steps = result.steps
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
        isComplete = true
    }

    private func runOptimizeRun() async {
        isRunning = true
        isComplete = false
        error = nil
        steps = []
        do {
            let result = try await service.executeOptimizeRun()
            steps = result.steps
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
        isComplete = true
    }

    private static let defaultSteps = [
        "DNS cache flush & Spotlight index verify",
        "Finder cache & icon services refresh",
        "App saved states cleanup",
        "Broken config repair",
        "Network cache refresh",
        "Database optimization",
        "LaunchServices repair",
        "Dock refresh",
        "Memory optimization",
        "Permission repair",
        "Spotlight optimization",
        "Login items health check",
    ]
}
