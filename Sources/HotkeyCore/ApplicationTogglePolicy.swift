import Foundation

public struct RunningApplicationSnapshot: Equatable, Sendable {
    public let processIdentifier: Int32
    public let displayName: String?
    public let bundleIdentifier: String?
    public let bundleURL: URL?
    public let isActive: Bool

    public init(
        processIdentifier: Int32,
        displayName: String?,
        bundleIdentifier: String?,
        bundleURL: URL?,
        isActive: Bool
    ) {
        self.processIdentifier = processIdentifier
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.isActive = isActive
    }
}

public enum ApplicationToggleAction: Equatable, Sendable {
    case hide(processIdentifier: Int32)
    case activate(processIdentifier: Int32)
    case reopen(URL)
    case unavailable
}

public protocol ApplicationWorkspaceProviding: AnyObject {
    var runningApplicationSnapshots: [RunningApplicationSnapshot] { get }
    func resolvedApplicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
    func applicationURLExists(_ url: URL) -> Bool
}

public protocol VisibleWindowProviding: AnyObject {
    func visibleWindowProcessIdentifiers() -> Set<Int32>
}

public struct ApplicationToggleResolver {
    private let workspace: ApplicationWorkspaceProviding
    private let windows: VisibleWindowProviding

    public init(
        workspace: ApplicationWorkspaceProviding,
        windows: VisibleWindowProviding
    ) {
        self.workspace = workspace
        self.windows = windows
    }

    public func action(for target: AppTarget) -> ApplicationToggleAction {
        let resolvedURL = target.bundleIdentifier.flatMap {
            workspace.resolvedApplicationURL(forBundleIdentifier: $0)
        }
        return ApplicationTogglePolicy.decide(
            target: target,
            runningApplications: workspace.runningApplicationSnapshots,
            visibleWindowProcessIDs: windows.visibleWindowProcessIdentifiers(),
            resolvedBundleURL: resolvedURL,
            storedURLExists: workspace.applicationURLExists(target.applicationURL)
        )
    }
}

public enum ApplicationTogglePolicy {
    public static func decide(
        target: AppTarget,
        runningApplications: [RunningApplicationSnapshot],
        visibleWindowProcessIDs: Set<Int32>,
        resolvedBundleURL: URL?,
        storedURLExists: Bool
    ) -> ApplicationToggleAction {
        let match = bestMatch(target: target, runningApplications: runningApplications)

        if let match {
            let hasWindows = visibleWindowProcessIDs.contains(match.processIdentifier)
            if match.isActive && hasWindows {
                return .hide(processIdentifier: match.processIdentifier)
            }
            if hasWindows {
                return .activate(processIdentifier: match.processIdentifier)
            }
            if let url = resolvedBundleURL ?? match.bundleURL
                ?? (storedURLExists ? target.applicationURL : nil) {
                return .reopen(url)
            }
            return .unavailable
        }

        if let resolvedBundleURL {
            return .reopen(resolvedBundleURL)
        }
        if storedURLExists {
            return .reopen(target.applicationURL)
        }
        return .unavailable
    }

    public static func bestMatch(
        target: AppTarget,
        runningApplications: [RunningApplicationSnapshot]
    ) -> RunningApplicationSnapshot? {
        if let bundleIdentifier = normalized(target.bundleIdentifier),
           let match = preferred(runningApplications.filter {
               normalized($0.bundleIdentifier) == bundleIdentifier
           }) {
            return match
        }

        let selectedPath = canonicalPath(target.applicationURL)
        if let match = preferred(runningApplications.filter {
            guard let url = $0.bundleURL else { return false }
            return canonicalPath(url) == selectedPath
        }) {
            return match
        }

        return preferred(runningApplications.filter {
            $0.displayName?.caseInsensitiveCompare(target.displayName) == .orderedSame
        })
    }

    private static func preferred(
        _ applications: [RunningApplicationSnapshot]
    ) -> RunningApplicationSnapshot? {
        applications.first(where: \.isActive) ?? applications.first
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value.lowercased()
    }
}
