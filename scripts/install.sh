#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
label="local.downloadwatch"
install_dir="$HOME/Library/Application Support/downloadwatch"
agent_path="$HOME/Library/LaunchAgents/$label.plist"
log_dir="$HOME/Library/Logs/downloadwatch"
cd "$project_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
mkdir -p "$install_dir" "$HOME/Library/LaunchAgents" "$log_dir"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
cp "$binary_dir/downloadwatch" "$install_dir/downloadwatch"
# plutil inserts paths without XML or shell interpolation hazards.
plutil -create xml1 "$agent_path"
plutil -insert Label -string "$label" "$agent_path"
plutil -insert ProgramArguments -array "$agent_path"
plutil -insert ProgramArguments.0 -string "$install_dir/downloadwatch" "$agent_path"
plutil -insert ProgramArguments.1 -string "$HOME/Downloads" "$agent_path"
plutil -insert RunAtLoad -bool YES "$agent_path"
plutil -insert KeepAlive -bool NO "$agent_path"
plutil -insert StandardErrorPath -string "$log_dir/watch.log" "$agent_path"
plutil -lint "$agent_path"
launchctl bootstrap "gui/$(id -u)" "$agent_path"
sleep 1
launchctl print "gui/$(id -u)/$label"
echo "Installed and started. Log: $log_dir/watch.log"
