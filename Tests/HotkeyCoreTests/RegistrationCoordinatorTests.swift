#if canImport(XCTest)
import Foundation
import XCTest
@testable import HotkeyCore

final class RegistrationCoordinatorTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    func testStartWithEmptyPreferencesHasEmptyActiveState() {
        let store = FakePreferencesStore()
        let registrar = FakeRegistrar()
        let coordinator = makeCoordinator(store: store, registrar: registrar)

        XCTAssertEqual(coordinator.start(), .applied)
        XCTAssertEqual(coordinator.activeBindings, [])
        XCTAssertEqual(registrar.registerCalls, [])
    }

    func testStartRegistersStoredPreferences() {
        let binding = makeBinding()
        let store = FakePreferencesStore(stored: [binding])
        let registrar = FakeRegistrar()
        let coordinator = makeCoordinator(store: store, registrar: registrar)

        XCTAssertEqual(coordinator.start(), .applied)
        XCTAssertEqual(coordinator.activeBindings, [binding])
        XCTAssertEqual(registrar.registerCalls, [binding])
    }

    func testAddEditDeleteAndRestart() {
        let store = FakePreferencesStore()
        let registrar = FakeRegistrar()
        let coordinator = makeCoordinator(store: store, registrar: registrar)
        XCTAssertEqual(coordinator.start(), .applied)

        let added = makeBinding(keyCode: 0)
        XCTAssertEqual(coordinator.apply([added]), .applied)
        XCTAssertEqual(store.stored, [added])

        var edited = added
        edited.keyCode = 11
        edited.modifiers = [.command, .shift]
        XCTAssertEqual(coordinator.apply([edited]), .applied)
        XCTAssertEqual(store.stored, [edited])

        let restartedRegistrar = FakeRegistrar()
        let restarted = makeCoordinator(store: store, registrar: restartedRegistrar)
        XCTAssertEqual(restarted.start(), .applied)
        XCTAssertEqual(restarted.activeBindings, [edited])

        XCTAssertEqual(restarted.apply([]), .applied)
        XCTAssertEqual(store.stored, [])
        XCTAssertEqual(restarted.activeBindings, [])
    }

    func testValidationFailureDoesNotUnregisterOrSave() {
        let original = makeBinding(keyCode: 0)
        let store = FakePreferencesStore(stored: [original])
        let registrar = FakeRegistrar()
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)
        let unregisterCount = registrar.unregisterCalls.count

        let duplicate = makeBinding(
            name: "Other",
            bundleIdentifier: "com.example.other",
            path: "/Applications/Other.app",
            keyCode: original.keyCode,
            modifiers: original.modifiers
        )
        XCTAssertEqual(coordinator.apply([original, duplicate]), .rejected)

        XCTAssertEqual(coordinator.activeBindings, [original])
        XCTAssertEqual(store.stored, [original])
        XCTAssertEqual(store.saveCalls.count, 0)
        XCTAssertEqual(registrar.unregisterCalls.count, unregisterCount)
        XCTAssertEqual(issues.issues.first?.kind, .validation)
        XCTAssertEqual(issues.issues.first?.bindingID, duplicate.id)
    }

    func testRegistrationFailureRemovesPartialSetAndRestoresOldSet() {
        let old = makeBinding(keyCode: 0)
        let first = makeBinding(
            name: "First",
            bundleIdentifier: "com.example.first",
            path: "/Applications/First.app",
            keyCode: 1
        )
        let failing = makeBinding(
            name: "Failing",
            bundleIdentifier: "com.example.failing",
            path: "/Applications/Failing.app",
            keyCode: 2
        )
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        registrar.registerFailure = { binding, _ in
            binding.id == failing.id ? registrationFailure(binding) : nil
        }
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)

        XCTAssertEqual(coordinator.apply([first, failing]), .rejected)

        XCTAssertEqual(coordinator.activeBindings, [old])
        XCTAssertEqual(store.stored, [old])
        XCTAssertTrue(store.saveCalls.isEmpty)
        XCTAssertEqual(Set(registrar.active.values), [old])
        XCTAssertTrue(registrar.unregisterCalls.contains(first))
        XCTAssertEqual(issues.issues.first?.kind, .registration)
        XCTAssertEqual(issues.issues.first?.bindingID, failing.id)
    }

    func testPersistenceFailureRollsBackRegistrationsAndStoredState() {
        let old = makeBinding(keyCode: 0)
        let proposed = makeBinding(keyCode: 1)
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)
        store.saveError = TestFailure.save

        XCTAssertEqual(coordinator.apply([proposed]), .rejected)

        XCTAssertEqual(coordinator.activeBindings, [old])
        XCTAssertEqual(store.stored, [old])
        XCTAssertEqual(Set(registrar.active.values), [old])
        XCTAssertTrue(issues.issues.contains { $0.kind == .preferences })
    }

    func testRollbackRegistrationFailureIsReportedDistinctly() {
        let old = makeBinding(keyCode: 0)
        let failing = makeBinding(keyCode: 1)
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        registrar.registerFailure = { binding, attempt in
            if binding.id == failing.id { return registrationFailure(binding) }
            if binding.id == old.id && attempt == 2 {
                return registrationFailure(binding, "restore failed")
            }
            return nil
        }
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)

        XCTAssertEqual(coordinator.apply([failing]), .rollbackFailed)
        XCTAssertEqual(coordinator.activeBindings, [old])
        XCTAssertTrue(issues.issues.contains { $0.kind == .rollback })
        XCTAssertTrue(issues.issues.contains { $0.reason.contains("restore") })
    }

    func testPartialRegistrationCleanupFailureIsRollbackFailure() {
        let old = makeBinding(keyCode: 0)
        let partial = makeBinding(keyCode: 1)
        let failing = makeBinding(keyCode: 2)
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        registrar.registerFailure = { binding, _ in
            binding.id == failing.id ? registrationFailure(binding) : nil
        }
        registrar.unregisterFailure = { binding, _ in
            binding.id == partial.id ? registrationFailure(binding, "cleanup failed") : nil
        }
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)

        XCTAssertEqual(coordinator.apply([partial, failing]), .rollbackFailed)
        XCTAssertEqual(coordinator.activeBindings, [old])
        XCTAssertEqual(store.stored, [old])
        XCTAssertTrue(issues.issues.contains {
            $0.kind == .rollback && $0.reason.contains("partially registered")
        })
    }

    func testTemporaryUnregisterFailureRestoresKnownGoodSet() {
        let first = makeBinding(keyCode: 0)
        let second = makeBinding(keyCode: 1)
        let proposed = makeBinding(keyCode: 2)
        let store = FakePreferencesStore(stored: [first, second])
        let registrar = FakeRegistrar()
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)
        registrar.unregisterFailure = { binding, _ in
            binding.id == second.id ? registrationFailure(binding, "unregister failed") : nil
        }

        XCTAssertEqual(coordinator.apply([proposed]), .rejected)
        XCTAssertEqual(coordinator.activeBindings, [first, second])
        XCTAssertEqual(store.stored, [first, second])
        XCTAssertEqual(Set(registrar.active.values), Set([first, second]))
        XCTAssertTrue(issues.issues.contains { $0.kind == .registration })
    }

    func testCorruptReloadKeepsLastValidInMemoryBindings() {
        let original = makeBinding()
        let store = FakePreferencesStore(stored: [original])
        let registrar = FakeRegistrar()
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)
        XCTAssertEqual(coordinator.start(), .applied)
        store.loadError = TestFailure.load

        XCTAssertEqual(coordinator.reload(), .rejected)
        XCTAssertEqual(coordinator.activeBindings, [original])
        XCTAssertEqual(Set(registrar.active.values), [original])
        XCTAssertEqual(issues.issues.first?.kind, .preferences)
        XCTAssertEqual(issues.issues.first?.timestamp, timestamp)
    }

    func testSuccessfulRetryClearsResolvedIssues() {
        let binding = makeBinding()
        let store = FakePreferencesStore()
        let registrar = FakeRegistrar()
        registrar.registerFailure = { candidate, _ in registrationFailure(candidate) }
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)

        XCTAssertEqual(coordinator.apply([binding]), .rejected)
        XCTAssertFalse(issues.issues.isEmpty)
        registrar.registerFailure = nil

        XCTAssertEqual(coordinator.apply([binding]), .applied)
        XCTAssertTrue(issues.issues.isEmpty)
    }

    func testSuccessfulRetryPreservesUnrelatedApplicationIssue() {
        let binding = makeBinding()
        let store = FakePreferencesStore()
        let registrar = FakeRegistrar()
        let issues = IssueCenter(issues: [
            .init(kind: .application, reason: "app missing", suggestion: "choose app")
        ])
        let coordinator = makeCoordinator(store: store, registrar: registrar, issues: issues)

        XCTAssertEqual(coordinator.apply([binding]), .applied)
        XCTAssertEqual(issues.issues.map(\.kind), [.application])
    }

    func testCorruptPersistedValuesCannotBypassValidation() {
        let invalid = makeBinding(
            keyCode: 200,
            modifiers: ShortcutModifiers(rawValue: 0x80)
        )
        let store = FakePreferencesStore(stored: [invalid])
        let registrar = FakeRegistrar()
        let coordinator = makeCoordinator(store: store, registrar: registrar)

        XCTAssertEqual(coordinator.start(), .rejected)
        XCTAssertTrue(coordinator.activeBindings.isEmpty)
        XCTAssertTrue(registrar.registerCalls.isEmpty)
    }

    func testShutdownUnregistersEveryActiveBinding() {
        let bindings = [makeBinding(keyCode: 0), makeBinding(keyCode: 1)]
        let store = FakePreferencesStore(stored: bindings)
        let registrar = FakeRegistrar()
        let coordinator = makeCoordinator(store: store, registrar: registrar)
        XCTAssertEqual(coordinator.start(), .applied)

        coordinator.shutdown()

        XCTAssertEqual(Set(registrar.unregisterCalls), Set(bindings))
        XCTAssertTrue(registrar.active.isEmpty)
        XCTAssertTrue(coordinator.activeBindings.isEmpty)
    }

    private func makeCoordinator(
        store: FakePreferencesStore,
        registrar: FakeRegistrar,
        issues: IssueCenter = IssueCenter()
    ) -> RegistrationCoordinator {
        RegistrationCoordinator(
            store: store,
            registrar: registrar,
            issueCenter: issues,
            now: { self.timestamp }
        )
    }
}
#endif
