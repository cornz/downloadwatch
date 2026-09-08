#!/bin/bash
set -euo pipefail
label="local.downloadwatch"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$label.plist"
rm -f "$HOME/Library/Application Support/downloadwatch/downloadwatch"
rmdir "$HOME/Library/Application Support/downloadwatch" 2>/dev/null || true
echo "Stopped and uninstalled. Source files, downloads and logs retained."
