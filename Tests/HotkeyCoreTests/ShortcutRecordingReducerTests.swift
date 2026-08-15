import XCTest
@testable import HotkeyCore

final class ShortcutRecordingReducerTests: XCTestCase {
    func testModifierReleaseAfterValidKeyDownPreservesAcceptedShortcut() {
        var reducer = ShortcutRecordingReducer(keyCode: nil, modifiers: .option)

        reducer.reduce(.begin)
        reducer.reduce(.modifiersChanged([.command, .shift]))
        XCTAssertEqual(
            reducer.reduce(.keyDown(
                keyCode: 0,
                modifiers: [.command, .shift],
                isRepeat: false
            )),
            .accepted(.init(keyCode: 0, modifiers: [.command, .shift]))
        )
        reducer.reduce(.modifiersChanged([]))

        XCTAssertEqual(
            reducer.state.acceptedShortcut,
            .init(keyCode: 0, modifiers: [.command, .shift])
        )
        XCTAssertFalse(reducer.state.isRecording)
    }

    func testSaveAfterReleaseReceivesAcceptedKeyAndModifiers() {
        var reducer = ShortcutRecordingReducer(keyCode: nil, modifiers: .option)
        reducer.reduce(.begin)
        reducer.reduce(.keyDown(keyCode: 11, modifiers: .control, isRepeat: false))
        reducer.reduce(.modifiersChanged([]))

        let draftShortcut = reducer.state.acceptedShortcut

        XCTAssertEqual(draftShortcut?.keyCode, 11)
        XCTAssertEqual(draftShortcut?.modifiers, .control)
        XCTAssertTrue(reducer.state.canSave)
    }

    func testRepeatedKeyEventsAreIgnored() {
        var reducer = ShortcutRecordingReducer(keyCode: 1, modifiers: .option)
        reducer.reduce(.begin)
        let originalState = reducer.state

        XCTAssertEqual(
            reducer.reduce(.keyDown(keyCode: 2, modifiers: .command, isRepeat: true)),
            .none
        )
        XCTAssertEqual(reducer.state, originalState)
    }

    func testInvalidAttemptRetainsPreviousValidShortcutAndRecording() {
        let previous = RecordedShortcut(keyCode: 3, modifiers: .option)
        var reducer = ShortcutRecordingReducer(
            keyCode: previous.keyCode,
            modifiers: previous.modifiers
        )
        reducer.reduce(.begin)

        guard case .rejected(let message) = reducer.reduce(.keyDown(
            keyCode: 4,
            modifiers: .shift,
            isRepeat: false
        )) else {
            return XCTFail("Expected invalid chord to be rejected")
        }

        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(reducer.state.acceptedShortcut, previous)
        XCTAssertEqual(reducer.state.errorMessage, message)
        XCTAssertTrue(reducer.state.isRecording)
    }

    func testEscapeAndFocusLossRetainPreviousValue() {
        let previous = RecordedShortcut(keyCode: 5, modifiers: .command)

        var escapeReducer = ShortcutRecordingReducer(
            keyCode: previous.keyCode,
            modifiers: previous.modifiers
        )
        escapeReducer.reduce(.begin)
        XCTAssertEqual(escapeReducer.reduce(.cancel), .ended)
        XCTAssertEqual(escapeReducer.state.acceptedShortcut, previous)
        XCTAssertFalse(escapeReducer.state.isRecording)

        var focusReducer = ShortcutRecordingReducer(
            keyCode: previous.keyCode,
            modifiers: previous.modifiers
        )
        focusReducer.reduce(.begin)
        XCTAssertEqual(focusReducer.reduce(.focusLost), .ended)
        XCTAssertEqual(focusReducer.state.acceptedShortcut, previous)
        XCTAssertFalse(focusReducer.state.isRecording)
    }

    func testValidCaptureEndsRecordingAndMakesSaveReady() {
        var reducer = ShortcutRecordingReducer(keyCode: nil, modifiers: .option)
        reducer.reduce(.begin)

        XCTAssertEqual(
            reducer.reduce(.keyDown(keyCode: 6, modifiers: .command, isRepeat: false)),
            .accepted(.init(keyCode: 6, modifiers: .command))
        )
        XCTAssertFalse(reducer.state.isRecording)
        XCTAssertTrue(reducer.state.canSave)
        XCTAssertNil(reducer.state.errorMessage)
    }
}
