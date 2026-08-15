import XCTest
@testable import HotkeyCore

final class MenuShortcutEntryTests: XCTestCase {
    func testEmptyBindingsProduceNoEntries() {
        XCTAssertEqual(MenuShortcutEntryMapper.map([]), [])
    }

    func testPreferenceOrderAndPresentationArePreserved() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let bindings = [
            makeBinding(
                id: firstID,
                name: "Mail",
                bundleIdentifier: "com.apple.mail",
                path: "/System/Applications/Mail.app",
                keyCode: 0,
                modifiers: [.control, .option]
            ),
            makeBinding(
                id: secondID,
                name: "Notes",
                bundleIdentifier: "com.apple.Notes",
                path: "/System/Applications/Notes.app",
                keyCode: 49,
                modifiers: [.command, .shift]
            ),
        ]

        let entries = MenuShortcutEntryMapper.map(bindings)

        XCTAssertEqual(entries.map(\.id), [firstID, secondID])
        XCTAssertEqual(entries.map(\.displayName), ["Mail", "Notes"])
        XCTAssertEqual(entries.map(\.shortcutLabel), ["⌃⌥A", "⇧⌘Space"])
        XCTAssertEqual(entries.map(\.keyEquivalent), ["a", " "])
        XCTAssertEqual(entries.map(\.title), ["Mail", "Notes"])
        XCTAssertEqual(entries.first?.bundleIdentifier, "com.apple.mail")
        XCTAssertEqual(entries.first?.applicationURL.path, "/System/Applications/Mail.app")
    }

    func testUnknownLegacyKeyCodeUsesVisibleInlineFallback() {
        let entry = MenuShortcutEntryMapper.map([
            makeBinding(name: "Legacy", keyCode: 127, modifiers: .option),
        ]).first

        XCTAssertEqual(entry?.shortcutLabel, "⌥Key 127")
        XCTAssertNil(entry?.keyEquivalent)
        XCTAssertEqual(entry?.title, "Legacy  ⌥Key 127")
    }

    func testAppliedEditsAndDeletesChangeNextSnapshot() {
        let original = makeBinding(name: "Original", keyCode: 0, modifiers: .option)
        let store = FakePreferencesStore(stored: [original])
        let coordinator = RegistrationCoordinator(
            store: store,
            registrar: FakeRegistrar(),
            issueCenter: IssueCenter()
        )
        XCTAssertEqual(coordinator.start(), .applied)

        let edited = makeBinding(
            id: original.id,
            name: "Edited",
            keyCode: 1,
            modifiers: .command
        )
        XCTAssertEqual(coordinator.apply([edited]), .applied)
        XCTAssertEqual(
            MenuShortcutEntryMapper.map(coordinator.activeBindings).map(\.displayName),
            ["Edited"]
        )
        XCTAssertEqual(
            MenuShortcutEntryMapper.map(coordinator.activeBindings).map(\.shortcutLabel),
            ["⌘S"]
        )

        XCTAssertEqual(coordinator.apply([]), .applied)
        XCTAssertEqual(MenuShortcutEntryMapper.map(coordinator.activeBindings), [])
    }
}
