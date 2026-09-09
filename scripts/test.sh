#!/bin/bash

set -euo pipefail

xcodebuild \
  -project AlertMe.xcodeproj \
  -scheme AlertMe \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  test

./scripts/test-install.sh
