#if canImport(XCTest)
import Foundation
import XCTest
@testable import HotkeyCore

final class IssueCenterTests: XCTestCase {
    func testReportDeduplicatesEquivalentCurrentIssue() {
        let bindingID = UUID()
        let center = IssueCenter()
        center.report(.init(
            kind: .validation,
            bindingID: bindingID,
            reason: "Duplicate",
            suggestion: "Change it"
        ))
        center.report(.init(
            kind: .validation,
            bindingID: bindingID,
            reason: "Duplicate",
            suggestion: "Change it"
        ))

        XCTAssertEqual(center.issues.count, 1)
    }

    func testClearCanResolveOneBindingAndKind() {
        let firstID = UUID()
        let secondID = UUID()
        let center = IssueCenter(issues: [
            .init(kind: .validation, bindingID: firstID, reason: "first", suggestion: "fix"),
            .init(kind: .registration, bindingID: firstID, reason: "other", suggestion: "fix"),
            .init(kind: .validation, bindingID: secondID, reason: "second", suggestion: "fix"),
        ])

        center.clear(kind: .validation, bindingID: firstID)

        XCTAssertEqual(center.issues.count, 2)
        XCTAssertFalse(center.issues.contains { $0.kind == .validation && $0.bindingID == firstID })
    }

    func testClearAllRemovesWarningState() {
        let center = IssueCenter(issues: [
            .init(kind: .preferences, reason: "corrupt", suggestion: "save")
        ])
        center.clearAll()
        XCTAssertTrue(center.issues.isEmpty)
    }
}
#endif
