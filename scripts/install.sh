#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data_path="${ALERT_ME_DERIVED_DATA_PATH:-$repository_root/.build/DerivedData}"
source_app="$derived_data_path/Build/Products/Release/AlertMe.app"
applications_directory="${ALERT_ME_APPLICATIONS_DIRECTORY:-$HOME/Applications}"
installed_app="$applications_directory/Alert Me.app"
xcodebuild_command="${XCODEBUILD_COMMAND:-xcodebuild}"
ditto_command="${DITTO_COMMAND:-/usr/bin/ditto}"
launch_services_register="${LSREGISTER_COMMAND:-/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister}"
touch_command="${TOUCH_COMMAND:-/usr/bin/touch}"
mdimport_command="${MDIMPORT_COMMAND:-/usr/bin/mdimport}"
open_command="${OPEN_COMMAND:-/usr/bin/open}"

"$xcodebuild_command" \
  -project "$repository_root/AlertMe.xcodeproj" \
  -scheme AlertMe \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  build

mkdir -p "$applications_directory"
"$ditto_command" "$source_app" "$installed_app"
"$launch_services_register" -f -R -trusted "$installed_app"
"$touch_command" "$installed_app"
"$mdimport_command" "$installed_app"

echo "Installed Alert Me at: $installed_app"
echo "Open Spotlight and search for: Alert Me"

if [[ "${1:-}" == "--open" ]]; then
  "$open_command" "$installed_app"
fi
