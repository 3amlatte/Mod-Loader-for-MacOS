#!/bin/bash
# Double-click installer for Mod Loader for MacOS.
# This is a readable shell script, not an .app. It runs install.sh next to it.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)

echo "Mod Loader for MacOS"
echo "===================="
echo

if [ ! -f "$HERE/install.sh" ]; then
    echo "Error: install.sh was not found next to this file."
    echo "Unzip the whole package and run this again."
    echo
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

bash "$HERE/install.sh" "$@"
status=$?

echo
if [ "$status" -eq 0 ]; then
    echo "Install finished. Start Melvor Idle 2 from Steam."
else
    echo "Install failed. Read the messages above."
fi
echo
read -n 1 -s -r -p "Press any key to close..."
exit "$status"
