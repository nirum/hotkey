# ARM64 DMG and GitHub Release Publishing

## Summary

Hotkey will publish reproducible, unsigned Apple Silicon releases from stable semantic-version tags. Pushing a tag such as `v0.1.0` from `main` will build and test the application, package a versioned DMG and SHA-256 checksum, validate both artifacts, and publish them as the latest GitHub Release with generated notes.

This release path is intentionally limited to Apple Silicon and GitHub Releases. Signing, notarization, universal binaries, automatic updates, Homebrew, the App Store, and ZIP distribution remain out of scope.

## Local packaging

The Makefile will accept `VERSION` and `ARCH` inputs, defaulting to `0.0.0` and the host architecture for local development. The app bundle will use `VERSION` for both `CFBundleShortVersionString` and `CFBundleVersion`.

The public packaging interface is:

```sh
make dmg VERSION=0.1.0 ARCH=arm64
```

It will produce:

- `dist/Hotkey-v0.1.0-arm64.dmg`
- `dist/Hotkey-v0.1.0-arm64.dmg.sha256`

The compressed DMG will contain `Hotkey.app` and an `Applications` symlink to `/Applications`. Packaging will check its required native tools, keep the app unsigned, and allow `make clean` to remove generated bundle, icon, staging, and `dist/` output.

## Release workflow

A dedicated GitHub Actions workflow will run only for pushed `v*` tags. Before building, it will require the exact `vMAJOR.MINOR.PATCH` format, reject an existing GitHub Release, and verify that the tagged commit is reachable from `main`.

The job will run on the ARM64 `macos-26` runner with only `contents: write` permission. It will install `librsvg`, then run `swift build`, `swift test`, and the DMG target using the version derived from the tag and `ARCH=arm64`.

Before publication, the workflow will verify:

- Both bundle version keys match the tag version.
- The packaged executable is ARM64-only.
- `hdiutil verify` accepts the DMG.
- A read-only mount contains `Hotkey.app` and an `Applications` symlink targeting `/Applications`.
- `shasum -a 256 -c` accepts the generated checksum.

If validation succeeds, `gh release create --verify-tag --generate-notes --latest` will publish the DMG and checksum. The workflow will fail if the tag or release state is not suitable and will never overwrite an existing release or asset.

## User and maintainer documentation

The README will link to the latest GitHub Release, identify the download as Apple Silicon-only and unsigned, document checksum verification, and explain macOS's Privacy & Security **Open Anyway** override with its security implications. It will also document the first release procedure: create an annotated `v0.1.0` tag on `main` and push that tag.

Repository guidance and the improvements tracker will describe the `librsvg` packaging dependency, the DMG command and validation steps, the tag-driven publication process, and the continuing absence of signing and notarization.

## Verification

Implementation is complete when the following pass on a suitable Apple Silicon Mac with a full Xcode toolchain:

```sh
swift build
swift test
make dmg VERSION=0.1.0 ARCH=arm64
```

The generated bundle versions and executable architecture must match the inputs. The DMG must pass `hdiutil verify`, mount read-only with the intended layout, and pass checksum verification. A final manual smoke test copies the app from the DMG, launches it, and exercises the menu and shortcuts.

After merge, pushing the first stable tag must create a latest GitHub Release containing exactly the versioned DMG and checksum assets. A final download test on Apple Silicon will confirm the documented checksum and Gatekeeper steps.

## Assumptions

- `v0.1.0` is the first public release and is published immediately as latest.
- GitHub is the only artifact host.
- Users explicitly accept the additional Gatekeeper warning associated with unsigned software.
- Developer ID signing and notarization are deferred until Apple Developer credentials are available.
