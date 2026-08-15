<p align="center">
  <img src="logo.png" width="128" height="128" alt="Hotkey app icon">
</p>

# Hotkey

A lightweight macOS menu-bar app that toggles applications with global keyboard shortcuts.

- **Toggle apps** — launch or reopen an app with no windows, activate a background app, or hide the focused app.
- **Menu shortcuts** — open the menu and click any configured application to toggle it without using the keyboard.
- **Native Preferences** — add, edit, and remove shortcuts from a SwiftUI window; changes take effect immediately.
- **Reliable targeting** — selected apps are identified by bundle identifier first, with bundle URL and display-name fallbacks.
- **Visible errors** — registration and preferences failures appear in the menu bar, Preferences, and a non-modal details window.
- **Launch at Login** — toggle the launch agent from the menu-bar menu.

## Install

```sh
make install
```

This creates an unsigned release app and replaces `~/Applications/Hotkey.app`. Packaging requires ImageMagick's `magick` command.

## Configure shortcuts

1. Choose **Hotkey → Preferences…** or press `⌘,` while the menu is open.
2. Select **Add Shortcut**, choose a `.app` bundle, and record a shortcut.
3. Save. The complete shortcut set is validated and applied immediately.

Configured applications also appear above **Quit Hotkey** in the menu, in preference order. Click an application there to perform the same toggle as its global shortcut.

A shortcut must contain a keyboard key and at least one of Command, Option, or Control. Shift can supplement those modifiers but cannot be used alone. Duplicate shortcuts are rejected.

Preferences are stored as versioned JSON data in `UserDefaults` under `hotkey.bindings.v1`. This is an intentional hard cutover from TOML: Hotkey never reads, creates, imports, watches, changes, or deletes `~/.config/hotkey/config.toml`.

If a new shortcut set cannot be completely registered or saved, Hotkey restores the last known-good set and keeps the rejected edit visible for correction.

## Build and test

```sh
swift build
swift test
```

Run the debug executable with `.build/debug/Hotkey`. Tests use fake registrars and application snapshots; they do not reserve global shortcuts or launch applications.

## Uninstall

```sh
make uninstall
```

This removes the installed app and its Launch at Login agent. Stored preferences and any legacy TOML file are left untouched.
