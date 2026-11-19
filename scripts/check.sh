#!/bin/bash
set -euo pipefail
SPOT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${DEVELOPER_DIR:-}" ]; then
  for SPOT_XCODE in /Applications/Xcode.app "$HOME/Downloads/Xcode.app"; do
    if [ -d "$SPOT_XCODE/Contents/Developer" ]; then
      export DEVELOPER_DIR="$SPOT_XCODE/Contents/Developer"
      break
    fi
  done
fi
swift test --package-path "$SPOT_ROOT/ios"
xcodebuild -quiet -project "$SPOT_ROOT/ios/SpotClicker.xcodeproj" -scheme SpotClicker \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$SPOT_ROOT/build/DerivedData" CODE_SIGNING_ALLOWED=NO build
