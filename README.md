# downloadwatch

A small native macOS tool that puts new or changed downloads on the clipboard as
file references, like copying a file in Finder. Each completed file replaces the
clipboard. It uses Swift and AppKit, with no external packages.

## Install with Homebrew

```sh
brew install cornz/tap/downloadwatch
brew services start downloadwatch
```

Run these commands as your logged-in user, without `sudo`. Homebrew manages the
binary and LaunchAgent. The service starts at login and watches `~/Downloads`.
Do not run the manual installer for a Homebrew installation.

```sh
brew services info downloadwatch
brew services stop downloadwatch
brew uninstall downloadwatch
```

Release 0.2.0 provides a Developer-ID-signed, Apple-notarized ARM64 binary for
Apple Silicon. The binary targets macOS 13 or later. Runtime verification was
performed on macOS 26.6.2 with Apple Silicon. macOS 13 and Intel Macs have not been
runtime-tested. No Intel binary is published.

Background operation has been tested with a temporary folder. Background access
to `~/Downloads` is not yet verified. See the
[verification report](docs/verification-0.2.0.md) for test coverage.

To update an existing installation:

```sh
brew update
brew upgrade cornz/tap/downloadwatch
```

If the service was running, restart it with `brew services restart downloadwatch`.

## Use

```sh
downloadwatch                         # Watch ~/Downloads
downloadwatch ~/Desktop/TestDownloads # Watch another directory
downloadwatch --help
downloadwatch --version
```

Stop a foreground process with Ctrl-C. Use only one watcher for each folder.
macOS may ask for access to Downloads. If access is denied, check **System Settings
→ Privacy & Security → Files & Folders**. Permissions for a terminal process and a
background service can differ. After fixing access, run
`brew services restart downloadwatch`.

The service does not restart repeatedly after a failure. It starts again at the
next login or when you restart it. Check its log with:

```sh
tail -f "$(brew --prefix)/var/log/downloadwatch.log"
```

Logs contain file names and are not rotated automatically.

## Behavior and limits

- Files present at startup are ignored until they change.
- Only files directly in the watched folder are considered.
- Hidden files, symlinks, folders, and files ending in `.crdownload`, `.part`,
  `.download`, `.tmp`, or `.temp` are ignored.
- A final file waits while a matching `.part`, `.crdownload`, or `.download`
  companion exists. Renaming a temporary file to its final name is detected.
- Size and modification time must stay stable for at least two seconds. This is
  a completion heuristic. A writer that pauses longer can cause an early copy.
  Later changes can trigger another copy.
- Files added or changed by other apps also trigger a copy.
- The clipboard contains a native file reference, not a path string or a backup.
  Moving or deleting the file can prevent pasting it later.
- Several completions are copied in sequence. The last one remains on the
  clipboard. Ties use modification time, then file path.
- Directory events and batched FSEvents detect changes and scan the folder.
  While files are pending, timer ticks inspect only those candidates every 250 ms. There is no periodic scan while idle.
  Frequent directory events can still cause repeated full scans in busy folders.
- If the watched folder disappears or becomes unreadable, the tool exits.

## Build and test

Building requires Xcode Command Line Tools. The package requires Swift 5.9 or
later; the verified release build used Swift 6.3.3. The installed binary does not require a Swift install.

```sh
swift build -c release
swift test
.build/release/downloadwatch
```

Integration tests use temporary folders and a separate named pasteboard. They do
not overwrite your personal clipboard. GitHub Actions runs the build and tests.

## Manual installation

For a source build without Homebrew:

```sh
./scripts/install.sh
./scripts/uninstall.sh
```

The installer builds locally and installs the binary under
`~/Library/Application Support/downloadwatch`. It creates the user LaunchAgent
`local.downloadwatch` and logs to `~/Library/Logs/downloadwatch/watch.log`.
It starts at login but does not retry persistent errors. This locally built binary
is not the signed release. The uninstaller keeps source files, downloads, and logs.

## Release process

Release builds require an Apple Silicon Mac, Xcode tools, Python 3, a Developer ID
Application certificate, and a notarytool Keychain profile. Signing keys and
notarization credentials stay in the Keychain. GitHub Actions only builds and tests.

1. Update the version in `Sources/downloadwatch/main.swift` and this README.
2. Set `SIGNING_IDENTITY` to your Developer ID Application identity and
   `NOTARY_PROFILE` to your notarytool Keychain profile, then run
   `scripts/release.sh 0.2.0`. No personal signing defaults are stored in the repo.
   The script tests and builds ARM64. It removes debug maps, local symbols, and
   toolchain paths from the build Mac before signing with hardened runtime and a
   secure timestamp. It creates a ZIP containing only
   the executable and license, checks for local build paths and extra metadata,
   notarizes the ZIP, and verifies the extracted binary without changing it.
3. Update `packaging/downloadwatch.rb` with the version and archive SHA-256.
   Commit the source and tag it as `v0.2.0`. Publish only the ZIP and `SHA256SUMS`
   from `dist/0.2.0` in the matching GitHub release.
4. Copy the formula to a local checkout of
   [cornz/homebrew-tap](https://github.com/cornz/homebrew-tap). Test installation,
   signature, and service, then publish the updated tap.

The formula copies the signed binary without stripping or patching it. Its
`skip_clean` declaration protects the binary during Homebrew cleanup. Compare the
installed binary with the archive and run `codesign --verify --strict` after any
packaging change. A ZIP and a standalone executable cannot carry a stapled ticket;
Gatekeeper uses Apple's online notarization record when needed.

## License

[MIT](LICENSE)
