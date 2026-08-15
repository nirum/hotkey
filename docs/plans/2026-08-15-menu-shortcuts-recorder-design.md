# Menu Shortcut Items and Recorder Release Fix

## Goal

Make configured applications directly accessible from Hotkey's menu-bar menu and make shortcut recording reliably preserve the first valid chord after its keys are released.

The work ships as two stacked changes. The first adds menu shortcut items. The second builds on it and fixes the recorder lifecycle. Neither change alters persisted preferences, public API, shortcut validation, or Carbon registration.

## Menu shortcut items

The status menu gains a dynamic section immediately above Quit. Each active binding appears once, in preference order, with the application's color icon, display name, and shortcut. The section and its separator are omitted when there are no active bindings.

The menu is rebuilt immediately before it opens from `RegistrationCoordinator.activeBindings`. This makes successful add, edit, and delete operations visible on the next opening while rejected transactions continue to show the last known-good configuration.

A framework-independent mapper in `HotkeyCore` converts bindings to stable menu-entry values containing the binding ID, application identity and URL, display name, and shortcut presentation. Recognized hardware keys use AppKit's native key-equivalent column. Unknown legacy key codes retain a visible inline shortcut label so the menu never hides configured information.

AppKit resolves each icon through Launch Services by bundle identifier first, then uses the stored application URL. Selecting a menu row resolves the binding's current value by UUID and passes it to the existing `WindowManager.toggle(_:)` path used by registered global hotkeys. Missing or moved applications therefore retain the existing non-modal error behavior.

## Recorder lifecycle

Shortcut recording becomes a small framework-independent reducer. Its inputs distinguish key-down, modifier changes, repeated key events, Escape cancellation, and focus loss. Its state separates transient modifier feedback from the persisted draft shortcut.

Modifier presses and releases may change the recorder's live display, but do not write the editor draft. The first valid, non-repeating key-down atomically stores its hardware key code and modifiers, clears inline recording errors, refreshes the display, relinquishes focus, and ends recording. This restores Return to the editor's Save action before the user releases the captured chord.

Invalid chords leave the last valid draft unchanged, show inline feedback, and keep recording active. Repeated key-down events are ignored. Escape and focus loss stop recording without changing the last valid value. Saving after release therefore always sends the accepted key and modifiers through the existing transactional registration coordinator.

## Testing and release shape

Core menu tests cover empty input, stable identity and presentation, preference ordering, and snapshots after active bindings are edited or removed. Core recorder tests cover modifier release after capture, save-ready accepted state, ignored repeats, invalid attempts preserving a prior shortcut, cancellation, focus loss, and one-shot completion.

Both branches must pass `swift build` and `swift test`. Manual macOS smoke testing covers menu icons and alignment, mouse activation, live menu refresh, light/dark appearance, missing-application errors, and saving a recorded shortcut with both mouse and Return.
