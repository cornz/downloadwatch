# Release 0.1.0 verification

Verified on 2026-09-08, Apple Silicon, macOS 26.6.2, Swift 6.3.3.

- Release build and all four XCTest integration tests passed locally.
- GitHub Actions build and tests passed on the macOS 15 runner.
- Mach-O inspection confirms ARM64 and a macOS 13.0 deployment target. This does
  not establish runtime compatibility with macOS 13 or Intel.
- Developer ID signature uses hardened runtime and a secure timestamp.
- Apple accepted notarization submission `3984908f-edd1-4d85-a811-0e1e33b4150c`.
- ZIP extraction and Homebrew installation preserve the executable byte for byte.
- The installed executable passed `codesign --verify --strict` and an explicit
  requirement for the expected Apple team and notarization.
- Homebrew formula style, strict audit, and formula tests passed.
- A real HTTPS download to `~/Downloads`, first stored with a `.part` suffix, was
  copied as a native file URL by the signed foreground executable.
- A real HTTPS download in a temporary folder also passed the native clipboard
  check with the Homebrew background service.
- Homebrew service registration, start, and stop passed. The generated LaunchAgent
  has `RunAtLoad` and no `KeepAlive` restart loop.

The background download-to-clipboard check is pending. While the Mac was locked,
the service stayed blocked in `open()` during startup and produced no log output.
A Downloads permission prompt could not be inspected on the locked screen. Unlock
the Mac, resolve the macOS access prompt, then repeat the download test with the
Homebrew service. Do not treat the foreground result as proof of background access.

The two-second completion rule remains a heuristic. Candidate polling avoids full
folder scans, but directory events and batched FSEvents can still cause repeated
full scans in a busy folder. No new idle CPU benchmark was performed for this
release after adding FSEvents.
