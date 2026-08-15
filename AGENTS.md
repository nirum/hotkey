# Repository guidance

## Project overview

Hotkey is a Swift 5.9 macOS 13+ menu-bar application. `Sources/Hotkey/main.swift` creates an accessory `NSApplication`; `AppDelegate` owns the status item and coordinates configuration, Carbon global-hotkey registration, and AppKit application/window behavior.

Current source layout:

- `Sources/Hotkey/AppDelegate.swift`: application lifecycle, menu, and launch-at-login support.
- `Sources/Hotkey/ConfigManager.swift`: TOML loading and filesystem watching.
- `Sources/Hotkey/HotkeyManager.swift`: Carbon registration and dispatch.
- `Sources/Hotkey/WindowManager.swift`: AppKit/Quartz application toggling.
- `Sources/Hotkey/KeyMapping.swift`: textual key/modifier conversion.
- `Makefile`: release build and unsigned `.app` packaging.

Update this file whenever architecture, dependencies, supported platforms, or verification commands change.

## Working conventions

- Use a project-local `.worktrees/<topic>` directory for isolated feature work. `.worktrees/` is ignored by Git.
- Keep macOS framework adapters thin. Business rules and state transitions should remain independent of AppKit and Carbon where practical.
- Preserve stable model identity and use explicit, Codable data contracts for persisted state.
- Prefer small types with dependency injection over global framework state.
- Do not modify unrelated user changes or generated artifacts.

## Commands

- `swift build` compiles the debug executable. It does not package or install the application.
- `swift test` compiles and runs the SwiftPM test suite. The baseline repository has no test target, so this currently reports `no tests found`.
- `make install` performs a release build, creates the unsigned `Hotkey.app` bundle and icons, and replaces `~/Applications/Hotkey.app`. It requires macOS tools plus ImageMagick's `magick` command and changes the user's installed applications.
- `make uninstall` removes the installed app and its launch agent. Treat it as destructive.

Before handing off a code change, run `swift build` and `swift test`. Packaging changes also require `make app` or `make install` plus a manual launch smoke test.

## Configuration and packaging

The current app reads `~/.config/hotkey/config.toml`, creates an example when absent, watches it for changes, and reloads registrations. TOMLKit is the sole package dependency. The packaging target creates an unsigned menu-bar app with bundle identifier `com.hotkey.app`, minimum macOS 13, and `LSUIElement` enabled.

## macOS constraints

- Global shortcuts use the legacy Carbon hot-key API. Keep Carbon flags and `EventHotKeyRef` values inside the registration adapter.
- UI and lifecycle operations use AppKit and must run on the main thread.
- Application matching and activation go through `NSWorkspace`; visible-window checks use Quartz window metadata.
- Avoid modal error alerts in a menu-bar utility. Errors should remain inspectable without blocking input.
- Registration tests must never reserve real global shortcuts, and application tests must never launch or hide real apps.

## Verification baseline

On 2026-08-15, `swift build` succeeded from the isolated worktree. `swift test` built the package and then reported that no tests exist. An earlier local run under restricted cache access exposed a Swift compiler/SDK patch mismatch; if that recurs, select an Xcode or Command Line Tools installation whose Swift compiler and SDK build versions match before judging code failures.
