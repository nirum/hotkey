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

**Status:** Complete
**Depends on:** Tasks 2–3

- [x] Share issues for preferences, validation, registration, and rollback failures.
- [x] Show status-item warning state, menu summary/action, details window, and inline preference errors.
- [x] Preserve last valid in-memory bindings after decoding failure and clear resolved errors after retry.

Acceptance: failures are visible and actionable without logs or modal alerts, identify bindings where possible, and state transitions are tested.

## 6. Enforce Modifier and Shortcut Validity

**Status:** Complete
**Depends on:** Tasks 3 and 5

- [x] Centralize validation for recorder, persistence, and registration.
- [x] Require Command, Option, or Control; permit Shift only as a supplement.
- [x] Reject missing/modifier-only keys, unsupported bits, and duplicate combinations.
- [x] Treat occupied/reserved combinations as registration failures.

Acceptance: invalid input has inline feedback and cannot be saved or applied; persisted data cannot bypass checks; all modifier cases are tested.

## 7. Make Bundle-Identifier Targeting Reliable

**Status:** Complete
**Depends on:** Tasks 2–3

- [x] Match bundle identifier, canonical selected URL, then display name; prefer active matches.
- [x] Resolve bundle identifiers through Launch Services before stored URLs.
- [x] Preserve hide, activate, and reopen behavior across all match paths.

Acceptance: repeated toggles, moves/renames, identifier-less apps, and matching precedence are covered.

## 8. Apply Preference Changes Transactionally

**Status:** Complete
**Depends on:** Tasks 5–7

- [x] Validate the complete proposed set before registration changes.
- [x] Register all-or-rollback, then persist only a completely registered set.
- [x] Keep rejected edits visible and active/persisted settings unchanged.
- [x] Report cleanup or restoration failures distinctly.
- [x] Apply successful CRUD without restart.

Acceptance: success, rejection, partial registration, persistence rollback, and rollback-failure paths are tested.

## 9. Add Configured Applications to the Menu

**Status:** Complete
**Depends on:** Task 8

- [x] Rebuild configured application rows from the active binding set before the menu opens.
- [x] Preserve preference order and show native shortcut equivalents with a legacy-key fallback.
- [x] Resolve color icons by bundle identifier before the stored URL.
- [x] Route mouse selection through the existing application toggle path.
- [x] Omit the section and its extra separator when no active bindings exist.

Acceptance: the next menu opening reflects successful add, edit, and delete operations while rejected edits remain absent; deterministic mapper tests cover identity, ordering, labels, and empty state.

## 10. Preserve One-Shot Shortcut Recording

**Status:** Complete
**Depends on:** Tasks 6 and 8

- [x] Reduce recorder key, modifier, repeat, cancellation, and focus events independently of AppKit.
- [x] Accept the first valid non-repeating chord atomically and end recording immediately.
- [x] Keep modifier feedback transient so key release cannot overwrite the draft.
- [x] Preserve the last valid shortcut after invalid input, Escape, or focus loss.
- [x] Relinquish focus after capture so Return resumes the Save action.

Acceptance: release events preserve the accepted chord; invalid and repeated events cannot replace it; mouse Save and Return Save both receive the accepted draft.

## 11. Publish ARM64 GitHub Releases

**Status:** Complete
**Depends on:** Tasks 4 and 10

- [x] Add version and architecture inputs to unsigned app packaging and inject both bundle version keys.
- [x] Create a compressed ARM64 DMG containing `Hotkey.app` and an `/Applications` symlink.
- [x] Generate a stable, versioned SHA-256 checksum beside the DMG in `dist/`.
- [x] Add tag-driven publication for annotated `vMAJOR.MINOR.PATCH` tags whose commits belong to `main`.
- [x] Build, test, and validate bundle metadata, ARM64 architecture, DMG integrity/layout, and checksum before publication.
- [x] Publish the DMG and checksum as the latest GitHub Release without signing, notarization, or overwrite behavior.
- [x] Document Apple Silicon support, checksum verification, Gatekeeper override risks, `librsvg`, and the maintainer release command.

Acceptance: `make dmg VERSION=0.1.0 ARCH=arm64` produces the named DMG and checksum; local validation passes; pushing a new annotated stable tag from `main` publishes both assets only after the ARM64 release job passes.

## Progress Log

- 2026-08-17 — Task 11 — Complete; added unsigned versioned ARM64 DMG packaging, SHA-256 generation, full artifact validation, and latest-release publication from annotated stable tags on `main`. Packaging uses `librsvg`; signing and notarization remain future work.
- 2026-08-17 — Verification — `swift build` and all 53 XCTest cases pass with the current Apple Silicon toolchain. The ARM64 DMG, bundle metadata, executable slice, mounted app/Applications layout, and generated checksum pass local validation.
- 2026-08-15 — Task 10 — Complete; shortcut recording now accepts one valid chord, updates the draft atomically, ends recording before release events, preserves valid values across invalid input and cancellation, and restores Return to Save.
- 2026-08-15 — Task 9 — Complete; configured applications now appear in preference order above Quit with color icons and native shortcut equivalents, mouse selection uses the existing toggle path, and rejected edits remain excluded by reading the active coordinator snapshot.
- 2026-08-15 — Verification — All eight tasks are complete. `swift build` passes; all committed XCTest sources type-check against the built `HotkeyCore` module. Local `swift test` stops because the standalone Command Line Tools omit XCTest, so execution is delegated to the documented full-Xcode `macos-26` CI check.
- 2026-08-15 — Task 8 — Complete; preference changes now validate, swap registrations, persist, and commit as one transaction; rejected edits retain known-good state. Tests cover success, validation rejection, partial registration, persistence rollback, cleanup failure, restoration failure, and temporary-unregister failure.
- 2026-08-15 — Task 7 — Complete; implemented bundle-ID, canonical URL, and display-name matching precedence, active-instance preference, Launch Services resolution, and injected workspace/window decision providers with tests.
- 2026-08-15 — Task 6 — Complete; centralized shortcut rules across recorder and model validation, rejected invalid/missing/duplicate input before Carbon, and covered primary modifiers, Shift, invalid bits, missing keys, and duplicates.
- 2026-08-15 — Task 5 — Complete; added shared issue state, warning menu-bar presentation, summaries, a non-modal timestamped details window, inline binding errors, last-known-good preservation, and tested resolution transitions.
- 2026-08-15 — Task 4 — Complete; added minimal push/PR CI with `macos-26`, `actions/checkout@v7`, read-only contents permission, superseded-run cancellation, and sequential build/test steps. Documented `Build and Test` as the required check.
- 2026-08-15 — Task 3 — Complete; added a deterministic XCTest suite. The installed standalone Command Line Tools omit XCTest, so a temporary Swift Testing harness exercised all final core scenarios locally; the committed CI/full-Xcode path remains XCTest. No test touches Carbon, `NSWorkspace`, standard user defaults, or real applications.
- 2026-08-15 — Task 2 — Complete; replaced TOML with native SwiftUI Preferences and versioned `UserDefaults` JSON, removed TOMLKit and filesystem configuration behavior, and verified with `swift build`.
- 2026-08-15 — Task 1 — Complete; added repository guidance and the sequential tracker. Baseline `swift build` passed; baseline `swift test` reached the expected `no tests found` result. The earlier compiler/SDK patch mismatch did not reproduce in the isolated worktree.
