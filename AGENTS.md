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
- `Makefile`: versioned release builds plus unsigned `.app` and DMG packaging.

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
- `make app VERSION=<major.minor.patch> ARCH=<native-arch>` performs a release build and creates an unsigned, versioned `Hotkey.app`. It requires macOS packaging tools plus `librsvg`'s `rsvg-convert`.
- `make dmg VERSION=<major.minor.patch> ARCH=arm64` creates `dist/Hotkey-v<version>-arm64.dmg` and its `.sha256` checksum. The DMG contains the app and an `/Applications` symlink.
- `make install` builds the unsigned app with local defaults (`VERSION=0.0.0` and the host architecture) and replaces `~/Applications/Hotkey.app`.
- `make uninstall` removes the installed app and its launch agent. Treat it as destructive.

Before handing off a code change, run `swift build` and `swift test`. Packaging changes also require `make dmg VERSION=0.1.0 ARCH=arm64`, bundle-version and architecture checks, `hdiutil verify`, a read-only mount/layout check, checksum verification, and a manual launch smoke test.

GitHub Actions runs build and test on the `macos-26` runner for every push and pull request. Protect the default branch with the `Build and Test` job as a required check. A separate release workflow accepts only annotated `vMAJOR.MINOR.PATCH` tags whose commits belong to `main`; it builds, tests, validates, and publishes the ARM64 DMG and checksum as the latest GitHub Release.

## Configuration and packaging

Bindings are encoded as versioned JSON in `UserDefaults` under `hotkey.bindings.v1`. There are no external Swift package dependencies. Packaging requires `librsvg`; all other packaging and verification tools are provided by macOS. The legacy `~/.config/hotkey/config.toml` is intentionally never read, created, imported, watched, modified, or deleted. Packaging creates an unsigned and unnotarized menu-bar app with bundle identifier `com.hotkey.app`, minimum macOS 13, and `LSUIElement` enabled. Do not add signing credentials or configuration without an explicitly approved signing design.

## macOS constraints

- Global shortcuts use the legacy Carbon hot-key API. Keep Carbon flags and `EventHotKeyRef` values inside `CarbonHotkeyRegistrar`.
- UI and lifecycle operations use AppKit and must run on the main thread.
- Application matching and activation go through `NSWorkspace`; visible-window checks use Quartz window metadata.
- Avoid modal error alerts in a menu-bar utility. Errors should remain inspectable without blocking input.
- Registration tests must never reserve real global shortcuts, and application tests must never launch or hide real apps.

## Verification baseline

On 2026-08-17, the current Apple Silicon development environment passed `swift build` and all 53 XCTest cases. Release changes must also pass the DMG verification listed above on Apple Silicon. The tag workflow repeats those checks on the ARM64 `macos-26` runner before publication. Signing and notarization remain intentionally absent.
