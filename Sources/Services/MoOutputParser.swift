import Foundation

// Pure, dependency-free parsers for Mole's human-readable output.
//
// Mole 1.40.0 exposes `--json` only for `status`, `uninstall --list`, and
// `analyze`. Clean and purge have no JSON, so their results are produced by
// parsing text keyed on glyph markers (`===`, `━━━`, `#`). If Mole's output
// format changes, these parsers silently return empty results — the single
// most fragile cross-component dependency in the app. These functions are
// extracted out of the `MoService` actor (pure, no disk/actor isolation) so
// they can be regression-tested against golden fixtures (see MoguTests).
enum MoOutputParser {

    // The exact literal `clean.sh` prints when system-level cleanup is skipped
    // for lack of sudo. CleanView matches on this to offer admin escalation.
    // Kept here as the single source of truth so the test guards the literal.
    static let systemCleanupSkipMarker = "System-level cleanup skipped, requires sudo"

    static func detectsSystemCleanupSkip(in text: String) -> Bool {
        text.contains(systemCleanupSkipMarker)
    }

    // Parse a human-readable size like "353.4MB", "1.19GB", or "104KB" to bytes.
    static func parseByteSize(_ text: String) -> UInt64? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB|TB|KiB|MiB|GiB|TiB)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else { return nil }

        let unit = text[unitRange].lowercased()
        let multiplier: Double
        switch unit {
        case "b": multiplier = 1
        case "kb", "kib": multiplier = 1024
        case "mb", "mib": multiplier = 1024 * 1024
        case "gb", "gib": multiplier = 1024 * 1024 * 1024
        case "tb", "tib": multiplier = 1024 * 1024 * 1024 * 1024
        default: return nil
        }
        return UInt64(value * multiplier)
    }

    static func parseHumanSize(_ text: String) -> UInt64? {
        parseByteSize(text)
    }

    // Clean preview format (from ~/.config/mole/clean-list.txt):
    //   # comment lines (skipped)
    //   === Section name ===
    //   /path  # 1.19GB, 10 items
    // We sum the `# size` of each path under its section.
    static func parseCleanList(text: String) -> CleanResult {
        var currentSection: String?
        var sectionSizes: [String: UInt64] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.hasPrefix("#") else { continue }
            if line.hasPrefix("==="), line.hasSuffix("===") {
                currentSection = line
                    .replacingOccurrences(of: "=", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            guard let currentSection, let hashIndex = line.firstIndex(of: "#") else { continue }
            let comment = String(line[line.index(after: hashIndex)...])
            if let size = parseByteSize(comment) {
                sectionSizes[currentSection, default: 0] += size
            }
        }

        let categories = sectionSizes
            .filter { $0.value > 0 }
            .map { CleanCategory(name: $0.key, size: $0.value, selected: true) }
            .sorted { $0.size > $1.size }
        let total = categories.reduce(UInt64(0)) { $0 + $1.size }
        return CleanResult(categories: categories, totalFreed: total, freeSpaceAfter: nil)
    }

    // Purge dry-run format:
    //   ━━━ Node.js ━━━
    //   ~/Repos/myproject/node_modules  # 245.3MB
    // We sum the `# size` of each path under its section header.
    static func parsePurgeText(_ text: String) -> PurgeResult {
        var currentSection: String?
        var projectsByName: [String: (size: UInt64, count: Int)] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("━━━"), line.hasSuffix("━━━") {
                currentSection = line
                    .trimmingCharacters(in: CharacterSet(charactersIn: "━ "))
                continue
            }

            guard currentSection != nil else { continue }

            if let hashIndex = line.firstIndex(of: "#"), let section = currentSection {
                let sizeText = String(line[line.index(after: hashIndex)...])
                let size = parseHumanSize(sizeText)
                projectsByName[section, default: (0, 0)].size += size ?? 0
                projectsByName[section, default: (0, 0)].count += 1
            }
        }

        let projects = projectsByName
            .filter { $0.value.size > 0 }
            .map { name, data in
                PurgeProject(
                    name: name,
                    size: data.size,
                    type: purgeCategoryToType(name),
                    isRecent: nil,
                    selected: true
                )
            }
            .sorted { $0.size > $1.size }
        let total = projects.reduce(UInt64(0)) { $0 + $1.size }
        return PurgeResult(projects: projects, totalSize: total)
    }

    static func purgeCategoryToType(_ category: String) -> String {
        switch category.lowercased() {
        case let s where s.contains("node") || s.contains("npm") || s.contains("yarn") || s.contains("pnpm"): return "Node.js"
        case let s where s.contains("rust") || s.contains("cargo") || s.contains("target"): return "Rust/Cargo"
        case let s where s.contains("python") || s.contains("pip") || s.contains("__pycache__") || s.contains(".venv"): return "Python"
        case let s where s.contains("swift") || s.contains("spm") || s.contains(".build"): return "Swift/SPM"
        case let s where s.contains("go") || s.contains("golang"): return "Go"
        case let s where s.contains("java") || s.contains("gradle") || s.contains("maven"): return "Java"
        case let s where s.contains("docker") || s.contains("container"): return "Docker"
        default: return "Other"
        }
    }
}
