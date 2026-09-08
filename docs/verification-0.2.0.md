# Release 0.2.0 verification

Verified on 2026-09-08, Apple Silicon, macOS 26.6.2, Swift 6.3.3.

- Release build and all four XCTest integration tests passed.
- Debug maps, local symbols, and the Xcode toolchain search path were removed
  before signing. Only portable runtime search paths remain.
- The release ZIP contains exactly `downloadwatch` and `LICENSE`.
- Archive inspection found no AppleDouble entries, extra ZIP metadata, or local
  build paths in the executable.
- The archive check also rejected test archives with extra files or local paths.
- Apple accepted notarization submission `af1d077c-1732-46e9-bc12-7229fd5f90dc`.
- The extracted executable matches the signed executable byte for byte and passes
  strict code-signature verification.
- Signing identity and Keychain profile are required environment variables.
  The release script contains no personal defaults or credentials.

The Developer ID certificate identifies the publisher. Its public certificate
information is part of the required signature. It is not a private signing key.
The MIT license retains its copyright notice.

The binary targets ARM64 and macOS 13 or later. macOS 13 and Intel execution have
not been tested. Download detection is unchanged from 0.1.0, including the
completion heuristic and the pending background Downloads access check described
in the [previous report](verification-0.1.0.md).
