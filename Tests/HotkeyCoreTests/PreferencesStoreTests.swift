import Foundation
import XCTest
@testable import HotkeyCore

final class PreferencesStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "HotkeyCoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMissingPreferencesLoadAsEmpty() throws {
        let store = UserDefaultsPreferencesStore(defaults: defaults)
        XCTAssertEqual(try store.load(), [])
    }

    func testRoundTripPreservesEveryBindingFieldAndSchema() throws {
        let binding = makeBinding(modifiers: [.command, .shift])
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        try store.save([binding])

        XCTAssertEqual(try store.load(), [binding])
        let data = try XCTUnwrap(defaults.data(forKey: UserDefaultsPreferencesStore.storageKey))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, StoredPreferences.currentSchemaVersion)
    }

    func testUnsupportedSchemaIsRejected() throws {
        let data = try JSONEncoder().encode(StoredPreferences(schemaVersion: 99, bindings: []))
        defaults.set(data, forKey: UserDefaultsPreferencesStore.storageKey)
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? PreferencesStoreError, .unsupportedSchema(99))
        }
    }

    func testCorruptDataIsReported() {
        defaults.set(Data("not-json".utf8), forKey: UserDefaultsPreferencesStore.storageKey)
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        XCTAssertThrowsError(try store.load()) { error in
            guard let storeError = error as? PreferencesStoreError,
                  case .corruptData = storeError else {
                return XCTFail("Expected corruptData, got \(error)")
            }
        }
    }

    func testMissingKeyCodeIsCorruptData() throws {
        let json = """
        {"schemaVersion":1,"bindings":[{"id":"00000000-0000-0000-0000-000000000001","target":{"displayName":"Example","applicationURL":"file:///Applications/Example.app"},"modifiers":2}]}
        """
        defaults.set(Data(json.utf8), forKey: UserDefaultsPreferencesStore.storageKey)

        XCTAssertThrowsError(try UserDefaultsPreferencesStore(defaults: defaults).load()) { error in
            guard let storeError = error as? PreferencesStoreError,
                  case .corruptData = storeError else {
                return XCTFail("Expected corruptData, got \(error)")
            }
        }
    }

    func testStoreUsesInjectedDefaultsOnly() throws {
        let binding = makeBinding()
        let key = "test.\(UUID().uuidString)"
        let store = UserDefaultsPreferencesStore(defaults: defaults, key: key)

        try store.save([binding])

        XCTAssertNotNil(defaults.data(forKey: key))
        XCTAssertNil(UserDefaults.standard.data(forKey: key))
    }
}
