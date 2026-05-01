import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var configManager: ConfigManager!
    private var hotkeyManager: HotkeyManager!
    private var windowManager: WindowManager!
    private var launchAtLoginItem: NSMenuItem!

    private let launchAgentLabel = "com.hotkey.app"
    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        windowManager = WindowManager()
        hotkeyManager = HotkeyManager()
        hotkeyManager.onHotkey = { [weak self] appName in
            self?.windowManager.toggleApp(appName)
        }

        configManager = ConfigManager()
        configManager.onChange = { [weak self] in
            self?.reloadConfig()
        }

        let entries = configManager.loadConfig()
        hotkeyManager.registerAll(entries)
        configManager.startWatching()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "Hotkey"
            )
        }

        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "Hotkey", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let reloadItem = NSMenuItem(
            title: "Reload Config",
            action: #selector(reloadConfigAction),
            keyEquivalent: "r"
        )
        reloadItem.keyEquivalentModifierMask = [.command]
        reloadItem.target = self
        menu.addItem(reloadItem)

        let editItem = NSMenuItem(
            title: "Edit Config…",
            action: #selector(editConfigAction),
            keyEquivalent: ","
        )
        editItem.keyEquivalentModifierMask = [.command]
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Hotkey",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func reloadConfigAction() {
        reloadConfig()
    }

    private func reloadConfig() {
        hotkeyManager.unregisterAll()
        let entries = configManager.loadConfig()
        hotkeyManager.registerAll(entries)
    }

    @objc private func editConfigAction() {
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/hotkey/config.toml")
        NSWorkspace.shared.open(configFile)
    }

    @objc private func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled {
            try? FileManager.default.removeItem(at: launchAgentURL)
        } else {
            writeLaunchAgent()
        }
        launchAtLoginItem.state = isLaunchAtLoginEnabled ? .on : .off
    }

    private var isLaunchAtLoginEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private func writeLaunchAgent() {
        let executablePath = resolveExecutablePath()
        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        let dir = launchAgentURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try? data?.write(to: launchAgentURL)
    }

    private func resolveExecutablePath() -> String {
        if let bundlePath = Bundle.main.executablePath,
           bundlePath.contains(".app/") {
            return bundlePath
        }
        // Running as bare binary — resolve from argv[0]
        let argv0 = ProcessInfo.processInfo.arguments[0]
        if argv0.hasPrefix("/") {
            return argv0
        }
        let cwd = FileManager.default.currentDirectoryPath
        return (cwd as NSString).appendingPathComponent(argv0)
    }

    @objc private func quit() {
        hotkeyManager.unregisterAll()
        configManager.stopWatching()
        NSApp.terminate(nil)
    }
}
