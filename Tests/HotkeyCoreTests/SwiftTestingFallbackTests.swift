#if !canImport(XCTest)
import Foundation
import Testing
@testable import HotkeyCore

@Suite("HotkeyCore fallback tests")
struct SwiftTestingFallbackTests {
    @Test("Preferences round trip, empty state, schema, and corruption")
    func preferencesStore() throws {
        let suite = "HotkeyCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)
        let store = UserDefaultsPreferencesStore(defaults: defaults)
        #expect(try store.load().isEmpty)

        let binding = makeBinding(modifiers: [.command, .shift])
        try store.save([binding])
        #expect(try store.load() == [binding])

        defaults.set(Data("bad-json".utf8), forKey: UserDefaultsPreferencesStore.storageKey)
        #expect(throws: PreferencesStoreError.self) { try store.load() }

        let future = try JSONEncoder().encode(StoredPreferences(schemaVersion: 99, bindings: []))
        defaults.set(future, forKey: UserDefaultsPreferencesStore.storageKey)
        do {
            _ = try store.load()
            Issue.record("Expected unsupported schema")
        } catch {
            #expect(error as? PreferencesStoreError == .unsupportedSchema(99))
        }
    }

    @Test("Shortcut recording and display")
    func shortcuts() {
        for modifiers: ShortcutModifiers in [.command, .option, .control] {
            #expect(ShortcutInterpreter.capture(keyCode: 0, modifiers: modifiers)
                == .accepted(.init(keyCode: 0, modifiers: modifiers)))
        }
        #expect(ShortcutInterpreter.capture(keyCode: 0, modifiers: .shift).isRejected)
        #expect(ShortcutInterpreter.capture(keyCode: 0, modifiers: []).isRejected)
        #expect(ShortcutInterpreter.capture(keyCode: nil, modifiers: .command).isRejected)
        #expect(ShortcutInterpreter.capture(
            keyCode: 0,
            modifiers: ShortcutModifiers(rawValue: 0x80)
        ).isRejected)
        #expect(ShortcutDisplay.string(
            keyCode: 0,
            modifiers: [.control, .option, .shift, .command]
        ) == "⌃⌥⇧⌘A")
    }

    @Test("Validation and duplicates")
    func validation() {
        let valid = [
            makeBinding(keyCode: 0, modifiers: .command),
            makeBinding(keyCode: 1, modifiers: .option),
            makeBinding(keyCode: 2, modifiers: .control),
            makeBinding(keyCode: 3, modifiers: [.control, .shift]),
        ]
        #expect(BindingValidator.validate(valid).isEmpty)

        let shiftOnly = makeBinding(keyCode: 4, modifiers: .shift)
        guard case .rejected(let recorderMessage) = ShortcutInterpreter.capture(
            keyCode: shiftOnly.keyCode,
            modifiers: shiftOnly.modifiers
        ) else {
            Issue.record("Expected recorder rejection")
            return
        }
        #expect(BindingValidator.validate([shiftOnly]).first?.message == recorderMessage)

        let duplicate = makeBinding(
            name: "Other",
            bundleIdentifier: "com.example.other",
            path: "/Applications/Other.app",
            keyCode: 0,
            modifiers: .command
        )
        #expect(BindingValidator.validate([valid[0], duplicate]).map(\.code) == [.duplicateShortcut])

        let corrupt = makeBinding(
            path: "/tmp/not-an-app",
            keyCode: 200,
            modifiers: ShortcutModifiers(rawValue: 0x80)
        )
        let codes = Set(BindingValidator.validate([corrupt]).map(\.code))
        #expect(codes == [.unsupportedModifiers, .missingPrimaryModifier, .unsupportedKey, .invalidApplication])
    }

    @Test("CRUD, restart, and empty preference state")
    func preferenceLifecycle() {
        let store = FakePreferencesStore()
        let firstRegistrar = FakeRegistrar()
        let coordinator = makeCoordinator(store, firstRegistrar)
        #expect(coordinator.start() == .applied)
        #expect(coordinator.activeBindings.isEmpty)

        let added = makeBinding()
        #expect(coordinator.apply([added]) == .applied)
        var edited = added
        edited.keyCode = 11
        #expect(coordinator.apply([edited]) == .applied)

        let restarted = makeCoordinator(store, FakeRegistrar())
        #expect(restarted.start() == .applied)
        #expect(restarted.activeBindings == [edited])
        #expect(restarted.apply([]) == .applied)
        #expect(store.stored.isEmpty)
    }

    @Test("Registration rejection rolls back partial registrations")
    func registrationRollback() {
        let old = makeBinding(keyCode: 0)
        let first = makeBinding(keyCode: 1)
        let failing = makeBinding(keyCode: 2)
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        registrar.registerFailure = { binding, _ in
            binding.id == failing.id ? registrationFailure(binding) : nil
        }
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store, registrar, issues)
        #expect(coordinator.start() == .applied)
        #expect(coordinator.apply([first, failing]) == .rejected)
        #expect(coordinator.activeBindings == [old])
        #expect(store.stored == [old])
        #expect(Set(registrar.active.values) == [old])
        #expect(issues.issues.contains { $0.kind == .registration })
    }

    @Test("Persistence rejection rolls back and successful retry clears issues")
    func persistenceRollbackAndRetry() {
        let old = makeBinding(keyCode: 0)
        let proposed = makeBinding(keyCode: 1)
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store, registrar, issues)
        #expect(coordinator.start() == .applied)
        store.saveError = TestFailure.save
        #expect(coordinator.apply([proposed]) == .rejected)
        #expect(coordinator.activeBindings == [old])
        #expect(Set(registrar.active.values) == [old])
        #expect(issues.issues.contains { $0.kind == .preferences })

        store.saveError = nil
        #expect(coordinator.apply([proposed]) == .applied)
        #expect(issues.issues.isEmpty)
    }

    @Test("Rollback failure and corrupt reload retain known-good state")
    func rollbackFailureAndReload() {
        let old = makeBinding(keyCode: 0)
        let failing = makeBinding(keyCode: 1)
        let store = FakePreferencesStore(stored: [old])
        let registrar = FakeRegistrar()
        registrar.registerFailure = { binding, attempt in
            if binding.id == failing.id { return registrationFailure(binding) }
            if binding.id == old.id && attempt == 2 { return registrationFailure(binding, "restore failed") }
            return nil
        }
        let issues = IssueCenter()
        let coordinator = makeCoordinator(store, registrar, issues)
        #expect(coordinator.start() == .applied)
        #expect(coordinator.apply([failing]) == .rollbackFailed)
        #expect(issues.issues.contains { $0.kind == .rollback })

        store.loadError = TestFailure.load
        #expect(coordinator.reload() == .rejected)
        #expect(coordinator.activeBindings == [old])
        #expect(issues.issues.contains { $0.kind == .preferences })
    }

    @Test("Application matching precedence and active instance")
    func applicationMatching() {
        let target = makeTarget()
        let name = app(1, "Example", "wrong", "/Other/Name.app")
        let url = app(2, "Other", "wrong", target.applicationURL.path)
        let id = app(3, "Renamed", "com.example.app", "/Moved/App.app", true)
        #expect(ApplicationTogglePolicy.bestMatch(
            target: target,
            runningApplications: [name, url, id]
        )?.processIdentifier == 3)

        let duplicate = app(4, "Example", "com.example.app", "/Copy/App.app", false)
        #expect(ApplicationTogglePolicy.bestMatch(
            target: target,
            runningApplications: [duplicate, id]
        )?.processIdentifier == 3)
    }

    @Test("Application toggle hide, activate, reopen, and unavailable")
    func applicationDecisions() {
        let target = makeTarget()
        let active = app(10, "Example", "com.example.app", "/Applications/Example.app", true)
        #expect(ApplicationTogglePolicy.decide(
            target: target,
            runningApplications: [active],
            visibleWindowProcessIDs: [10],
            resolvedBundleURL: nil,
            storedURLExists: true
        ) == .hide(processIdentifier: 10))

        let background = app(11)
        #expect(ApplicationTogglePolicy.decide(
            target: target,
            runningApplications: [background],
            visibleWindowProcessIDs: [11],
            resolvedBundleURL: nil,
            storedURLExists: true
        ) == .activate(processIdentifier: 11))

        let moved = URL(fileURLWithPath: "/Moved/Example.app")
        #expect(ApplicationTogglePolicy.decide(
            target: target,
            runningApplications: [],
            visibleWindowProcessIDs: [],
            resolvedBundleURL: moved,
            storedURLExists: false
        ) == .reopen(moved))

        #expect(ApplicationTogglePolicy.decide(
            target: target,
            runningApplications: [],
            visibleWindowProcessIDs: [],
            resolvedBundleURL: nil,
            storedURLExists: false
        ) == .unavailable)

        let workspace = FakeApplicationWorkspace()
        let windows = FakeVisibleWindows()
        workspace.runningApplicationSnapshots = [background]
        windows.processIdentifiers = [11]
        #expect(ApplicationToggleResolver(workspace: workspace, windows: windows)
            .action(for: target) == .activate(processIdentifier: 11))
    }

    @Test("Issue state deduplicates and resolves")
    func issueState() {
        let center = IssueCenter()
        let id = UUID()
        center.report(.init(kind: .validation, bindingID: id, reason: "bad", suggestion: "fix"))
        center.report(.init(kind: .validation, bindingID: id, reason: "bad", suggestion: "fix"))
        #expect(center.issues.count == 1)
        center.clear(kind: .validation, bindingID: id)
        #expect(center.issues.isEmpty)
    }

    private func makeCoordinator(
        _ store: FakePreferencesStore,
        _ registrar: FakeRegistrar,
        _ issues: IssueCenter = IssueCenter()
    ) -> RegistrationCoordinator {
        RegistrationCoordinator(store: store, registrar: registrar, issueCenter: issues)
    }

    private func app(
        _ pid: Int32,
        _ name: String = "Example",
        _ id: String? = "com.example.app",
        _ path: String = "/Applications/Example.app",
        _ active: Bool = false
    ) -> RunningApplicationSnapshot {
        RunningApplicationSnapshot(
            processIdentifier: pid,
            displayName: name,
            bundleIdentifier: id,
            bundleURL: URL(fileURLWithPath: path),
            isActive: active
        )
    }
}

private extension ShortcutCaptureResult {
    var isRejected: Bool {
        if case .rejected = self { return true }
        return false
    }
}
#endif
