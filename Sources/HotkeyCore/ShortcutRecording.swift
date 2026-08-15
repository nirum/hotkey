import Foundation

package enum ShortcutRecordingEvent: Equatable, Sendable {
    case begin
    case keyDown(keyCode: UInt32, modifiers: ShortcutModifiers, isRepeat: Bool)
    case modifiersChanged(ShortcutModifiers)
    case cancel
    case focusLost
}

package enum ShortcutRecordingEffect: Equatable, Sendable {
    case none
    case accepted(RecordedShortcut)
    case rejected(String)
    case ended
}

package struct ShortcutRecordingState: Equatable, Sendable {
    package fileprivate(set) var acceptedShortcut: RecordedShortcut?
    package fileprivate(set) var transientModifiers: ShortcutModifiers
    package fileprivate(set) var errorMessage: String?
    package fileprivate(set) var isRecording: Bool

    package var canSave: Bool {
        !isRecording && acceptedShortcut != nil
    }
}

package struct ShortcutRecordingReducer: Sendable {
    package private(set) var state: ShortcutRecordingState

    package init(keyCode: UInt32?, modifiers: ShortcutModifiers) {
        state = ShortcutRecordingState(
            acceptedShortcut: keyCode.map {
                RecordedShortcut(keyCode: $0, modifiers: modifiers)
            },
            transientModifiers: [],
            errorMessage: nil,
            isRecording: false
        )
    }

    package mutating func synchronize(
        keyCode: UInt32?,
        modifiers: ShortcutModifiers
    ) {
        guard !state.isRecording else { return }
        state.acceptedShortcut = keyCode.map {
            RecordedShortcut(keyCode: $0, modifiers: modifiers)
        }
        state.transientModifiers = []
        state.errorMessage = nil
    }

    @discardableResult
    package mutating func reduce(_ event: ShortcutRecordingEvent) -> ShortcutRecordingEffect {
        switch event {
        case .begin:
            state.isRecording = true
            state.transientModifiers = []
            state.errorMessage = nil
            return .none

        case .modifiersChanged(let modifiers):
            guard state.isRecording else { return .none }
            state.transientModifiers = modifiers
            return .none

        case .keyDown(let keyCode, let modifiers, let isRepeat):
            guard state.isRecording, !isRepeat else { return .none }
            state.transientModifiers = modifiers
            switch ShortcutInterpreter.capture(keyCode: keyCode, modifiers: modifiers) {
            case .accepted(let shortcut):
                state.acceptedShortcut = shortcut
                state.errorMessage = nil
                state.isRecording = false
                return .accepted(shortcut)
            case .rejected(let message):
                state.errorMessage = message
                return .rejected(message)
            }

        case .cancel, .focusLost:
            guard state.isRecording else { return .none }
            state.isRecording = false
            state.transientModifiers = []
            state.errorMessage = nil
            return .ended
        }
    }
}
