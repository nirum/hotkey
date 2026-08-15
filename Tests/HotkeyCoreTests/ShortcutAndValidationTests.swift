import XCTest
@testable import HotkeyCore

final class ShortcutAndValidationTests: XCTestCase {
    func testEveryPrimaryModifierIsAccepted() {
        for modifiers: ShortcutModifiers in [.command, .option, .control] {
            XCTAssertEqual(
                ShortcutInterpreter.capture(keyCode: 0, modifiers: modifiers),
                .accepted(.init(keyCode: 0, modifiers: modifiers))
            )
        }
    }

    func testShiftCanSupplementPrimaryModifier() {
        XCTAssertEqual(
            ShortcutInterpreter.capture(keyCode: 11, modifiers: [.control, .shift]),
            .accepted(.init(keyCode: 11, modifiers: [.control, .shift]))
        )
    }

    func testShiftOnlyAndBareKeyAreRejected() {
        assertRejected(ShortcutInterpreter.capture(keyCode: 0, modifiers: .shift))
        assertRejected(ShortcutInterpreter.capture(keyCode: 0, modifiers: []))
    }

    func testModifierOnlyAndMissingKeyAreRejected() {
        assertRejected(ShortcutInterpreter.capture(
            keyCode: nil,
            modifiers: .command,
            isModifierOnly: true
        ))
        assertRejected(ShortcutInterpreter.capture(keyCode: nil, modifiers: .command))
    }

    func testUnsupportedModifierBitsAndKeyCodesAreRejected() {
        assertRejected(ShortcutInterpreter.capture(
            keyCode: 0,
            modifiers: ShortcutModifiers(rawValue: ShortcutModifiers.command.rawValue | 0x80)
        ))
        assertRejected(ShortcutInterpreter.capture(keyCode: 128, modifiers: .command))
    }

    func testShortcutDisplayUsesSymbolsAndHardwareKeyNames() {
        XCTAssertEqual(
            ShortcutDisplay.string(keyCode: 0, modifiers: [.control, .option, .shift, .command]),
            "⌃⌥⇧⌘A"
        )
        XCTAssertEqual(ShortcutDisplay.string(keyCode: 49, modifiers: .option), "⌥Space")
        XCTAssertEqual(ShortcutDisplay.keyName(for: 127), "Key 127")
    }

    func testValidatorAcceptsSupportedPrimaryModifierCombinations() {
        let bindings = [
            makeBinding(keyCode: 0, modifiers: .command),
            makeBinding(keyCode: 1, modifiers: .option),
            makeBinding(keyCode: 2, modifiers: .control),
            makeBinding(keyCode: 3, modifiers: [.command, .shift]),
        ]
        XCTAssertTrue(BindingValidator.validate(bindings).isEmpty)
    }

    func testValidatorReportsInvalidBitsShiftOnlyKeyAndApplication() {
        let unsupported = makeBinding(
            path: "/tmp/not-an-app",
            keyCode: 200,
            modifiers: ShortcutModifiers(rawValue: 0x80)
        )
        let codes = Set(BindingValidator.validate([unsupported]).map(\.code))
        XCTAssertEqual(codes, [
            .unsupportedModifiers,
            .missingPrimaryModifier,
            .unsupportedKey,
            .invalidApplication,
        ])
    }

    func testValidatorRejectsDuplicateKeyAndModifiers() {
        let first = makeBinding(keyCode: 12, modifiers: [.option, .shift])
        let second = makeBinding(
            name: "Other",
            bundleIdentifier: "com.example.other",
            path: "/Applications/Other.app",
            keyCode: 12,
            modifiers: [.option, .shift]
        )
        let failures = BindingValidator.validate([first, second])
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.bindingID, second.id)
        XCTAssertEqual(failures.first?.code, .duplicateShortcut)
    }

    func testRecorderAndBindingValidationShareShortcutRules() {
        let binding = makeBinding(keyCode: 0, modifiers: .shift)
        let modelFailure = BindingValidator.validate([binding]).first
        guard case .rejected(let recorderMessage) = ShortcutInterpreter.capture(
            keyCode: binding.keyCode,
            modifiers: binding.modifiers
        ) else {
            return XCTFail("Expected recorder rejection")
        }
        XCTAssertEqual(modelFailure?.message, recorderMessage)
    }

    private func assertRejected(
        _ result: ShortcutCaptureResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .rejected(let message) = result else {
            return XCTFail("Expected rejection", file: file, line: line)
        }
        XCTAssertFalse(message.isEmpty, file: file, line: line)
    }
}
