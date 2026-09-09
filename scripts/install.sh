#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data_path="$repository_root/.build/DerivedData"
source_app="$derived_data_path/Build/Products/Release/AlertMe.app"
applications_directory="$HOME/Applications"
installed_app="$applications_directory/Alert Me.app"
launch_services_register="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

xcodebuild \
  -project "$repository_root/AlertMe.xcodeproj" \
  -scheme AlertMe \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  build

mkdir -p "$applications_directory"
/usr/bin/ditto "$source_app" "$installed_app"
"$launch_services_register" -f -R -trusted "$installed_app"
/usr/bin/touch "$installed_app"
/usr/bin/mdimport "$installed_app"

echo "Installed Alert Me at: $installed_app"
echo "Open Spotlight and search for: Alert Me"

if [[ "${1:-}" == "--open" ]]; then
  /usr/bin/open "$installed_app"
fi
