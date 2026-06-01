import XCTest
@testable import Drilbur

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
}
