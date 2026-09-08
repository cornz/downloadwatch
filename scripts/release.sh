#!/bin/bash
# Run on the signing Mac. Credentials remain in the macOS Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?Usage: scripts/release.sh VERSION}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
[[ "$(uname -m)" == arm64 ]] || { echo 'Release validation requires Apple Silicon.' >&2; exit 1; }
identity="${SIGNING_IDENTITY:-Developer ID Application: Cornelius Tom Christian Putzler (3Z55A24KS4)}"
profile="${NOTARY_PROFILE:-TrimWM-notary}"
output="$PWD/dist/$version"
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 1; }
swift test
swift build -c release --arch arm64
binary_dir="$(swift build -c release --arch arm64 --show-bin-path)"
[[ "$("$binary_dir/downloadwatch" --version)" == "downloadwatch $version" ]]
mkdir -p "$output/stage"
cp "$binary_dir/downloadwatch" "$output/stage/downloadwatch"
cp LICENSE "$output/stage/LICENSE"
codesign --force --options runtime --timestamp --identifier com.cornz.downloadwatch \
  --sign "$identity" "$output/stage/downloadwatch"
codesign --verify --strict --verbose=2 "$output/stage/downloadwatch"
archive="$output/downloadwatch-$version-macos-arm64.zip"
ditto -c -k "$output/stage" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$profile" --wait \
  --output-format json > "$output/notarization.json"
python3 - "$output/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get("status") != "Accepted":
    raise SystemExit("Notarization was not accepted. Inspect the submission log.")
print("Notarization accepted:", result["id"])
PY
mkdir "$output/verify"
ditto -x -k "$archive" "$output/verify"
cmp "$output/stage/downloadwatch" "$output/verify/downloadwatch"
codesign --verify --strict --verbose=2 "$output/verify/downloadwatch"
(cd "$output" && shasum -a 256 "$(basename "$archive")" > SHA256SUMS)
echo "Verified release: $archive"
