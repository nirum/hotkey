import Foundation

public struct RegistrationToken: Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public struct RegistrationFailure: Error, Equatable, LocalizedError, Sendable {
    public let bindingID: UUID
    public let reason: String
    public let status: Int32?

    public init(bindingID: UUID, reason: String, status: Int32? = nil) {
        self.bindingID = bindingID
        self.reason = reason
        self.status = status
    }

    public var errorDescription: String? { reason }
}

public protocol HotkeyRegistering: AnyObject {
    func register(_ binding: HotkeyBinding) -> Result<RegistrationToken, RegistrationFailure>
    func unregister(_ token: RegistrationToken, binding: HotkeyBinding) -> Result<Void, RegistrationFailure>
}

public enum PreferenceApplyResult: Equatable {
    case applied
    case rejected
    case rollbackFailed
}

public final class RegistrationCoordinator {
    public private(set) var activeBindings: [HotkeyBinding] = []

    private let store: PreferencesStoring
    private let registrar: HotkeyRegistering
    private let issueCenter: IssueCenter
    private let now: () -> Date
    private var registrations: [UUID: RegistrationToken] = [:]

    public init(
        store: PreferencesStoring,
        registrar: HotkeyRegistering,
        issueCenter: IssueCenter,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.registrar = registrar
        self.issueCenter = issueCenter
        self.now = now
    }

    @discardableResult
    public func start() -> PreferenceApplyResult {
        do {
            let stored = try store.load()
            return transition(to: stored, persist: false)
        } catch {
            issueCenter.report(.init(
                kind: .preferences,
                reason: error.localizedDescription,
                timestamp: now(),
                suggestion: "Open Preferences and save a valid shortcut set. The last active shortcuts were kept."
            ))
            return .rejected
        }
    }

    @discardableResult
    public func reload() -> PreferenceApplyResult {
        start()
    }

    @discardableResult
    public func apply(_ proposed: [HotkeyBinding]) -> PreferenceApplyResult {
        transition(to: proposed, persist: true)
    }

    public func shutdown() {
        for binding in activeBindings {
            if let token = registrations[binding.id] {
                _ = registrar.unregister(token, binding: binding)
            }
        }
        registrations.removeAll()
        activeBindings.removeAll()
    }

    private func transition(to proposed: [HotkeyBinding], persist: Bool) -> PreferenceApplyResult {
        let validationFailures = BindingValidator.validate(proposed)
        guard validationFailures.isEmpty else {
            issueCenter.clear(kind: .validation)
            issueCenter.report(contentsOf: validationFailures.map { failure in
                issue(for: failure, in: proposed)
            })
            return .rejected
        }
        issueCenter.clear(kind: .validation)

        let oldBindings = activeBindings
        let oldRegistrations = registrations
        var oldTokensStillActive: [UUID: RegistrationToken] = [:]
        var oldBindingsToRestore: [HotkeyBinding] = []
        var transitionIssues: [HotkeyIssue] = []

        for binding in oldBindings {
            guard let token = oldRegistrations[binding.id] else { continue }
            switch registrar.unregister(token, binding: binding) {
            case .success:
                oldBindingsToRestore.append(binding)
            case .failure(let failure):
                oldTokensStillActive[binding.id] = token
                transitionIssues.append(registrationIssue(
                    failure,
                    binding: binding,
                    reasonPrefix: "Could not temporarily unregister this shortcut"
                ))
            }
        }

        if !transitionIssues.isEmpty {
            let restorationIssues = restore(
                oldBindingsToRestore,
                keeping: &oldTokensStillActive
            )
            activeBindings = oldBindings
            registrations = oldTokensStillActive
            issueCenter.report(contentsOf: transitionIssues + restorationIssues)
            return restorationIssues.isEmpty ? .rejected : .rollbackFailed
        }

        var proposedRegistrations: [UUID: RegistrationToken] = [:]
        for binding in proposed {
            switch registrar.register(binding) {
            case .success(let token):
                proposedRegistrations[binding.id] = token
            case .failure(let failure):
                transitionIssues.append(registrationIssue(failure, binding: binding))
                let rollbackIssues = rollback(
                    proposed: proposed,
                    proposedRegistrations: proposedRegistrations,
                    oldBindings: oldBindings
                )
                issueCenter.report(contentsOf: transitionIssues + rollbackIssues)
                return rollbackIssues.isEmpty ? .rejected : .rollbackFailed
            }
        }

        if persist {
            do {
                try store.save(proposed)
            } catch {
                transitionIssues.append(.init(
                    kind: .preferences,
                    reason: error.localizedDescription,
                    timestamp: now(),
                    suggestion: "Check that preferences storage is available, then try saving again."
                ))
                let rollbackIssues = rollback(
                    proposed: proposed,
                    proposedRegistrations: proposedRegistrations,
                    oldBindings: oldBindings
                )
                issueCenter.report(contentsOf: transitionIssues + rollbackIssues)
                return rollbackIssues.isEmpty ? .rejected : .rollbackFailed
            }
        }

        activeBindings = proposed
        registrations = proposedRegistrations
        issueCenter.clear(kind: .preferences)
        issueCenter.clear(kind: .validation)
        issueCenter.clear(kind: .registration)
        issueCenter.clear(kind: .rollback)
        return .applied
    }

    private func rollback(
        proposed: [HotkeyBinding],
        proposedRegistrations: [UUID: RegistrationToken],
        oldBindings: [HotkeyBinding]
    ) -> [HotkeyIssue] {
        var rollbackIssues: [HotkeyIssue] = []
        for binding in proposed {
            guard let token = proposedRegistrations[binding.id] else { continue }
            if case .failure(let failure) = registrar.unregister(token, binding: binding) {
                rollbackIssues.append(rollbackIssue(
                    failure,
                    binding: binding,
                    action: "remove a partially registered shortcut"
                ))
            }
        }

        var restored: [UUID: RegistrationToken] = [:]
        rollbackIssues += restore(oldBindings, keeping: &restored)
        activeBindings = oldBindings
        registrations = restored
        return rollbackIssues
    }

    private func restore(
        _ bindings: [HotkeyBinding],
        keeping registrations: inout [UUID: RegistrationToken]
    ) -> [HotkeyIssue] {
        var issues: [HotkeyIssue] = []
        for binding in bindings where registrations[binding.id] == nil {
            switch registrar.register(binding) {
            case .success(let token):
                registrations[binding.id] = token
            case .failure(let failure):
                issues.append(rollbackIssue(
                    failure,
                    binding: binding,
                    action: "restore the last known-good shortcut"
                ))
            }
        }
        return issues
    }

    private func issue(
        for failure: BindingValidationFailure,
        in bindings: [HotkeyBinding]
    ) -> HotkeyIssue {
        let binding = bindings.first { $0.id == failure.bindingID }
        return .init(
            kind: .validation,
            bindingID: failure.bindingID,
            applicationName: binding?.target.displayName,
            reason: failure.message,
            timestamp: now(),
            suggestion: "Choose a unique key with Command, Option, or Control."
        )
    }

    private func registrationIssue(
        _ failure: RegistrationFailure,
        binding: HotkeyBinding,
        reasonPrefix: String = "macOS refused to register this shortcut"
    ) -> HotkeyIssue {
        .init(
            kind: .registration,
            bindingID: binding.id,
            applicationName: binding.target.displayName,
            reason: "\(reasonPrefix): \(failure.reason)",
            timestamp: now(),
            suggestion: "Choose another shortcut or remove the conflicting system or application shortcut."
        )
    }

    private func rollbackIssue(
        _ failure: RegistrationFailure,
        binding: HotkeyBinding,
        action: String
    ) -> HotkeyIssue {
        .init(
            kind: .rollback,
            bindingID: binding.id,
            applicationName: binding.target.displayName,
            reason: "Could not \(action): \(failure.reason)",
            timestamp: now(),
            suggestion: "Quit and reopen Hotkey to restore all global shortcuts, then correct the conflicting binding."
        )
    }
}
