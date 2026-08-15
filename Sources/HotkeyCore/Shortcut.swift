import Foundation

public struct RecordedShortcut: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum ShortcutCaptureResult: Equatable, Sendable {
    case accepted(RecordedShortcut)
    case rejected(String)
}

public enum ShortcutInterpreter {
    public static func capture(
        keyCode: UInt32?,
        modifiers: ShortcutModifiers,
        isModifierOnly: Bool = false
    ) -> ShortcutCaptureResult {
        if let violation = ShortcutRules.validate(
            keyCode: keyCode,
            modifiers: modifiers,
            isModifierOnly: isModifierOnly
        ).first {
            return .rejected(violation.message)
        }
        guard let keyCode else { return .rejected("Choose a supported keyboard key.") }
        return .accepted(RecordedShortcut(keyCode: keyCode, modifiers: modifiers))
    }
}

public enum ShortcutDisplay {
    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 49: "Space", 50: "`", 36: "Return",
        48: "Tab", 51: "Delete", 53: "Escape", 71: "Clear", 76: "Enter",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 115: "Home", 116: "Page Up", 117: "Forward Delete",
        118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func keyName(for keyCode: UInt32) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    public static func string(keyCode: UInt32, modifiers: ShortcutModifiers) -> String {
        modifierString(modifiers) + keyName(for: keyCode)
    }

    package static func modifierString(_ modifiers: ShortcutModifiers) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }
}
