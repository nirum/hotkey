import Foundation
import TOMLKit

struct HotkeyEntry: Codable {
    let key: String
    let modifiers: [String]
    let app: String
}

private struct HotkeyConfig: Codable {
    let hotkey: [HotkeyEntry]
}

class ConfigManager {
    private let configDir: URL
    private let configFile: URL
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var debounceWork: DispatchWorkItem?
    var onChange: (() -> Void)?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/hotkey")
        configFile = configDir.appendingPathComponent("config.toml")
    }

    func loadConfig() -> [HotkeyEntry] {
        ensureConfigExists()

        do {
            let contents = try String(contentsOf: configFile, encoding: .utf8)
            let config = try TOMLDecoder().decode(HotkeyConfig.self, from: contents)
            NSLog("Hotkey: Loaded %d hotkey(s) from config", config.hotkey.count)
            return config.hotkey
        } catch {
            NSLog("Hotkey: Failed to parse config: %@", error.localizedDescription)
            return []
        }
    }

    func startWatching() {
        watchFile()
    }

    func stopWatching() {
        debounceWork?.cancel()
        dispatchSource?.cancel()
        dispatchSource = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func ensureConfigExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir.path) {
            try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: configFile.path) {
            let example = """
            # Hotkey configuration
            # Define keyboard shortcuts to toggle application visibility.
            #
            # Example:
            # [[hotkey]]
            # key = "space"
            # modifiers = ["option"]
            # app = "iTerm"
            #
            # [[hotkey]]
            # key = "b"
            # modifiers = ["option"]
            # app = "Safari"
            """
            try? example.write(to: configFile, atomically: true, encoding: .utf8)
        }
    }

    private func watchFile() {
        dispatchSource?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }

        fileDescriptor = open(configFile.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            NSLog("Hotkey: Could not open config file for watching")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data

            if flags.contains(.delete) || flags.contains(.rename) {
                // File was replaced (atomic save) — re-establish watch after a short delay
                self.dispatchSource?.cancel()
                close(self.fileDescriptor)
                self.fileDescriptor = -1

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.watchFile()
                    self?.scheduleReload()
                }
                return
            }

            self.scheduleReload()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        dispatchSource = source
        source.resume()
    }

    private func scheduleReload() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    deinit {
        stopWatching()
    }
}
