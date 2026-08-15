import Foundation

package struct MenuShortcutEntry: Equatable, Sendable {
    package let id: UUID
    package let displayName: String
    package let bundleIdentifier: String?
    package let applicationURL: URL
    package let shortcutLabel: String
    package let keyEquivalent: String?
    package let modifiers: ShortcutModifiers

    package var title: String {
        guard keyEquivalent == nil else { return displayName }
        return "\(displayName)  \(shortcutLabel)"
    }
}

package enum MenuShortcutEntryMapper {
    package static func map(_ bindings: [HotkeyBinding]) -> [MenuShortcutEntry] {
        bindings.map { binding in
            MenuShortcutEntry(
                id: binding.id,
                displayName: binding.target.displayName,
                bundleIdentifier: binding.target.bundleIdentifier,
                applicationURL: binding.target.applicationURL,
                shortcutLabel: ShortcutDisplay.string(
                    keyCode: binding.keyCode,
                    modifiers: binding.modifiers
                ),
                keyEquivalent: keyEquivalents[binding.keyCode],
                modifiers: binding.modifiers
            )
        }
    }

    private static let keyEquivalents: [UInt32: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
        38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "n", 46: "m", 47: ".", 49: " ", 50: "`", 36: "\r",
        48: "\t", 51: "\u{8}", 53: "\u{1b}", 71: "\u{f739}", 76: "\u{3}",
        96: "\u{f708}", 97: "\u{f709}", 98: "\u{f70a}", 99: "\u{f706}",
        100: "\u{f70b}", 101: "\u{f70c}", 103: "\u{f70e}", 105: "\u{f710}",
        106: "\u{f713}", 107: "\u{f711}", 109: "\u{f70d}", 111: "\u{f70f}",
        113: "\u{f712}", 115: "\u{f729}", 116: "\u{f72c}", 117: "\u{f728}",
        118: "\u{f707}", 119: "\u{f72b}", 120: "\u{f705}", 121: "\u{f72d}",
        122: "\u{f704}", 123: "\u{f702}", 124: "\u{f703}", 125: "\u{f701}",
        126: "\u{f700}",
    ]
}
