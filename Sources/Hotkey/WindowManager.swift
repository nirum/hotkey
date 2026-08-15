import AppKit
import HotkeyCore

final class WindowManager {
    var onFailure: ((HotkeyBinding, String) -> Void)?

    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func toggle(_ binding: HotkeyBinding) {
        let action = ApplicationToggleResolver(workspace: self, windows: self)
            .action(for: binding.target)

        switch action {
        case .hide(let processIdentifier):
            runningApplication(processIdentifier)?.hide()
        case .activate(let processIdentifier):
            guard let application = runningApplication(processIdentifier) else {
                fail(binding, "The running application disappeared before it could be activated.")
                return
            }
            application.unhide()
            application.activate(options: [.activateIgnoringOtherApps])
        case .reopen(let url):
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            workspace.openApplication(at: url, configuration: configuration) { [weak self] _, error in
                if let error {
                    self?.fail(binding, "Could not open the application: \(error.localizedDescription)")
                }
            }
        case .unavailable:
            fail(binding, "The selected application could not be found. Choose it again in Preferences.")
        }
    }

    private func runningApplication(_ processIdentifier: pid_t) -> NSRunningApplication? {
        NSRunningApplication(processIdentifier: processIdentifier)
    }

    func visibleWindowProcessIdentifiers() -> Set<Int32> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] else { return [] }

        return Set(windows.compactMap { window in
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { return nil }
            return ownerPID
        })
    }

    private func fail(_ binding: HotkeyBinding, _ reason: String) {
        onFailure?(binding, reason)
    }
}

extension WindowManager: ApplicationWorkspaceProviding, VisibleWindowProviding {
    var runningApplicationSnapshots: [RunningApplicationSnapshot] {
        workspace.runningApplications.map {
            RunningApplicationSnapshot(
                processIdentifier: $0.processIdentifier,
                displayName: $0.localizedName,
                bundleIdentifier: $0.bundleIdentifier,
                bundleURL: $0.bundleURL,
                isActive: $0.isActive
            )
        }
    }

    func resolvedApplicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    func applicationURLExists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
