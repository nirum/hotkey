import Carbon

enum KeyMapping {
    private static let keyCodes: [String: UInt32] = [
        // Letters
        "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),

        // Numbers
        "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9),

        // Special keys
        "space": UInt32(kVK_Space),
        "return": UInt32(kVK_Return), "enter": UInt32(kVK_Return),
        "tab": UInt32(kVK_Tab),
        "escape": UInt32(kVK_Escape), "esc": UInt32(kVK_Escape),
        "delete": UInt32(kVK_Delete), "backspace": UInt32(kVK_Delete),
        "forwarddelete": UInt32(kVK_ForwardDelete),

        // Arrow keys
        "up": UInt32(kVK_UpArrow), "uparrow": UInt32(kVK_UpArrow),
        "down": UInt32(kVK_DownArrow), "downarrow": UInt32(kVK_DownArrow),
        "left": UInt32(kVK_LeftArrow), "leftarrow": UInt32(kVK_LeftArrow),
        "right": UInt32(kVK_RightArrow), "rightarrow": UInt32(kVK_RightArrow),

        // Navigation
        "home": UInt32(kVK_Home), "end": UInt32(kVK_End),
        "pageup": UInt32(kVK_PageUp), "pagedown": UInt32(kVK_PageDown),

        // Function keys
        "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3),
        "f4": UInt32(kVK_F4), "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6),
        "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8), "f9": UInt32(kVK_F9),
        "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
        "f13": UInt32(kVK_F13), "f14": UInt32(kVK_F14), "f15": UInt32(kVK_F15),
        "f16": UInt32(kVK_F16), "f17": UInt32(kVK_F17), "f18": UInt32(kVK_F18),
        "f19": UInt32(kVK_F19), "f20": UInt32(kVK_F20),

        // Punctuation
        "period": UInt32(kVK_ANSI_Period), ".": UInt32(kVK_ANSI_Period),
        "comma": UInt32(kVK_ANSI_Comma), ",": UInt32(kVK_ANSI_Comma),
        "slash": UInt32(kVK_ANSI_Slash), "/": UInt32(kVK_ANSI_Slash),
        "backslash": UInt32(kVK_ANSI_Backslash), "\\": UInt32(kVK_ANSI_Backslash),
        "semicolon": UInt32(kVK_ANSI_Semicolon), ";": UInt32(kVK_ANSI_Semicolon),
        "quote": UInt32(kVK_ANSI_Quote), "'": UInt32(kVK_ANSI_Quote),
        "equal": UInt32(kVK_ANSI_Equal), "=": UInt32(kVK_ANSI_Equal),
        "minus": UInt32(kVK_ANSI_Minus), "-": UInt32(kVK_ANSI_Minus),
        "leftbracket": UInt32(kVK_ANSI_LeftBracket), "[": UInt32(kVK_ANSI_LeftBracket),
        "rightbracket": UInt32(kVK_ANSI_RightBracket), "]": UInt32(kVK_ANSI_RightBracket),
        "grave": UInt32(kVK_ANSI_Grave), "`": UInt32(kVK_ANSI_Grave),
    ]

    private static let modifierFlags: [String: UInt32] = [
        "command": UInt32(cmdKey),
        "cmd": UInt32(cmdKey),
        "option": UInt32(optionKey),
        "alt": UInt32(optionKey),
        "control": UInt32(controlKey),
        "ctrl": UInt32(controlKey),
        "shift": UInt32(shiftKey),
    ]

    static func carbonKeyCode(for keyName: String) -> UInt32? {
        let key = keyName.lowercased()
        guard let code = keyCodes[key] else {
            NSLog("Hotkey: Unknown key name '%@'", keyName)
            return nil
        }
        return code
    }

    static func carbonModifiers(for modifierNames: [String]) -> UInt32 {
        var flags: UInt32 = 0
        for name in modifierNames {
            let key = name.lowercased()
            if let flag = modifierFlags[key] {
                flags |= flag
            } else {
                NSLog("Hotkey: Unknown modifier '%@'", name)
            }
        }
        return flags
    }
}
