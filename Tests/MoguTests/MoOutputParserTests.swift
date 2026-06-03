import XCTest
@testable import Mogu

// Regression guard for the fragile text parsers. Mole exposes no JSON for clean
// or purge, so results come from parsing human-readable output keyed on glyph
// markers (`===`, `━━━`, `#`, `➤`, `→`). If Mole's format drifts, these parsers
// silently return empty — these tests fail loudly instead.
//
// Fixtures live in Fixtures/ (see Fixtures/README.md for provenance).
final class MoOutputParserTests: XCTestCase {

    private func fixture(_ name: String, _ ext: String = "txt") throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            return try XCTUnwrap(nil, "fixture \(name).\(ext) not found in bundle")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Clean preview (=== sections + # size)

    func testCleanListParsesRealFixture() throws {
        let result = MoOutputParser.parseCleanList(text: try fixture("clean-list"))
        XCTAssertGreaterThanOrEqual(result.categories.count, 5,
            "Real clean-list.txt should yield several sized categories; got \(result.categories.count)")
        XCTAssertGreaterThan(result.totalFreed, 100_000_000,
            "Fixture has GB of caches; total should exceed 100MB")
        XCTAssertTrue(result.categories.contains { $0.name == "App caches" },
            "Expected an 'App caches' section in the fixture")
        // Sorted by size descending.
        let sizes = result.categories.map(\.size)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    func testCleanListPopulatesPerItemPaths() throws {
        let result = MoOutputParser.parseCleanList(text: try fixture("clean-list"))
        let appCaches = try XCTUnwrap(result.categories.first { $0.name == "App caches" },
            "Expected an 'App caches' section")
        XCTAssertGreaterThan(appCaches.items.count, 1,
            "Drill-down tree needs the individual paths under a section, not just a sum")
        // Item sizes must add up to the category total the header shows.
        let itemTotal = appCaches.items.reduce(UInt64(0)) { $0 + $1.size }
        XCTAssertEqual(itemTotal, appCaches.size,
            "Category size must equal the sum of its item sizes")
        // Items carry their real path and, when Mole reports it, an item count.
        XCTAssertTrue(appCaches.items.allSatisfy { $0.path.hasPrefix("/") },
            "Each item should keep its absolute path")
        XCTAssertTrue(appCaches.items.contains { $0.itemCount != nil },
            "At least one fixture line has an 'N items' count that should parse")
    }

    func testCleanListAttributesPathsAfterRepeatedHeader() {
        // A repeated section header must re-activate that section. The previous
        // `order.last` approach misfiled paths after the repeat into whatever
        // section was appended last (here, Beta).
        let text = """
        === Alpha ===
        /a  # 10MB
        === Beta ===
        /b  # 20MB
        === Alpha ===
        /a2  # 5MB
        """
        let result = MoOutputParser.parseCleanList(text: text)
        XCTAssertEqual(result.categories.first { $0.name == "Alpha" }?.items.count, 2,
            "Both /a and /a2 belong to Alpha")
        XCTAssertEqual(result.categories.first { $0.name == "Beta" }?.items.count, 1,
            "/a2 must not leak into Beta")
    }

    func testCleanListDropsEmptySections() throws {
        // The fixture has an empty '=== Cloud & Office ===' section.
        let result = MoOutputParser.parseCleanList(text: try fixture("clean-list"))
        XCTAssertFalse(result.categories.contains { $0.name == "Cloud & Office" },
            "Empty sections must not render as empty tree nodes")
    }

    func testCleanScanFindingCountsSizedAndWouldCleanLines() {
        // Sized findings tick the live "found N" counter…
        XCTAssertTrue(MoOutputParser.isCleanScanFinding("→ npm npx cache 3 items, 271.4MB dry"))
        // …and so do unsized "would clean" findings, so the counter doesn't
        // stall on "Starting scan…" when sized lines arrive late.
        XCTAssertTrue(MoOutputParser.isCleanScanFinding("→ pnpm cache · would clean"))
        // Decoration / headers do not.
        XCTAssertFalse(MoOutputParser.isCleanScanFinding("Scanning developer caches"))
    }

    func testCleanListDriftReturnsEmpty() throws {
        // Simulate Mole changing its section marker: the parser keys on `=== ... ===`.
        let drifted = try fixture("clean-list").replacingOccurrences(of: "===", with: "###")
        let result = MoOutputParser.parseCleanList(text: drifted)
        XCTAssertTrue(result.categories.isEmpty,
            "Marker drift must surface as empty results, which the app shows as 'nothing to clean' — this test exists to catch that silent failure")
    }

    // MARK: - Purge preview (━━━ sections + # size)

    func testPurgeParsesFixture() throws {
        let result = MoOutputParser.parsePurgeText(try fixture("purge"))
        XCTAssertEqual(result.projects.count, 3, "Node.js, Rust, Swift sections expected")
        XCTAssertGreaterThan(try XCTUnwrap(result.totalSize), 1_000_000_000, "Fixture totals >1GB")
        XCTAssertTrue(result.projects.contains { $0.type == "Node.js" })
        XCTAssertTrue(result.projects.contains { $0.type == "Rust/Cargo" })
    }

    func testPurgeDriftReturnsEmpty() throws {
        let drifted = try fixture("purge").replacingOccurrences(of: "━━━", with: "===")
        let result = MoOutputParser.parsePurgeText(drifted)
        XCTAssertTrue(result.projects.isEmpty, "Header drift must surface as empty results")
    }

    // MARK: - Size parsing

    func testParseByteSizeUnits() {
        XCTAssertEqual(MoOutputParser.parseByteSize("104KB"), 104 * 1024)
        XCTAssertEqual(MoOutputParser.parseByteSize("512MB"), 512 * 1024 * 1024)
        XCTAssertEqual(MoOutputParser.parseByteSize("1.2GB"), UInt64(1.2 * 1024 * 1024 * 1024))
        // First size in a comment like "1.19GB, 10 items" is what the parser uses.
        let gb = try? XCTUnwrap(MoOutputParser.parseByteSize("1.19GB, 10 items"))
        XCTAssertNotNil(gb)
        XCTAssertGreaterThan(gb!, 1_000_000_000)
        XCTAssertLessThan(gb!, 1_300_000_000)
        XCTAssertNil(MoOutputParser.parseByteSize("no size here"))
    }

    // MARK: - History totals

    func testHistoryTotalFreedBytesIgnoresDryRunSessions() {
        let result = HistoryResult(
            logs: HistoryLogs(operations: "", deletions: ""),
            limit: 10,
            sessions: [
                HistorySession(
                    command: "uninstall",
                    startedAt: "2026-06-03 21:33:08",
                    endedAt: "2026-06-03 21:33:10",
                    items: 1,
                    size: "12.30GB",
                    operationCount: 0,
                    actions: HistoryActions(removed: 0, trashed: 0, skipped: 0, failed: 0, rebuilt: 0, other: 0)
                ),
                HistorySession(
                    command: "uninstall",
                    startedAt: "2026-06-03 21:40:00",
                    endedAt: "2026-06-03 21:40:05",
                    items: 1,
                    size: "102KB",
                    operationCount: 1,
                    actions: HistoryActions(removed: 0, trashed: 1, skipped: 0, failed: 0, rebuilt: 0, other: 0)
                )
            ]
        )

        XCTAssertEqual(result.totalFreedBytes, MoOutputParser.parseHumanSize("102KB"))
    }

    // MARK: - Installer preview

    func testInstallerListParsesTUIRows() {
        let text = """
        \u{1B}[0;36m➤ ○ Arc-1.148.0-81146.dmg                     431.4MB | Downloads \u{1B}[0m
          ○ ClickUp Mac Installer.zip                   634KB | Downloads
        """
        let result = MoOutputParser.parseInstallerList(text: text)
        XCTAssertEqual(result.files.map(\.name), ["Arc-1.148.0-81146.dmg", "ClickUp Mac Installer.zip"])
        XCTAssertEqual(result.files.first?.size, MoOutputParser.parseByteSize("431.4MB"))
        XCTAssertEqual(result.files.first?.path, "~/Downloads/Arc-1.148.0-81146.dmg")
        XCTAssertEqual(result.totalSize, (MoOutputParser.parseByteSize("431.4MB") ?? 0) + (MoOutputParser.parseByteSize("634KB") ?? 0))
    }

    // MARK: - System-skip literal (cross-component dependency on clean.sh)

    func testSystemCleanupSkipMarkerLiteral() {
        // CleanView relies on this exact literal to offer admin escalation.
        XCTAssertEqual(MoOutputParser.systemCleanupSkipMarker,
                       "System-level cleanup skipped, requires sudo")
        XCTAssertTrue(MoOutputParser.detectsSystemCleanupSkip(
            in: "  ⚠ System-level cleanup skipped, requires sudo"))
        XCTAssertFalse(MoOutputParser.detectsSystemCleanupSkip(in: "Cleanup completed"))
    }

    // MARK: - StepStreamParser (optimize: ➤ steps + → details)

    func testStepStreamParserOnRealOptimize() throws {
        var parser = StepStreamParser()
        for line in try fixture("optimize").components(separatedBy: .newlines) {
            parser.consume(line)
        }
        parser.finish()
        XCTAssertEqual(parser.steps.count, 22,
            "Real optimize fixture has 22 ➤ step headers")
        XCTAssertFalse(parser.steps.contains { $0.state == .pending || $0.state == .running },
            "After finish, every step must have reached a terminal state")
    }

    func testStepStreamParserDetectsAdminSkip() {
        var parser = StepStreamParser()
        parser.consume("➤ System Maintenance")
        parser.consume("→ operation requires sudo")
        parser.finish()
        XCTAssertEqual(parser.steps.count, 1)
        XCTAssertEqual(parser.steps.first?.state, .skipped)
        XCTAssertEqual(parser.steps.first?.requiresAdmin, true)
    }

    // MARK: - Uninstall preview (Files to be removed / ◎ name,size / ✓ path / ➤ total)

    func testUninstallPreviewParsesRealFixture() throws {
        let preview = MoOutputParser.parseUninstallPreview(text: try fixture("uninstall-preview"))
        XCTAssertEqual(preview.apps.map(\.name), ["IINA", "Bruno"],
            "Two app groups in encounter order; the leading '◎ Matched 2 app(s):' summary must NOT become an app")
        let iina = try XCTUnwrap(preview.apps.first { $0.name == "IINA" })
        XCTAssertTrue(iina.paths.contains("/Applications/IINA.app"),
            "The bundle path must be among the items to remove")
        XCTAssertGreaterThan(iina.paths.count, 3,
            "Leftovers (caches, prefs, containers) must be captured, not just the bundle")
        XCTAssertTrue(iina.paths.contains { $0.hasPrefix("~/Library/") },
            "User-library leftovers are ~-relative in Mole's output and must be kept")
        // Grand total comes from the `➤ Remove N apps, <total>` line (707.3MB,
        // 1024-based), which is larger than the bundle-only list size — the
        // reason we parse the dry-run instead of summarizing the JSON list.
        XCTAssertEqual(preview.totalSize, MoOutputParser.parseByteSize("707.3MB"))
    }

    func testUninstallPreviewStripsControlSequencesAndNoise() {
        // Mirrors production: ANSI clear/cursor escapes and a scan-spinner line
        // are merged into the stream; the matched-summary precedes the section.
        let text = "\u{1B}[2J\u{1B}[H◎ Matched 1 app(s):\n"
            + "1. IINA  207.8MB  |  Last: 1w ago\n"
            + "\rScanning applications... 3/12\u{1B}[K\n"
            + "Files to be removed:\n\n"
            + "◎ IINA , 235.5MB\n"
            + "  ✓ /Applications/IINA.app\n"
            + "  ✓ ~/Library/Caches/com.colliderli.iina\n"
            + "➤ Remove 1 app, 235.5MB  Enter confirm, ESC cancel: \n"
        let preview = MoOutputParser.parseUninstallPreview(text: text)
        XCTAssertEqual(preview.apps.count, 1)
        XCTAssertEqual(preview.apps.first?.name, "IINA")
        XCTAssertEqual(preview.apps.first?.paths.count, 2)
        XCTAssertEqual(preview.totalSize, MoOutputParser.parseByteSize("235.5MB"))
    }

    func testUninstallPreviewDriftReturnsEmpty() throws {
        // If Mole stops printing the "Files to be removed:" gate, the parser
        // yields nothing — and finalizeUninstallPreview leaves the
        // preview-before-delete guard disarmed, so no delete can proceed.
        let drifted = try fixture("uninstall-preview")
            .replacingOccurrences(of: "Files to be removed:", with: "Items queued:")
        let preview = MoOutputParser.parseUninstallPreview(text: drifted)
        XCTAssertTrue(preview.isEmpty,
            "Gate-marker drift must surface as an empty preview so the guard stays disarmed")
    }

    func testUninstallPreviewToleratesMissingTerminator() {
        // If only the `➤ Remove …` total line drifts away, the app groups and
        // their leftover paths are still fully parsed — so the preview stays
        // valid (and the guard arms), with the total falling back to the sum of
        // the per-app header sizes. Deletion targets the right apps regardless;
        // only the displayed grand total is derived rather than read. This is
        // intentional: a missing total line must NOT silently drop apps/paths.
        let text = """
        Files to be removed:

        ◎ IINA , 235.5MB
          ✓ /Applications/IINA.app
          ✓ ~/Library/Caches/com.colliderli.iina
        ◎ Bruno , 471.7MB
          ✓ /Applications/Bruno.app
        """
        let preview = MoOutputParser.parseUninstallPreview(text: text)
        XCTAssertEqual(preview.apps.map(\.name), ["IINA", "Bruno"],
            "Missing terminator must not drop app groups")
        XCTAssertTrue(preview.apps.first?.paths.contains("/Applications/IINA.app") ?? false)
        XCTAssertFalse(preview.isEmpty, "Valid apps+paths must still arm the preview-before-delete guard")
        // Total falls back to the sum of the per-app (bundle+leftover) header sizes.
        let expected = (MoOutputParser.parseByteSize("235.5MB") ?? 0) + (MoOutputParser.parseByteSize("471.7MB") ?? 0)
        XCTAssertEqual(preview.totalSize, expected)
    }

    func testUninstallPreviewHandlesAppNamesWithSpaces() {
        let text = """
        Files to be removed:

        ◎ Google Chrome , 1.2GB
          ✓ /Applications/Google Chrome.app
          ✓ ~/Library/Application Support/Google/Chrome
        ➤ Remove 1 app, 1.2GB  Enter confirm, ESC cancel:
        """
        let preview = MoOutputParser.parseUninstallPreview(text: text)
        XCTAssertEqual(preview.apps.first?.name, "Google Chrome",
            "A space-comma-space header must not truncate multi-word app names")
        XCTAssertTrue(preview.apps.first?.paths.contains("/Applications/Google Chrome.app") ?? false)
    }
}
