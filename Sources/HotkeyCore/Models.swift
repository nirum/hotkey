import Foundation

public struct ShortcutModifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let control = ShortcutModifiers(rawValue: 1 << 2)
    public static let shift = ShortcutModifiers(rawValue: 1 << 3)

    public static let primary: ShortcutModifiers = [.command, .option, .control]
    public static let supported: ShortcutModifiers = [.command, .option, .control, .shift]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UInt8.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct AppTarget: Codable, Equatable, Hashable, Sendable {
    public var displayName: String
    public var bundleIdentifier: String?
    public var applicationURL: URL

    public init(displayName: String, bundleIdentifier: String?, applicationURL: URL) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL
    }
}

public struct HotkeyBinding: Codable, Equatable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var target: AppTarget
    public var keyCode: UInt32
    public var modifiers: ShortcutModifiers

    public init(
        id: UUID = UUID(),
        target: AppTarget,
        keyCode: UInt32,
        modifiers: ShortcutModifiers
    ) {
        self.id = id
        self.target = target
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct StoredPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var bindings: [HotkeyBinding]

    public init(schemaVersion: Int = Self.currentSchemaVersion, bindings: [HotkeyBinding]) {
        self.schemaVersion = schemaVersion
        self.bindings = bindings
    }
}
