#!/bin/bash

set -euo pipefail

marker=".build/capture-readme-screenshot"
result_bundle=".build/ReadmeScreenshot.xcresult"
attachments=".build/ReadmeScreenshotAttachments"
destination="docs/images/alert-me-main-window.png"

mkdir -p .build docs/images
rm -f "$marker"
rm -rf "$result_bundle" "$attachments"
touch "$marker"
trap 'rm -f "$marker"' EXIT

xcodebuild \
  -project AlertMe.xcodeproj \
  -scheme AlertMe \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  -resultBundlePath "$result_bundle" \
  test \
  -only-testing:AlertMeUITests/AlertMeUITests/testCapturesReadmeScreenshot

xcrun xcresulttool export attachments \
  --path "$result_bundle" \
  --output-path "$attachments"

screenshot_count="$(find "$attachments" -type f -name '*.png' -print | wc -l | tr -d ' ')"
if [[ "$screenshot_count" -ne 1 ]]; then
  echo "Expected one screenshot attachment, found $screenshot_count." >&2
  exit 1
fi

screenshot="$(find "$attachments" -type f -name '*.png' -print -quit)"
cp "$screenshot" "$destination"
echo "Saved $destination"
