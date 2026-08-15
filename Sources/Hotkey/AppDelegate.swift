import AppKit
import Combine
import HotkeyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let issueCenter = IssueCenter()
    private let launchAgentLabel = "com.hotkey.app"

    private var statusItem: NSStatusItem!
    private var issueSummaryItem: NSMenuItem!
    private var showErrorsItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var issueCancellable: AnyCancellable?

    private var registrar: CarbonHotkeyRegistrar!
    private var coordinator: RegistrationCoordinator!
    private var windowManager: WindowManager!
    private var preferencesWindowController: PreferencesWindowController!
    private var issueWindowController: IssueWindowController!

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        windowManager = WindowManager()
        windowManager.onFailure = { [weak self] binding, reason in
            self?.issueCenter.report(.init(
                kind: .application,
                bindingID: binding.id,
                applicationName: binding.target.displayName,
                reason: reason,
                suggestion: "Choose the application again in Preferences and retry the shortcut."
            ))
        }

        registrar = CarbonHotkeyRegistrar()
        registrar.onHotkey = { [weak self] binding in
            self?.windowManager.toggle(binding)
        }

        coordinator = RegistrationCoordinator(
            store: UserDefaultsPreferencesStore(),
            registrar: registrar,
            issueCenter: issueCenter
        )
        _ = coordinator.start()

        let preferencesViewModel = PreferencesViewModel(
            coordinator: coordinator,
            issueCenter: issueCenter
        )
        preferencesWindowController = PreferencesWindowController(viewModel: preferencesViewModel)
        issueWindowController = IssueWindowController(issueCenter: issueCenter)

        issueCancellable = issueCenter.$issues
            .receive(on: RunLoop.main)
            .sink { [weak self] issues in
                self?.updateIssueStatus(issues)
            }
        updateIssueStatus(issueCenter.issues)
    }

    private func setupMenuBar() {
        // The ⌘H lockup is wider than it is tall, so the item sizes itself to the
        // image instead of being squeezed into a 22pt square.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setNormalStatusImage()

        let menu = NSMenu()
        let headerItem = NSMenuItem(title: "Hotkey", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        issueSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        issueSummaryItem.isEnabled = false
        issueSummaryItem.isHidden = true
        menu.addItem(issueSummaryItem)

        showErrorsItem = NSMenuItem(
            title: "Show Errors…",
            action: #selector(showErrors),
            keyEquivalent: ""
        )
        showErrorsItem.target = self
        showErrorsItem.isHidden = true
        menu.addItem(showErrorsItem)

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

    private func setNormalStatusImage() {
        guard let button = statusItem.button else { return }
        if let iconPath = Bundle.main.path(forResource: "menubar-icon@2x", ofType: "png"),
           let icon = NSImage(contentsOfFile: iconPath) {
            icon.size = NSSize(width: 28, height: 22)
            // Template images are tinted by AppKit for the light and dark menu
            // bar and inverted while the menu is open. Colour images are not.
            icon.isTemplate = true
            icon.accessibilityDescription = "Hotkey"
            button.image = icon
        } else {
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "Hotkey"
            )
        }
    }

    private func updateIssueStatus(_ issues: [HotkeyIssue]) {
        let hasIssues = !issues.isEmpty
        issueSummaryItem.isHidden = !hasIssues
        showErrorsItem.isHidden = !hasIssues
        issueSummaryItem.title = issues.count == 1
            ? "1 unresolved error"
            : "\(issues.count) unresolved errors"

        if hasIssues {
            statusItem.button?.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "Hotkey has unresolved errors"
            )
        } else {
            setNormalStatusImage()
        }
    }

    @objc private func showPreferences() {
        preferencesWindowController.present()
    }

    @objc private func showErrors() {
        issueWindowController.present()
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
        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [resolveExecutablePath()],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]
        let directory = launchAgentURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try? data?.write(to: launchAgentURL)
    }

    private func resolveExecutablePath() -> String {
        if let path = Bundle.main.executablePath, path.contains(".app/") {
            return path
        }
        let argument = ProcessInfo.processInfo.arguments[0]
        if argument.hasPrefix("/") { return argument }
        return (FileManager.default.currentDirectoryPath as NSString)
            .appendingPathComponent(argument)
    }

    @objc private func quit() {
        coordinator.shutdown()
        NSApp.terminate(nil)
    }
}
