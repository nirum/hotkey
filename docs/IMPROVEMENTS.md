# Hotkey Improvements Tracker

This is the authoritative, sequential tracker for the native-preferences work. Status values are `Not started`, `In progress`, `Blocked`, and `Complete`. Change a task's status and add a newest-first progress entry in the same commit as its related work.

## 1. Add `AGENTS.md`

**Status:** Complete

Document architecture, layout, macOS support, SwiftPM commands, packaging, configuration, conventions, verification, and AppKit/Carbon constraints.

- [x] Add accurate root guidance.
- [x] Distinguish `swift build`, `swift test`, and `make install`.
- [x] Require later architecture and verification updates.
- [x] Record the project-local `.worktrees/` convention.

## 2. Replace TOML with Native Preferences

**Status:** Complete
**Depends on:** Task 1

- [x] Add a SwiftUI Preferences window with binding list, `.app` picker, and shortcut recorder.
- [x] Persist versioned JSON in `UserDefaults` under `hotkey.bindings.v1`.
- [x] Add `HotkeyBinding`, `AppTarget`, and app-defined Codable modifiers.
- [x] Remove TOMLKit, `ConfigManager`, parsing, creation, and watching.
- [x] Leave any existing TOML file untouched and show an empty state when appropriate.
- [x] Update `README.md` and `AGENTS.md`.

Acceptance: add, edit, and remove shortcuts without files; settings survive restart; selection is limited to `.app`; old TOML is untouched; the app builds without TOMLKit.

## 3. Add Automated Tests

**Status:** Complete
**Depends on:** Task 2

- [x] Isolate storage, registration, shortcut, validation, toggle, and preference-state policy behind small protocols.
- [x] Test serialization, schema handling, corrupt data, shortcut recording/display, validation, duplicates, registration paths, toggle decisions, CRUD, restart, and empty preferences.
- [x] Keep tests independent of real global shortcuts, app launches, and the user's defaults.

Acceptance: `swift test` is deterministic; platform adapters remain thin and receive manual smoke testing.

## 4. Add GitHub Actions CI

**Status:** Complete
**Depends on:** Task 3

- [x] Add push and pull-request CI on `macos-26`.
- [x] Use `actions/checkout@v7`, `contents: read`, and branch-scoped concurrency cancellation.
- [x] Run `swift build` followed by `swift test`; document the required check.

Acceptance: clean checkouts build and test; failures fail CI; no signing, deployment, or release work occurs.

## 5. Add Non-Modal Error UI

**Status:** Not started
**Depends on:** Tasks 2–3

- [ ] Share issues for preferences, validation, registration, and rollback failures.
- [ ] Show status-item warning state, menu summary/action, details window, and inline preference errors.
- [ ] Preserve last valid in-memory bindings after decoding failure and clear resolved errors after retry.

Acceptance: failures are visible and actionable without logs or modal alerts, identify bindings where possible, and state transitions are tested.

## 6. Enforce Modifier and Shortcut Validity

**Status:** Not started
**Depends on:** Tasks 3 and 5

- [ ] Centralize validation for recorder, persistence, and registration.
- [ ] Require Command, Option, or Control; permit Shift only as a supplement.
- [ ] Reject missing/modifier-only keys, unsupported bits, and duplicate combinations.
- [ ] Treat occupied/reserved combinations as registration failures.

Acceptance: invalid input has inline feedback and cannot be saved or applied; persisted data cannot bypass checks; all modifier cases are tested.

## 7. Make Bundle-Identifier Targeting Reliable

**Status:** Not started
**Depends on:** Tasks 2–3

- [ ] Match bundle identifier, canonical selected URL, then display name; prefer active matches.
- [ ] Resolve bundle identifiers through Launch Services before stored URLs.
- [ ] Preserve hide, activate, and reopen behavior across all match paths.

Acceptance: repeated toggles, moves/renames, identifier-less apps, and matching precedence are covered.

## 8. Apply Preference Changes Transactionally

**Status:** Not started
**Depends on:** Tasks 5–7

- [ ] Validate the complete proposed set before registration changes.
- [ ] Register all-or-rollback, then persist only a completely registered set.
- [ ] Keep rejected edits visible and active/persisted settings unchanged.
- [ ] Report cleanup or restoration failures distinctly.
- [ ] Apply successful CRUD without restart.

Acceptance: success, rejection, partial registration, persistence rollback, and rollback-failure paths are tested.

## Progress Log

- 2026-08-15 — Task 4 — Complete; added minimal push/PR CI with `macos-26`, `actions/checkout@v7`, read-only contents permission, superseded-run cancellation, and sequential build/test steps. Documented `Build and Test` as the required check.
- 2026-08-15 — Task 3 — Complete; added an XCTest suite plus a conditional Swift Testing fallback for Command Line Tools installations without XCTest. Ten fallback tests passed via `swift test`; no test touched Carbon, `NSWorkspace`, standard user defaults, or real applications.
- 2026-08-15 — Task 2 — Complete; replaced TOML with native SwiftUI Preferences and versioned `UserDefaults` JSON, removed TOMLKit and filesystem configuration behavior, and verified with `swift build`.
- 2026-08-15 — Task 1 — Complete; added repository guidance and the sequential tracker. Baseline `swift build` passed; baseline `swift test` reached the expected `no tests found` result. The earlier compiler/SDK patch mismatch did not reproduce in the isolated worktree.
