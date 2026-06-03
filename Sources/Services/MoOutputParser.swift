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
    // We keep each path as an item under its section and sum their sizes for
    // the section total. Sections in encounter order; empty/zero-size sections
    // are dropped so the drill-down tree never shows an empty node.
    static func parseCleanList(text: String) -> CleanResult {
        var order: [String] = []
        var itemsBySection: [String: [CleanItem]] = [:]
        var currentSection: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.hasPrefix("#") else { continue }
            if line.hasPrefix("==="), line.hasSuffix("===") {
                let name = line
                    .replacingOccurrences(of: "=", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if itemsBySection[name] == nil {
                    itemsBySection[name] = []
                    order.append(name)
                }
                // Track the active header explicitly so paths attribute to the
                // section they fall under even if a header repeats (order keeps
                // first-seen position only, for stable tie-breaking).
                currentSection = name
                continue
            }

            guard let currentSection, let hashIndex = line.firstIndex(of: "#") else { continue }
            let path = String(line[..<hashIndex]).trimmingCharacters(in: .whitespaces)
            let comment = String(line[line.index(after: hashIndex)...])
            guard !path.isEmpty, let size = parseByteSize(comment) else { continue }
            itemsBySection[currentSection, default: []]
                .append(CleanItem(path: path, size: size, itemCount: parseItemCount(comment)))
        }

        let categories = order
            .compactMap { name -> CleanCategory? in
                let items = (itemsBySection[name] ?? []).sorted { $0.size > $1.size }
                let total = items.reduce(UInt64(0)) { $0 + $1.size }
                guard total > 0 else { return nil }
                return CleanCategory(name: name, size: total, selected: true, items: items)
            }
            .sorted { $0.size > $1.size }
        let total = categories.reduce(UInt64(0)) { $0 + $1.size }
        return CleanResult(categories: categories, totalFreed: total, freeSpaceAfter: nil)
    }

    // Parse the "N items" hint from a clean-list comment like "1.19GB, 10 items".
    static func parseItemCount(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"([0-9]+)\s+items?"#, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[r])
    }

    // A streamed `clean --dry-run` stdout line that represents a discovered
    // location: it either reports a size or says it "would clean" something.
    // Both are real findings, so counting both keeps the live "found N" counter
    // climbing steadily through the scan rather than jumping only on sized
    // lines. Drives the scan counter only, never the structured result.
    static func isCleanScanFinding(_ line: String) -> Bool {
        parseByteSize(line) != nil || line.localizedCaseInsensitiveContains("would clean")
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

    // Uninstall dry-run preview (no JSON; driven by `uninstall <names…> --dry-run`
    // with a fed `y` confirmation). Format, verified live on Mole 1.40.0:
    //
    //   Files to be removed:
    //
    //   ◎ IINA , 235.5MB
    //     ✓ /Applications/IINA.app
    //     ✓ ~/Library/Application Support/com.colliderli.iina
    //   ◎ Bruno , 471.7MB
    //     ✓ /Applications/Bruno.app
    //
    //   ➤ Remove 2 apps, 707.3MB  Enter confirm, ESC cancel:
    //
    // Parsing is glyph-agnostic on purpose (Mole's exact icons may change): a
    // file line is one whose text after the leading marker is an absolute or
    // `~/` path; a group header is `<marker> <name> , <size>`; the terminator is
    // `<marker> Remove N app(s), <total>`. Everything before "Files to be
    // removed:" (including the `◎ Matched N app(s):` summary) is ignored, as is
    // ANSI/cursor control noise from the scan spinner (stderr is merged in).
    // On format drift this returns an empty preview — the golden-fixture test
    // (Tests/MoguTests) fails loudly so the drift is caught.
    static func parseUninstallPreview(text: String) -> UninstallPreview {
        var inSection = false
        var apps: [UninstallPreviewApp] = []
        var grandTotal: UInt64?
        var currentName: String?
        var currentSize: UInt64 = 0
        var currentPaths: [String] = []

        func flush() {
            guard let name = currentName else { return }
            apps.append(UninstallPreviewApp(name: name, size: currentSize, paths: currentPaths))
            currentName = nil
            currentSize = 0
            currentPaths = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = stripControlSequences(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if !inSection {
                if line.contains("Files to be removed") { inSection = true }
                continue
            }

            // Split off the leading marker glyph (e.g. ◎ / ✓ / ➤) from the rest.
            let remainder = dropLeadingMarker(line)

            // File path line: the marker is followed by an absolute or ~ path.
            if remainder.hasPrefix("/") || remainder.hasPrefix("~/") {
                if currentName != nil { currentPaths.append(remainder) }
                continue
            }

            // Terminator: `Remove N app(s), <total>` — capture the grand total and stop.
            if remainder.hasPrefix("Remove "), remainder.contains("app") {
                grandTotal = parseByteSize(remainder)
                break
            }

            // Group header: `<name> , <size>` (space-comma-space distinguishes it
            // from the terminator's `apps,`). Starts a new app group.
            if let comma = remainder.range(of: " , "), let size = parseByteSize(String(remainder[comma.upperBound...])) {
                flush()
                currentName = String(remainder[..<comma.lowerBound]).trimmingCharacters(in: .whitespaces)
                currentSize = size
                currentPaths = []
            }
        }
        flush()

        let total = grandTotal ?? apps.reduce(UInt64(0)) { $0 + $1.size }
        return UninstallPreview(apps: apps, totalSize: total)
    }

    // Drop a single leading non-path "marker" token (the bullet/check/arrow glyph
    // Mole prints) plus its trailing space. If the first token already looks like
    // a path, leave the line untouched.
    private static func dropLeadingMarker(_ line: String) -> String {
        guard let space = line.firstIndex(of: " ") else { return line }
        let marker = line[..<space]
        // A real path or a normal word stays put; only strip a short symbol token.
        if marker.hasPrefix("/") || marker.hasPrefix("~") { return line }
        if marker.count <= 2 {
            return String(line[line.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    // Strip ANSI/VT100 control sequences (cursor moves, clears, colors) and bare
    // ESC/CR bytes that the scan spinner emits to stderr (merged into the stream).
    static func stripControlSequences(_ s: String) -> String {
        var result = s
        if let regex = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", options: []) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result.replacingOccurrences(of: "\u{1B}", with: "")
            .replacingOccurrences(of: "\r", with: "")
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

    // Installer preview format (from `mo installer --dry-run` TUI output):
    // After stripping ANSI/CR, each installer line looks like:
    //   "  ○ Arc-1.148.0.dmg                     431.4MB | Downloads"
    //   "➤ ○ Brave-Browser.dmg                   246.2MB | Downloads"
    // Pattern: optional bullet prefix, name, whitespace, size, " | ", location
    static func parseInstallerList(text: String) -> InstallerResult {
        var files: [InstallerFile] = []
        // Match lines with: optional leading chars, name, whitespace, size, " | ", location
        let pattern = #"[○●]\s+(.+?)\s+([0-9.]+\s*(?:TB|GB|MB|KB|B))\s*\|\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return InstallerResult(files: [])
        }

        let lines = text.split(separator: "\n")
        for line in lines {
            let stripped = stripControlSequences(String(line)).trimmingCharacters(in: .whitespaces)
            let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            guard let match = regex.firstMatch(in: stripped, options: [], range: range),
                  let nameRange = Range(match.range(at: 1), in: stripped),
                  let sizeRange = Range(match.range(at: 2), in: stripped),
                  let locRange = Range(match.range(at: 3), in: stripped) else { continue }

            let name = String(stripped[nameRange]).trimmingCharacters(in: .whitespaces)
            let sizeText = String(stripped[sizeRange]).trimmingCharacters(in: .whitespaces)
            let location = String(stripped[locRange]).trimmingCharacters(in: .whitespaces)
            guard let size = parseByteSize(sizeText), !name.isEmpty else { continue }

            let path = location.contains("/") ? "\(location)/\(name)" : "~/\(location)/\(name)"
            files.append(InstallerFile(name: name, path: path, size: size, location: location))
        }
        return InstallerResult(files: files)
    }
}
