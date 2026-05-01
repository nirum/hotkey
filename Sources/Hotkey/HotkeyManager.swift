import Carbon
import AppKit

private func carbonEventHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard err == noErr else { return err }

    if let appName = HotkeyManager.hotkeyMap[hotKeyID.id] {
        HotkeyManager.shared?.onHotkey?(appName)
    }

    return noErr
}

class HotkeyManager {
    static weak var shared: HotkeyManager?
    static var hotkeyMap: [UInt32: String] = [:]

    var onHotkey: ((String) -> Void)?

    private var registeredHotkeys: [(id: UInt32, ref: EventHotKeyRef)] = []
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    init() {
        HotkeyManager.shared = self
        installEventHandler()
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            carbonEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
    }

    func registerAll(_ entries: [HotkeyEntry]) {
        for entry in entries {
            guard let keyCode = KeyMapping.carbonKeyCode(for: entry.key) else {
                NSLog("Hotkey: Skipping hotkey for '%@' — unknown key '%@'", entry.app, entry.key)
                continue
            }

            let modifiers = KeyMapping.carbonModifiers(for: entry.modifiers)
            let id = nextID
            nextID += 1

            let hotKeyID = EventHotKeyID(
                signature: fourCharCode("HKEY"),
                id: id
            )

            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &ref
            )

            if status == noErr, let ref = ref {
                HotkeyManager.hotkeyMap[id] = entry.app
                registeredHotkeys.append((id: id, ref: ref))
                let modStr = entry.modifiers.joined(separator: "+")
                NSLog("Hotkey: Registered %@+%@ → %@", modStr, entry.key, entry.app)
            } else {
                NSLog("Hotkey: Failed to register %@ (status %d)", entry.app, status)
            }
        }
    }

    func unregisterAll() {
        for (id, ref) in registeredHotkeys {
            UnregisterEventHotKey(ref)
            HotkeyManager.hotkeyMap.removeValue(forKey: id)
        }
        registeredHotkeys.removeAll()
        nextID = 1
    }

    deinit {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}
