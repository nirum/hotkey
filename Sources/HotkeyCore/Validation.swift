import Foundation

public enum BindingValidationCode: String, Equatable, Sendable {
    case missingKey
    case missingPrimaryModifier
    case unsupportedModifiers
    case unsupportedKey
    case duplicateShortcut
    case invalidApplication
}

public struct ShortcutRuleViolation: Equatable, Sendable {
    public let code: BindingValidationCode
    public let message: String

    public init(code: BindingValidationCode, message: String) {
        self.code = code
        self.message = message
    }
}

public enum ShortcutRules {
    public static func validate(
        keyCode: UInt32?,
        modifiers: ShortcutModifiers,
        isModifierOnly: Bool = false
    ) -> [ShortcutRuleViolation] {
        var violations: [ShortcutRuleViolation] = []
        if isModifierOnly || keyCode == nil {
            violations.append(.init(
                code: .missingKey,
                message: "Press a key together with Command, Option, or Control."
            ))
        }
        if !modifiers.subtracting(.supported).isEmpty {
            violations.append(.init(
                code: .unsupportedModifiers,
                message: "This shortcut contains unsupported modifier keys."
            ))
        }
        if modifiers.intersection(.primary).isEmpty {
            violations.append(.init(
                code: .missingPrimaryModifier,
                message: "Add Command, Option, or Control. Shift cannot be used alone."
            ))
        }
        if let keyCode, keyCode > 127 {
            violations.append(.init(
                code: .unsupportedKey,
                message: "Choose a supported keyboard key."
            ))
        }
        return violations
    }
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
            for violation in ShortcutRules.validate(
                keyCode: binding.keyCode,
                modifiers: binding.modifiers
            ) {
                failures.append(.init(
                    bindingID: binding.id,
                    code: violation.code,
                    message: violation.message
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
