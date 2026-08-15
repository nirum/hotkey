import Foundation
@testable import HotkeyCore

enum TestFailure: Error, LocalizedError {
    case load
    case save

    var errorDescription: String? {
        switch self {
        case .load: return "test load failure"
        case .save: return "test save failure"
        }
    }
}

final class FakePreferencesStore: PreferencesStoring {
    var stored: [HotkeyBinding]
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCalls: [[HotkeyBinding]] = []

    init(stored: [HotkeyBinding] = []) {
        self.stored = stored
    }

    func load() throws -> [HotkeyBinding] {
        if let loadError { throw loadError }
        return stored
    }

    func save(_ bindings: [HotkeyBinding]) throws {
        saveCalls.append(bindings)
        if let saveError { throw saveError }
        stored = bindings
    }
}

final class FakeRegistrar: HotkeyRegistering {
    typealias FailureRule = (HotkeyBinding, Int) -> RegistrationFailure?

    var registerFailure: FailureRule?
    var unregisterFailure: FailureRule?
    private(set) var registerCalls: [HotkeyBinding] = []
    private(set) var unregisterCalls: [HotkeyBinding] = []
    private(set) var active: [RegistrationToken: HotkeyBinding] = [:]

    private var nextToken: UInt32 = 1
    private var registerCounts: [UUID: Int] = [:]
    private var unregisterCounts: [UUID: Int] = [:]

    func register(_ binding: HotkeyBinding) -> Result<RegistrationToken, RegistrationFailure> {
        registerCalls.append(binding)
        registerCounts[binding.id, default: 0] += 1
        if let failure = registerFailure?(binding, registerCounts[binding.id]!) {
            return .failure(failure)
        }
        let token = RegistrationToken(rawValue: nextToken)
        nextToken += 1
        active[token] = binding
        return .success(token)
    }

    func unregister(
        _ token: RegistrationToken,
        binding: HotkeyBinding
    ) -> Result<Void, RegistrationFailure> {
        unregisterCalls.append(binding)
        unregisterCounts[binding.id, default: 0] += 1
        if let failure = unregisterFailure?(binding, unregisterCounts[binding.id]!) {
            return .failure(failure)
        }
        active.removeValue(forKey: token)
        return .success(())
    }
}

func makeTarget(
    name: String = "Example",
    bundleIdentifier: String? = "com.example.app",
    path: String = "/Applications/Example.app"
) -> AppTarget {
    AppTarget(
        displayName: name,
        bundleIdentifier: bundleIdentifier,
        applicationURL: URL(fileURLWithPath: path)
    )
}

func makeBinding(
    id: UUID = UUID(),
    name: String = "Example",
    bundleIdentifier: String? = "com.example.app",
    path: String = "/Applications/Example.app",
    keyCode: UInt32 = 0,
    modifiers: ShortcutModifiers = .option
) -> HotkeyBinding {
    HotkeyBinding(
        id: id,
        target: makeTarget(name: name, bundleIdentifier: bundleIdentifier, path: path),
        keyCode: keyCode,
        modifiers: modifiers
    )
}

func registrationFailure(_ binding: HotkeyBinding, _ reason: String = "occupied") -> RegistrationFailure {
    RegistrationFailure(bindingID: binding.id, reason: reason, status: -1)
}
