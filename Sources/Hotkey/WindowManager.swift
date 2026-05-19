import AppKit

class WindowManager {
    private var appURLCache: [String: URL] = [:]

    private static let searchDirectories: [String] = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
    ]

    func toggleApp(_ appName: String) {
        if let app = findRunningApp(named: appName) {
            let hasWindows = hasVisibleWindows(pid: app.processIdentifier)
            if app.isActive && hasWindows {
                app.hide()
            } else if hasWindows {
                app.unhide()
                app.activate(options: [.activateIgnoringOtherApps])
            } else if let url = app.bundleURL {
                openOrReopen(url: url, appName: appName)
            }
        } else if let url = resolveAppURL(appName) {
            openOrReopen(url: url, appName: appName)
        } else {
            NSLog("Hotkey: Could not find application '%@'", appName)
        }
    }

    private func openOrReopen(url: URL, appName: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                NSLog("Hotkey: Failed to open '%@': %@", appName, error.localizedDescription)
            }
        }
    }

    private func hasVisibleWindows(pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] else {
            return false
        }
        return windows.contains { window in
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                return false
            }
            return true
        }
    }

    private func findRunningApp(named name: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            app.localizedName == name
        }
    }

    private func resolveAppURL(_ appName: String) -> URL? {
        if let cached = appURLCache[appName] {
            if FileManager.default.fileExists(atPath: cached.path) {
                return cached
            }
            appURLCache.removeValue(forKey: appName)
        }

        // Search standard directories
        for dir in Self.searchDirectories {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(appName).app")
            if FileManager.default.fileExists(atPath: url.path) {
                appURLCache[appName] = url
                return url
            }
        }

        // Check ~/Applications
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .appendingPathComponent("\(appName).app")
        if FileManager.default.fileExists(atPath: homeApps.path) {
            appURLCache[appName] = homeApps
            return homeApps
        }

        // Try as bundle identifier
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            appURLCache[appName] = url
            return url
        }

        return nil
    }
}
