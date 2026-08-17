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

Download the DMG and checksum from the [latest GitHub Release](https://github.com/nirum/hotkey/releases/latest). The published build supports Apple Silicon Macs and requires macOS 13 or later.

Verify both files are in the same directory, then run:

```sh
cd ~/Downloads
shasum -a 256 -c Hotkey-v0.1.0-arm64.dmg.sha256
```

Use the version you downloaded in place of `0.1.0`. Open the DMG and drag **Hotkey** to **Applications**.

Hotkey is currently unsigned and not notarized, so macOS cannot verify its developer and will block the first launch. After trying to open Hotkey once, open **System Settings → Privacy & Security**, find the message that Hotkey was blocked, and click **Open Anyway**. Authenticate if prompted, then confirm **Open**. Apple documents this process in [Open a Mac app from an unidentified developer](https://support.apple.com/guide/mac-help/mh40616/mac).

Only use **Open Anyway** when you trust the download. The checksum detects corruption or a changed DMG relative to the separately downloaded checksum, but it is not a developer signature and does not replace signing or notarization.

To build and install locally instead, install the packaging dependency and run:

```sh
brew install librsvg
make install
```

This creates an unsigned release app with development version `0.0.0` and replaces `~/Applications/Hotkey.app`.

## Configure shortcuts

1. Choose **Hotkey → Preferences…** or press `⌘,` while the menu is open.
2. Select **Add Shortcut**, choose a `.app` bundle, click the recorder, and press one shortcut chord.
3. Release the keys. Recording ends after the valid chord, so click **Save** or press Return to apply it.

Configured applications also appear above **Quit Hotkey** in the menu, in preference order. Click an application there to perform the same toggle as its global shortcut.

A shortcut must contain a keyboard key and at least one of Command, Option, or Control. Shift can supplement those modifiers but cannot be used alone. Duplicate shortcuts are rejected.

An invalid chord shows feedback without replacing the previous valid shortcut. Press Escape or move focus away to stop recording without changing that value.

Preferences are stored as versioned JSON data in `UserDefaults` under `hotkey.bindings.v1`. This is an intentional hard cutover from TOML: Hotkey never reads, creates, imports, watches, changes, or deletes `~/.config/hotkey/config.toml`.

If a new shortcut set cannot be completely registered or saved, Hotkey restores the last known-good set and keeps the rejected edit visible for correction.

## Build and test

```sh
swift build
swift test
```

Run the debug executable with `.build/debug/Hotkey`. Tests use fake registrars and application snapshots; they do not reserve global shortcuts or launch applications.

Create a local Apple Silicon DMG with:

```sh
brew install librsvg
make dmg VERSION=0.1.0 ARCH=arm64
```

The DMG and its SHA-256 checksum are written to `dist/`.

## Publish a release

Stable releases are published from annotated `vMAJOR.MINOR.PATCH` tags whose commits belong to `main`. For the first release:

```sh
git switch main
git pull --ff-only
git tag -a v0.1.0 -m "Hotkey v0.1.0"
git push origin v0.1.0
```

The release workflow builds and tests on an ARM64 `macos-26` runner, validates the app and DMG, and publishes both assets as the latest GitHub Release. It refuses invalid tags and existing releases instead of overwriting them. Choose a new semantic version if a tag or release already exists.

## Uninstall

```sh
make uninstall
```

This removes the installed app and its Launch at Login agent. Stored preferences and any legacy TOML file are left untouched.
