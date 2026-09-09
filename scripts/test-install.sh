#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d)"

cleanup() {
  if [[ -n "$temporary_directory" && -d "$temporary_directory" ]]; then
    rm -rf "$temporary_directory"
  fi
}
trap cleanup EXIT

fake_commands="$temporary_directory/bin"
derived_data="$temporary_directory/DerivedData"
applications_directory="$temporary_directory/Applications"
command_log="$temporary_directory/commands.log"
mkdir -p "$fake_commands"

cat > "$fake_commands/xcodebuild" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

derived_data=""
while (($#)); do
  if [[ "$1" == "-derivedDataPath" ]]; then
    derived_data="$2"
    shift 2
  else
    shift
  fi
done

test -n "$derived_data"
mkdir -p "$derived_data/Build/Products/Release/AlertMe.app"
printf 'built\n' > "$derived_data/Build/Products/Release/AlertMe.app/fixture.txt"
printf 'xcodebuild\n' >> "$COMMAND_LOG"
SCRIPT

cat > "$fake_commands/ditto" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
cp -R "$1" "$2"
printf 'ditto:%s\n' "$2" >> "$COMMAND_LOG"
SCRIPT

for command in lsregister touch mdimport open; do
  cat > "$fake_commands/$command" <<SCRIPT
#!/bin/bash
set -euo pipefail
printf '$command:%s\\n' "\${*: -1}" >> "\$COMMAND_LOG"
SCRIPT
done

chmod +x "$fake_commands"/*

COMMAND_LOG="$command_log" \
XCODEBUILD_COMMAND="$fake_commands/xcodebuild" \
DITTO_COMMAND="$fake_commands/ditto" \
LSREGISTER_COMMAND="$fake_commands/lsregister" \
TOUCH_COMMAND="$fake_commands/touch" \
MDIMPORT_COMMAND="$fake_commands/mdimport" \
OPEN_COMMAND="$fake_commands/open" \
ALERT_ME_DERIVED_DATA_PATH="$derived_data" \
ALERT_ME_APPLICATIONS_DIRECTORY="$applications_directory" \
  "$repository_root/scripts/install.sh" --open > /dev/null

installed_app="$applications_directory/Alert Me.app"
test -f "$installed_app/fixture.txt"
grep -Fx "xcodebuild" "$command_log" > /dev/null
grep -Fx "ditto:$installed_app" "$command_log" > /dev/null
grep -Fx "lsregister:$installed_app" "$command_log" > /dev/null
grep -Fx "touch:$installed_app" "$command_log" > /dev/null
grep -Fx "mdimport:$installed_app" "$command_log" > /dev/null
grep -Fx "open:$installed_app" "$command_log" > /dev/null
