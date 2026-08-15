import AppKit
import Carbon
import HotkeyCore

private func carbonEventHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    CarbonHotkeyRegistrar.shared?.handle(id: hotKeyID.id)
    return noErr
}

final class CarbonHotkeyRegistrar: HotkeyRegistering {
    static weak var shared: CarbonHotkeyRegistrar?

    var onHotkey: ((HotkeyBinding) -> Void)?

    private var registered: [UInt32: (reference: EventHotKeyRef, binding: HotkeyBinding)] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    init() {
        Self.shared = self
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

    func register(_ binding: HotkeyBinding) -> Result<RegistrationToken, RegistrationFailure> {
        let id = nextID
        nextID &+= 1
        if nextID == 0 { nextID = 1 }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("HKEY"), id: id)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            carbonModifiers(binding.modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            return .failure(.init(
                bindingID: binding.id,
                reason: "The shortcut may be reserved or in use by another application (status \(status)).",
                status: status
            ))
        }
        registered[id] = (reference, binding)
        return .success(.init(rawValue: id))
    }

    func unregister(
        _ token: RegistrationToken,
        binding: HotkeyBinding
    ) -> Result<Void, RegistrationFailure> {
        guard let item = registered[token.rawValue] else { return .success(()) }
        let status = UnregisterEventHotKey(item.reference)
        guard status == noErr else {
            return .failure(.init(
                bindingID: binding.id,
                reason: "macOS returned status \(status) while unregistering.",
                status: status
            ))
        }
        registered.removeValue(forKey: token.rawValue)
        return .success(())
    }

    func handle(id: UInt32) {
        guard let binding = registered[id]?.binding else { return }
        onHotkey?(binding)
    }

    deinit {
        for item in registered.values {
            UnregisterEventHotKey(item.reference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func carbonModifiers(_ modifiers: ShortcutModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
}
