# Repository guidance

## Project overview

Hotkey is a Swift 5.9 macOS 13+ menu-bar application. `Sources/Hotkey/main.swift` creates an accessory `NSApplication`; `AppDelegate` owns the status item and coordinates native preferences, Carbon global-hotkey registration, and AppKit application/window behavior.

Current source layout:

- `Sources/HotkeyCore/`: framework-independent models, JSON preferences storage, validation, issue state, toggle decisions, and transactional registration coordination.
- `Sources/Hotkey/AppDelegate.swift`: application lifecycle, menu/error state, and launch-at-login support.
- `Sources/Hotkey/PreferencesWindow.swift`: SwiftUI settings UI, `.app` picker, and AppKit shortcut recorder.
- `Sources/Hotkey/CarbonHotkeyRegistrar.swift`: Carbon registration and event dispatch adapter.
- `Sources/Hotkey/WindowManager.swift`: AppKit/Quartz execution of core application-toggle decisions.
- `Sources/Hotkey/IssueWindow.swift`: non-modal SwiftUI issue details.
- `Tests/HotkeyCoreTests/`: XCTest coverage for core policy and transactional state.
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
- `swift test` compiles and runs the SwiftPM unit suite. Tests must not register real global shortcuts, use standard user defaults, or launch applications.
- `make install` performs a release build, creates the unsigned `Hotkey.app` bundle and icons, and replaces `~/Applications/Hotkey.app`. It requires macOS tools plus ImageMagick's `magick` command and changes the user's installed applications.
- `make uninstall` removes the installed app and its launch agent. Treat it as destructive.

Before handing off a code change, run `swift build` and `swift test`. Packaging changes also require `make app` or `make install` plus a manual launch smoke test.

GitHub Actions runs those commands on the `macos-26` runner for every push and pull request. Protect the default branch with the `Build and Test` job as a required check. CI intentionally has no signing, packaging, deployment, or release responsibility.

## Configuration and packaging

Bindings are encoded as versioned JSON in `UserDefaults` under `hotkey.bindings.v1`. There are no external Swift package dependencies. The legacy `~/.config/hotkey/config.toml` is intentionally never read, created, imported, watched, modified, or deleted. The packaging target creates an unsigned menu-bar app with bundle identifier `com.hotkey.app`, minimum macOS 13, and `LSUIElement` enabled.

## macOS constraints

- Global shortcuts use the legacy Carbon hot-key API. Keep Carbon flags and `EventHotKeyRef` values inside `CarbonHotkeyRegistrar`.
- UI and lifecycle operations use AppKit and must run on the main thread.
- Application matching and activation go through `NSWorkspace`; visible-window checks use Quartz window metadata.
- Avoid modal error alerts in a menu-bar utility. Errors should remain inspectable without blocking input.
- Registration tests must never reserve real global shortcuts, and application tests must never launch or hide real apps.

## Verification baseline

On 2026-08-15, the native-preferences app passed `swift build`. The installed standalone Command Line Tools pair a slightly mismatched compiler and SDK: they omit XCTest and `SwiftUIMacros`, so local `swift test` stops at the missing XCTest module. The full core scenarios were exercised successfully with a temporary local Swift Testing harness during implementation, but that toolchain also fails to embed its own Testing runtime without manual intervention. Use a matching full Xcode toolchain before judging test or macro failures; CI's `macos-26` image provides that environment.
