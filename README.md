# Hotkey

A lightweight macOS menu bar app that lets you toggle application visibility with global keyboard shortcuts. Define your shortcuts in a simple TOML config file.

- **Toggle apps** — if the app isn't running, launch it. If it's in the background, bring it to front. If it's focused, hide it.
- **Live reload** — edit your config and shortcuts update automatically, no restart needed.
- **Launch at Login** — toggle from the menu bar dropdown.

## Install

```
make install
```

This builds the app and copies `Hotkey.app` to `~/Applications/`.

## Configuration

Shortcuts are defined in `~/.config/hotkey/config.toml`:

```toml
[[hotkey]]
key = ";"
modifiers = ["control"]
app = "Ghostty"

[[hotkey]]
key = "b"
modifiers = ["option"]
app = "Safari"
```

Each `[[hotkey]]` entry maps a keyboard shortcut to an app name. The app name should match what you see in the macOS menu bar (e.g. "Ghostty", "Safari", "Slack"). Bundle identifiers like `com.mitchellh.ghostty` also work.

### Keys

Letters (`a`-`z`), numbers (`0`-`9`), function keys (`f1`-`f20`), and special keys:

`space` `return` `tab` `escape` `delete` `up` `down` `left` `right` `home` `end` `pageup` `pagedown`

Punctuation: `;` `.` `,` `/` `\` `'` `=` `-` `[` `]` `` ` ``

### Modifiers

`command` (or `cmd`), `option` (or `alt`), `control` (or `ctrl`), `shift`

## Build from source

```
swift build
.build/debug/Hotkey
```

## Uninstall

```
make uninstall
```

Removes the app and the Launch at Login agent.
