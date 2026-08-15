import Foundation

public protocol PreferencesStoring: AnyObject {
    func load() throws -> [HotkeyBinding]
    func save(_ bindings: [HotkeyBinding]) throws
}

public enum PreferencesStoreError: Error, Equatable, LocalizedError {
    case corruptData(String)
    case unsupportedSchema(Int)
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .corruptData(let reason):
            return "Stored preferences could not be read: \(reason)"
        case .unsupportedSchema(let version):
            return "Stored preferences use unsupported schema version \(version)."
        case .encodingFailed(let reason):
            return "Preferences could not be saved: \(reason)"
        }
    }
}

public final class UserDefaultsPreferencesStore: PreferencesStoring {
    public static let storageKey = "hotkey.bindings.v1"

    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults = .standard, key: String = storageKey) {
        self.defaults = defaults
        self.key = key
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    public func load() throws -> [HotkeyBinding] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let stored = try decoder.decode(StoredPreferences.self, from: data)
            guard stored.schemaVersion == StoredPreferences.currentSchemaVersion else {
                throw PreferencesStoreError.unsupportedSchema(stored.schemaVersion)
            }
            return stored.bindings
        } catch let error as PreferencesStoreError {
            throw error
        } catch {
            throw PreferencesStoreError.corruptData(error.localizedDescription)
        }
    }

    public func save(_ bindings: [HotkeyBinding]) throws {
        do {
            let data = try encoder.encode(StoredPreferences(bindings: bindings))
            defaults.set(data, forKey: key)
        } catch {
            throw PreferencesStoreError.encodingFailed(error.localizedDescription)
        }
    }
}
