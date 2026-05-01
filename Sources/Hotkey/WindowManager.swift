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
            if app.isActive {
                app.hide()
            } else {
                app.unhide()
                app.activate(options: [.activateIgnoringOtherApps])
            }
        } else if let url = resolveAppURL(appName) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error = error {
                    NSLog("Hotkey: Failed to launch '%@': %@", appName, error.localizedDescription)
                }
            }
        } else {
            NSLog("Hotkey: Could not find application '%@'", appName)
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
