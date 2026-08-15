#if canImport(XCTest)
import Foundation
import XCTest
@testable import HotkeyCore

final class ApplicationTogglePolicyTests: XCTestCase {
    func testBundleIdentifierMatchPrecedesURLAndDisplayName() throws {
        let target = makeTarget()
        let nameMatch = app(pid: 1, name: "Example", id: "wrong.name", path: "/Other/Name.app")
        let urlMatch = app(pid: 2, name: "Other", id: "wrong.url", path: target.applicationURL.path)
        let identifierMatch = app(pid: 3, name: "Renamed", id: "com.example.app", path: "/Moved/Renamed.app")

        let match = try XCTUnwrap(ApplicationTogglePolicy.bestMatch(
            target: target,
            runningApplications: [nameMatch, urlMatch, identifierMatch]
        ))
        XCTAssertEqual(match.processIdentifier, 3)
    }

    func testCanonicalURLMatchPrecedesDisplayNameWithoutIdentifier() throws {
        let target = makeTarget(bundleIdentifier: nil, path: "/Applications/Folder/../Example.app")
        let nameMatch = app(pid: 1, name: "Example", id: nil, path: "/Other/Example.app")
        let urlMatch = app(pid: 2, name: "Renamed", id: nil, path: "/Applications/Example.app")

        let match = try XCTUnwrap(ApplicationTogglePolicy.bestMatch(
            target: target,
            runningApplications: [nameMatch, urlMatch]
        ))
        XCTAssertEqual(match.processIdentifier, 2)
    }

    func testDisplayNameIsFinalCompatibilityFallback() throws {
        let target = makeTarget(bundleIdentifier: nil)
        let match = try XCTUnwrap(ApplicationTogglePolicy.bestMatch(
            target: target,
            runningApplications: [app(pid: 4, name: "example", id: nil, path: "/Moved/App.app")]
        ))
        XCTAssertEqual(match.processIdentifier, 4)
    }

    func testActiveInstanceIsPreferredAmongIdentifierMatches() throws {
        let inactive = app(pid: 1, active: false)
        let active = app(pid: 2, path: "/Applications/Example Copy.app", active: true)
        let match = try XCTUnwrap(ApplicationTogglePolicy.bestMatch(
            target: makeTarget(),
            runningApplications: [inactive, active]
        ))
        XCTAssertEqual(match.processIdentifier, 2)
    }

    func testActiveVisibleAppIsHiddenAndBackgroundVisibleAppIsActivated() {
        let active = app(pid: 10, active: true)
        XCTAssertEqual(decide(running: [active], visible: [10]), .hide(processIdentifier: 10))

        let background = app(pid: 11, active: false)
        XCTAssertEqual(decide(running: [background], visible: [11]), .activate(processIdentifier: 11))
    }

    func testRunningAppWithoutWindowsReopensResolvedLaunchServicesURL() {
        let resolved = URL(fileURLWithPath: "/Resolved/Example.app")
        XCTAssertEqual(
            decide(running: [app(pid: 5)], visible: [], resolved: resolved),
            .reopen(resolved)
        )
    }

    func testMovedNonRunningAppUsesResolvedBundleIdentifierURL() {
        let resolved = URL(fileURLWithPath: "/Moved/Example.app")
        XCTAssertEqual(decide(running: [], resolved: resolved), .reopen(resolved))
    }

    func testIdentifierlessAppUsesValidStoredURL() {
        let target = makeTarget(bundleIdentifier: nil)
        XCTAssertEqual(
            ApplicationTogglePolicy.decide(
                target: target,
                runningApplications: [],
                visibleWindowProcessIDs: [],
                resolvedBundleURL: nil,
                storedURLExists: true
            ),
            .reopen(target.applicationURL)
        )
    }

    func testMissingAppIsUnavailable() {
        XCTAssertEqual(decide(running: [], storedExists: false), .unavailable)
    }

    private func decide(
        running: [RunningApplicationSnapshot],
        visible: Set<Int32> = [],
        resolved: URL? = nil,
        storedExists: Bool = true
    ) -> ApplicationToggleAction {
        ApplicationTogglePolicy.decide(
            target: makeTarget(),
            runningApplications: running,
            visibleWindowProcessIDs: visible,
            resolvedBundleURL: resolved,
            storedURLExists: storedExists
        )
    }

    private func app(
        pid: Int32,
        name: String = "Example",
        id: String? = "com.example.app",
        path: String = "/Applications/Example.app",
        active: Bool = false
    ) -> RunningApplicationSnapshot {
        RunningApplicationSnapshot(
            processIdentifier: pid,
            displayName: name,
            bundleIdentifier: id,
            bundleURL: URL(fileURLWithPath: path),
            isActive: active
        )
    }
}
#endif
