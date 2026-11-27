#!/bin/bash
# Double-click uninstaller for Mod Loader for MacOS.
# This is a readable shell script, not an .app. It runs uninstall.sh next to it.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)

echo "Uninstall Mod Loader for MacOS"
echo "=============================="
echo

if [ ! -f "$HERE/uninstall.sh" ]; then
    echo "Error: uninstall.sh was not found next to this file."
    echo "Unzip the whole package and run this again."
    echo
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

bash "$HERE/uninstall.sh" "$@"
status=$?

echo
if [ "$status" -eq 0 ]; then
    echo "Uninstall finished."
else
    echo "Uninstall failed. Read the messages above."
fi
echo
read -n 1 -s -r -p "Press any key to close..."
exit "$status"
