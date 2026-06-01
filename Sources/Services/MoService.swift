import Foundation

enum MoError: Error, LocalizedError {
    case commandNotFound
    case executionFailed(String)
    case decodeError(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .commandNotFound:
            return "Bundled Mole runtime is missing or not executable. Rebuild the app with ./build_app.sh."
        case .executionFailed(let msg):
            return "Command failed: \(msg)"
        case .decodeError(let msg):
            return "Failed to parse response: \(msg)"
        case .permissionDenied:
            return "Permission denied. Mole may need sudo privileges."
        }
    }
}

// Events emitted while streaming a `mo` invocation line-by-line.
enum MoStreamEvent: Sendable {
    case line(String)       // one line of stdout/stderr as it arrives
    case finished(Int32)    // process exited with this status code
    case error(String)      // failed to launch
}

actor MoService {
    private let moPath: String
    private var cleanPreviewReady = false

    init(moPath: String? = nil) {
        self.moPath = moPath ?? Self.resolveMoPath()
    }

    private static func resolveMoPath() -> String {
        let fileManager = FileManager.default

        if let resourceURL = Bundle.main.resourceURL {
            let bundledPath = resourceURL
                .appendingPathComponent("MoleRuntime")
                .appendingPathComponent("mo")
                .path
            if fileManager.isExecutableFile(atPath: bundledPath) {
                return bundledPath
            }
        }

        if let overridePath = Foundation.ProcessInfo.processInfo.environment["MOLEMAC_MO_PATH"],
           !overridePath.isEmpty {
            return overridePath
        }

        #if DEBUG
        for candidate in ["/opt/homebrew/bin/mo", "/usr/local/bin/mo"] where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }
        #endif

        return Bundle.main.resourceURL?
            .appendingPathComponent("MoleRuntime")
            .appendingPathComponent("mo")
            .path ?? "/nonexistent/MoleRuntime/mo"
    }

    // Check if mole is installed and accessible
    func isAvailable() async -> Bool {
        let result = await runCommand(args: ["--version"])
        return result != nil
    }

    // Get system status
    func getStatus() async throws -> SystemStatus {
        let output = try await runCommandOrThrow(args: ["status", "--json"])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        do {
            return try decoder.decode(SystemStatus.self, from: output)
        } catch {
            throw MoError.decodeError(error.localizedDescription)
        }
    }

    // Preview-before-delete guard: the destructive clean run (streamed elevated
    // from the view) must only proceed after a preview has populated this flag.
    func cleanPreviewIsReady() -> Bool { cleanPreviewReady }

    // Get uninstallable apps. Mole 1.40.0 uses `mo uninstall --list` for JSON,
    // not `--dry-run --json`. Size is a string like "353.4MB".
    func getUninstallList() async throws -> UninstallResult {
        let output = try await runCommandOrThrow(args: ["uninstall", "--list"])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let rawApps = try decoder.decode([RawAppInfo].self, from: output)
        let apps = rawApps.map { app in
            AppInfo(
                name: app.name,
                size: parseHumanSize(app.size) ?? 0,
                bundleID: app.bundleID,
                status: nil,
                relatedFiles: nil,
                uninstallName: app.uninstallName
            )
        }
        let total = apps.reduce(UInt64(0)) { $0 + $1.size }
        return UninstallResult(apps: apps, totalSize: total)
    }

    // Get disk analysis
    func getAnalysis(path: String = NSHomeDirectory()) async throws -> AnalysisResult {
        let output = try await runCommandOrThrow(args: ["analyze", "--json", path])
        return try decode(AnalysisResult.self, from: output)
    }

    // MARK: - Streaming preview helpers
    // These pair with `stream(args:)`: the view streams the command live for the
    // activity feed, then calls one of these to build the structured result.

    // Clear the stale clean preview file before a fresh streamed scan.
    func resetCleanPreview() {
        cleanPreviewReady = false
        try? FileManager.default.removeItem(at: cleanPreviewURL)
    }

    // After a streamed `clean --dry-run`, parse the side file into categories and
    // mark the preview ready (enforces preview-before-delete for the clean run).
    func finalizeCleanPreview() -> CleanResult {
        cleanPreviewReady = true
        return parseCleanPreview(stdout: Data())
    }

    // Build purge projects from accumulated streamed stdout text.
    func purgeResult(fromText text: String) -> PurgeResult {
        parsePurgePreview(stdout: Data(text.utf8))
    }

    // MARK: - Private

    private struct CommandResult {
        let stdout: Data
        let stderr: Data
        let status: Int32

        var outputText: String {
            String(data: stdout, encoding: .utf8) ?? ""
        }

        var errorMessage: String {
            let stderrText = String(data: stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !stderrText.isEmpty { return stderrText }

            let stdoutText = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            return stdoutText.isEmpty ? "Unknown error" : stdoutText
        }
    }

    private func runCommand(args: [String]) async -> Data? {
        guard let result = await runCommandResult(args: args) else { return nil }
        guard result.status == 0 else {
            Logger.log("mo \(args.joined(separator: " ")) failed: \(result.errorMessage)")
            return nil
        }
        return result.stdout
    }

    private func runCommandOrThrow(args: [String]) async throws -> Data {
        guard let result = await runCommandResult(args: args) else {
            throw MoError.commandNotFound
        }
        guard result.status == 0 else {
            throw MoError.executionFailed(result.errorMessage)
        }
        return result.stdout
    }

    private var cleanPreviewURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/mole/clean-list.txt")
    }

    // Shared environment for all `mo` invocations: disable color/locale/paging
    // so output is plain and parseable, and force non-interactive behavior.
    nonisolated static func makeEnvironment() -> [String: String] {
        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        environment["TERM"] = "dumb"
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["NONINTERACTIVE"] = "1"
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        return environment
    }

    // Stream a `mo` invocation line-by-line as it runs, so the UI can show live
    // step-by-step progress. stdout and stderr are merged. `nonisolated` so the
    // blocking process read never ties up the actor; it runs in a detached task.
    nonisolated func stream(args: [String]) -> AsyncStream<MoStreamEvent> {
        let path = moPath
        return AsyncStream { continuation in
            let work = Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
                process.environment = Self.makeEnvironment()

                let pipe = Pipe()
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                    return
                }

                // Read with availableData so each burst flushes immediately —
                // FileHandle.bytes buffers and would delay live progress.
                let handle = pipe.fileHandleForReading
                var buffer = Data()
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break } // EOF
                    buffer.append(chunk)
                    while let nl = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                        buffer.removeSubrange(buffer.startIndex...nl)
                        continuation.yield(.line(String(decoding: lineData, as: UTF8.self)))
                    }
                }
                if !buffer.isEmpty {
                    continuation.yield(.line(String(decoding: buffer, as: UTF8.self)))
                }

                process.waitUntilExit()
                continuation.yield(.finished(process.terminationStatus))
                continuation.finish()
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    // Stream a `mo` invocation with administrator privileges. osascript's
    // `do shell script ... with administrator privileges` shows the native admin
    // / Touch ID dialog and runs the command as root — but it does NOT stream its
    // output. So the elevated command redirects to a temp log that we tail live,
    // preserving the same step-by-step UI. If the user cancels auth, an `.error`
    // is emitted before `.finished`.
    nonisolated func streamElevated(args: [String]) -> AsyncStream<MoStreamEvent> {
        let path = moPath
        return AsyncStream { continuation in
            let work = Task.detached {
                let logURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("molemac-elevated-\(UUID().uuidString).log")
                FileManager.default.createFile(atPath: logURL.path, contents: nil)

                // Build the root shell command: explicit env + mo + args, output
                // redirected to the log we tail.
                let env = Self.makeEnvironment()
                let envPrefix = ["NO_COLOR", "LC_ALL", "LANG", "TERM", "NONINTERACTIVE", "PATH"]
                    .compactMap { key in env[key].map { "\(key)=\(Self.shellQuote($0))" } }
                    .joined(separator: " ")
                let argStr = args.map { Self.shellQuote($0) }.joined(separator: " ")
                let shellCmd = "\(envPrefix) \(Self.shellQuote(path)) \(argStr) "
                    + "> \(Self.shellQuote(logURL.path)) 2>&1"
                let escaped = shellCmd
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", appleScript]
                let errPipe = Pipe()
                process.standardInput = FileHandle.nullDevice
                process.standardError = errPipe
                process.standardOutput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    try? FileManager.default.removeItem(at: logURL)
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                    return
                }

                // Tail the log while the elevated process runs.
                let handle = try? FileHandle(forReadingFrom: logURL)
                var buffer = Data()
                func drain() {
                    guard let handle else { return }
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { return }
                    buffer.append(chunk)
                    while let nl = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                        buffer.removeSubrange(buffer.startIndex...nl)
                        continuation.yield(.line(String(decoding: lineData, as: UTF8.self)))
                    }
                }
                while process.isRunning {
                    drain()
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                drain()
                if !buffer.isEmpty {
                    continuation.yield(.line(String(decoding: buffer, as: UTF8.self)))
                }
                try? handle?.close()

                let status = process.terminationStatus
                if status != 0 {
                    let errText = String(decoding: (try? errPipe.fileHandleForReading.readToEnd()) ?? Data(),
                                         as: UTF8.self).lowercased()
                    if errText.contains("-128") || errText.contains("cancel") {
                        continuation.yield(.error("Administrator permission was declined."))
                    }
                }
                try? FileManager.default.removeItem(at: logURL)
                continuation.yield(.finished(status))
                continuation.finish()
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    // Single-quote a string for safe interpolation into a /bin/sh command.
    nonisolated static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func runCommandResult(args: [String]) async -> CommandResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: moPath)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        process.environment = Self.makeEnvironment()

        let tempDir = FileManager.default.temporaryDirectory
        let id = UUID().uuidString
        let stdoutURL = tempDir.appendingPathComponent("molemac-\(id)-stdout.log")
        let stderrURL = tempDir.appendingPathComponent("molemac-\(id)-stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        guard let stdoutHandle = try? FileHandle(forWritingTo: stdoutURL),
              let stderrHandle = try? FileHandle(forWritingTo: stderrURL) else {
            return nil
        }

        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
            process.waitUntilExit()
            try? stdoutHandle.close()
            try? stderrHandle.close()

            let stdout = (try? Data(contentsOf: stdoutURL)) ?? Data()
            let stderr = (try? Data(contentsOf: stderrURL)) ?? Data()
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)

            return CommandResult(stdout: stdout, stderr: stderr, status: process.terminationStatus)
        } catch {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
            Logger.log("Failed to execute mo: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseCleanPreview(stdout: Data) -> CleanResult {
        let previewPath = cleanPreviewURL
        let text = (try? String(contentsOf: previewPath, encoding: .utf8))
            ?? String(data: stdout, encoding: .utf8)
            ?? ""

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

    // Parse a human-readable size string like "353.4MB" or "1.23GB" into bytes.
    private func parseHumanSize(_ text: String) -> UInt64? {
        parseByteSize(text)
    }

    private func parseByteSize(_ text: String) -> UInt64? {
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

    // MARK: - Purge parser
    // Purge dry-run output is text like:
    // ━━━ Node.js ━━━
    //   ~/Repos/myproject/node_modules  # 245.3MB
    // We parse section headers and size comments.
    private func parsePurgePreview(stdout: Data) -> PurgeResult {
        let text = String(data: stdout, encoding: .utf8) ?? ""
        var currentSection: String?
        var projectsByName: [String: (size: UInt64, count: Int)] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            // Section header: ━━━ Name ━━━
            if line.hasPrefix("━━━"), line.hasSuffix("━━━") {
                let inner = line
                    .trimmingCharacters(in: CharacterSet(charactersIn: "━ "))
                currentSection = inner
                continue
            }

            guard currentSection != nil else { continue }

            // Path line with size: ~/Repos/foo/node_modules  # 245.3MB
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

    private func purgeCategoryToType(_ category: String) -> String {
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

    private func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MoError.decodeError(error.localizedDescription)
        }
    }
}

// Simple logger
enum Logger {
    static func log(_ message: String) {
        #if DEBUG
        print("[MoleMac] \(message)")
        #endif
    }
}
