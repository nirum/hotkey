import Combine
import Foundation

public enum HotkeyIssueKind: String, Codable, CaseIterable, Sendable {
    case preferences
    case validation
    case registration
    case rollback
    case application

    public var title: String {
        switch self {
        case .preferences: return "Preferences"
        case .validation: return "Invalid shortcut"
        case .registration: return "Shortcut unavailable"
        case .rollback: return "Shortcut restoration failed"
        case .application: return "Application unavailable"
        }
    }
}

public struct HotkeyIssue: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: HotkeyIssueKind
    public let bindingID: UUID?
    public let applicationName: String?
    public let reason: String
    public let timestamp: Date
    public let suggestion: String

    public init(
        id: UUID = UUID(),
        kind: HotkeyIssueKind,
        bindingID: UUID? = nil,
        applicationName: String? = nil,
        reason: String,
        timestamp: Date = Date(),
        suggestion: String
    ) {
        self.id = id
        self.kind = kind
        self.bindingID = bindingID
        self.applicationName = applicationName
        self.reason = reason
        self.timestamp = timestamp
        self.suggestion = suggestion
    }
}

public final class IssueCenter: ObservableObject {
    @Published public private(set) var issues: [HotkeyIssue]

    public init(issues: [HotkeyIssue] = []) {
        self.issues = issues
    }

    public func report(_ issue: HotkeyIssue) {
        issues.removeAll {
            $0.kind == issue.kind
                && $0.bindingID == issue.bindingID
                && $0.reason == issue.reason
        }
        issues.insert(issue, at: 0)
    }

    public func report(contentsOf newIssues: [HotkeyIssue]) {
        for issue in newIssues.reversed() {
            report(issue)
        }
    }

    public func clear(kind: HotkeyIssueKind? = nil, bindingID: UUID? = nil) {
        issues.removeAll { issue in
            let kindMatches = kind == nil || issue.kind == kind
            let bindingMatches = bindingID == nil || issue.bindingID == bindingID
            return kindMatches && bindingMatches
        }
    }

    public func clearAll() {
        issues.removeAll()
    }
}
