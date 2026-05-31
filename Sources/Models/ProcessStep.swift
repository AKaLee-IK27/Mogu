import Foundation

// A single step in a multi-step `mo` operation, used to render live progress.
// `mo` streams `➤ Step name` headers followed by `→ detail` lines as it runs;
// the parser below folds that stream into an ordered, stateful list.

enum StepState: Equatable {
    case pending   // not reached yet
    case running   // currently executing
    case done      // finished successfully
    case failed    // errored
    case skipped   // not run (e.g. needs admin and elevation was declined)
}

struct ProcessStep: Identifiable, Equatable {
    let id: Int
    let name: String
    var state: StepState
    var details: [String]
    var requiresAdmin: Bool
}

// Folds a stream of `mo` output lines into `[ProcessStep]`. Stateful: feed each
// line via `consume`, then call `finish` when the process exits.
struct StepStreamParser {
    private(set) var steps: [ProcessStep] = []
    private var current: Int?

    mutating func consume(_ rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }

        if line.hasPrefix("➤") {
            // New step starts; close out the previous running one.
            if let c = current, steps[c].state == .running { steps[c].state = .done }
            let name = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            steps.append(ProcessStep(id: steps.count, name: name, state: .running,
                                     details: [], requiresAdmin: false))
            current = steps.count - 1
        } else if line.hasPrefix("→"), let c = current {
            let detail = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            steps[c].details.append(detail)
            // Honest reporting: a detail line that signals a permission/elevation
            // gap marks the step skipped/failed rather than silently "done".
            let lower = detail.lowercased()
            if lower.contains("permission denied") || lower.contains("requires sudo")
                || lower.contains("needs admin") || lower.contains("not permitted") {
                steps[c].state = .skipped
                steps[c].requiresAdmin = true
            } else if lower.contains("error") || lower.contains("failed") {
                steps[c].state = .failed
            }
        }
    }

    mutating func finish() {
        if let c = current, steps[c].state == .running { steps[c].state = .done }
    }
}
