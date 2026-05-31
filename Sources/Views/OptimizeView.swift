import SwiftUI

struct OptimizeView: View {
    let service: MoService
    @ObservedObject var permissions: PermissionsService
    @Binding var previewTrigger: UUID
    @Binding var runTrigger: UUID
    @Binding var isRunning: Bool
    @Binding var isComplete: Bool
    @State private var steps: [ProcessStep] = []
    @State private var error: String?
    @State private var isPreviewing = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            PreflightBanner(item: .optimize, permissions: permissions)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    statusBanner
                    if !steps.isEmpty {
                        StepListView(steps: steps)
                            .padding(.horizontal, 24)
                    }
                    if isComplete {
                        Button("Optimize Again") {
                            isComplete = false
                            steps = []
                            Task { await runOptimizePreview() }
                        }
                        .buttonStyle(.bordered)
                        .tint(DesignTokens.Color.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
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
        .task { await runOptimizePreview() }
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
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-preview",
                             disabled: isRunning || isPreviewing) {
                Task { await runOptimizePreview() }
            }
            // Run is enabled once a preview has streamed in; disabled while a
            // preview/run is in flight or after completion.
            HeaderActionButton(label: "Run", systemName: "bolt.horizontal.circle.fill",
                               tint: DesignTokens.Color.warning,
                               disabled: isRunning || isPreviewing || isComplete || steps.isEmpty) {
                Task { await runOptimizeRun() }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    // Adapts to the current phase. The live step list renders below it.
    @ViewBuilder
    private var statusBanner: some View {
        if let error {
            bannerRow(icon: "exclamationmark.circle", tint: DesignTokens.Color.danger,
                      title: "Optimization failed", subtitle: error)
        } else if isComplete {
            bannerRow(icon: "checkmark.seal.fill", tint: DesignTokens.Color.successText,
                      title: "Optimization Complete", subtitle: "\(steps.count) steps")
        } else if isRunning {
            bannerRow(icon: nil, tint: DesignTokens.Color.warning,
                      title: "Optimizing system…", subtitle: "Running each task in order")
        } else if isPreviewing {
            bannerRow(icon: nil, tint: DesignTokens.Color.accent,
                      title: "Analyzing tasks…", subtitle: "Previewing what will run")
        } else if !steps.isEmpty {
            bannerRow(icon: "bolt.horizontal.circle.fill", tint: DesignTokens.Color.warning,
                      title: "Ready to optimize", subtitle: "Review the steps below, then Run")
        }
    }

    private func bannerRow(icon: String?, tint: SwiftUI.Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(tint)
            } else {
                ProgressView().scaleEffect(0.8).frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignTokens.Font.section).foregroundStyle(DesignTokens.Color.primary)
                Text(subtitle).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // Dry-run preview, streamed live. Lands in the "ready" state (NOT complete).
    private func runOptimizePreview() async {
        isPreviewing = true
        isComplete = false
        error = nil
        steps = []
        var parser = StepStreamParser()
        for await event in service.stream(args: ["optimize", "--dry-run"]) {
            switch event {
            case .line(let l):
                parser.consume(l)
                steps = parser.steps
            case .finished(let code):
                parser.finish()
                steps = parser.steps
                if code != 0 && steps.isEmpty {
                    error = "Optimization preview failed (exit \(code))."
                }
            case .error(let m):
                error = m
            }
        }
        isPreviewing = false
    }

    // Actual run (destructive), streamed live with administrator privileges so
    // steps that modify system files actually execute. If the user declines the
    // admin prompt, an `.error` is surfaced (and not overwritten by `.finished`).
    private func runOptimizeRun() async {
        isRunning = true
        isComplete = false
        error = nil
        steps = []
        var parser = StepStreamParser()
        for await event in service.streamElevated(args: ["optimize"]) {
            switch event {
            case .line(let l):
                parser.consume(l)
                steps = parser.steps
            case .finished(let code):
                parser.finish()
                steps = parser.steps
                if code == 0 {
                    isComplete = true
                } else if error == nil && steps.isEmpty {
                    error = "Optimization failed (exit \(code))."
                } else if error == nil {
                    // Partial: some steps ran but the process reported failure.
                    isComplete = true
                }
            case .error(let m):
                error = m
            }
        }
        isRunning = false
    }
}

// Renders a live, ordered list of process steps with per-step state icons and
// detail lines. Shared by any operation that streams `➤`/`→` output.
struct StepListView: View {
    let steps: [ProcessStep]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        stepIcon(step.state)
                            .frame(width: 18, height: 18)
                        Text(step.name)
                            .font(DesignTokens.Font.bodyStrong)
                            .foregroundStyle(DesignTokens.Color.primary)
                        if step.requiresAdmin {
                            Text("admin")
                                .font(DesignTokens.Font.label)
                                .foregroundStyle(DesignTokens.Color.warningText)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(DesignTokens.Color.warningSoft)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                        }
                        Spacer()
                        if step.state == .skipped {
                            Text("needs admin")
                                .font(DesignTokens.Font.caption)
                                .foregroundStyle(DesignTokens.Color.warningText)
                        }
                    }
                    ForEach(Array(step.details.enumerated()), id: \.offset) { _, d in
                        Text(d)
                            .font(DesignTokens.Font.caption)
                            .foregroundStyle(DesignTokens.Color.tertiary)
                            .padding(.leading, 28)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

                if i < steps.count - 1 {
                    Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 44)
                }
            }
        }
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
    }

    @ViewBuilder
    private func stepIcon(_ state: StepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle").font(.system(size: 14)).foregroundStyle(DesignTokens.Color.tertiary.opacity(0.5))
        case .running:
            ProgressView().scaleEffect(0.6)
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(DesignTokens.Color.successText)
        case .failed:
            Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(DesignTokens.Color.danger)
        case .skipped:
            Image(systemName: "minus.circle.fill").font(.system(size: 16)).foregroundStyle(DesignTokens.Color.warning)
        }
    }
}
