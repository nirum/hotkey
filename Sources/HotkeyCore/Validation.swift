import Foundation

public enum BindingValidationCode: String, Equatable, Sendable {
    case missingPrimaryModifier
    case unsupportedModifiers
    case unsupportedKey
    case duplicateShortcut
    case invalidApplication
}

public struct BindingValidationFailure: Error, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let bindingID: UUID
    public let code: BindingValidationCode
    public let message: String

    public init(
        id: UUID = UUID(),
        bindingID: UUID,
        code: BindingValidationCode,
        message: String
    ) {
        self.id = id
        self.bindingID = bindingID
        self.code = code
        self.message = message
    }
}

public enum BindingValidator {
    public static func validate(_ bindings: [HotkeyBinding]) -> [BindingValidationFailure] {
        var failures: [BindingValidationFailure] = []
        var shortcutOwners: [ShortcutIdentity: UUID] = [:]

        for binding in bindings {
            if !binding.modifiers.subtracting(.supported).isEmpty {
                failures.append(.init(
                    bindingID: binding.id,
                    code: .unsupportedModifiers,
                    message: "Remove unsupported modifier keys."
                ))
            }
            if binding.modifiers.intersection(.primary).isEmpty {
                failures.append(.init(
                    bindingID: binding.id,
                    code: .missingPrimaryModifier,
                    message: "Add Command, Option, or Control. Shift cannot be used alone."
                ))
            }
            if binding.keyCode > 127 {
                failures.append(.init(
                    bindingID: binding.id,
                    code: .unsupportedKey,
                    message: "Choose a supported keyboard key."
                ))
            }
            if binding.target.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || binding.target.applicationURL.pathExtension.lowercased() != "app" {
                failures.append(.init(
                    bindingID: binding.id,
                    code: .invalidApplication,
                    message: "Choose a macOS application bundle (.app)."
                ))
            }

            let identity = ShortcutIdentity(
                keyCode: binding.keyCode,
                modifiers: binding.modifiers.rawValue
            )
            if shortcutOwners[identity] != nil {
                failures.append(.init(
                    bindingID: binding.id,
                    code: .duplicateShortcut,
                    message: "This shortcut is already assigned to another application."
                ))
            } else {
                shortcutOwners[identity] = binding.id
            }
        }
        return failures
    }

    private struct ShortcutIdentity: Hashable {
        let keyCode: UInt32
        let modifiers: UInt8
    }
}
