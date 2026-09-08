# Changelog

## 0.2.0

- Remove debug maps, local symbols, and build-machine toolchain search paths
  before signing the release binary.
- Package only `downloadwatch` and `LICENSE`, without macOS metadata files.
- Reject release archives with extra files, ZIP metadata, or local build paths.
- Require signing identity and notarization profile through environment variables.
  Remove machine-specific defaults from the release script.
- Keep the ARM64 target, Developer ID signature, Apple notarization, and existing
  download detection behavior.

## 0.1.0

Initial release with native clipboard file references, Homebrew service support,
and a signed and notarized Apple Silicon binary.
