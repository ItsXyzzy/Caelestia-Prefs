#!/usr/bin/env bash
#
# Caelestia dashboard mods: uninstaller
#
# Restores the files the installer backed up and removes NotesTab.qml.
# Your saved notes are kept unless you pass --purge.
#
# Usage: ./uninstall.sh [--purge]
#
set -euo pipefail

XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$XDG_CONFIG/quickshell/caelestia"
NOTES_DATA="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/notes_tab.json"

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

if [ "$EUID" -eq 0 ]; then
    echo "Don't run this with sudo. It works on your user config."
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Nothing to uninstall: $TARGET doesn't exist."
    exit 0
fi

echo "Uninstalling Caelestia dashboard mods..."

restore() {
    local f="$TARGET/$1"
    if [ -f "$f.bak" ]; then
        mv "$f.bak" "$f"
        echo "  restored $1"
    fi
}

restore "modules/dashboard/Content.qml"
restore "modules/dashboard/WeatherTab.qml"
restore "modules/bar/popouts/Battery.qml"
restore "modules/drawers/ContentWindow.qml"

if [ -f "$TARGET/modules/dashboard/NotesTab.qml" ]; then
    rm -f "$TARGET/modules/dashboard/NotesTab.qml"
    echo "  removed NotesTab.qml"
fi

if [ -f "$NOTES_DATA" ]; then
    if [ "$PURGE" -eq 1 ]; then
        rm -f "$NOTES_DATA"
        echo "  deleted your saved notes"
    else
        echo "  kept your saved notes ($NOTES_DATA). Use --purge to delete them."
    fi
fi

echo
echo "Done. Restart the shell."
echo "Your user copy at $TARGET still overrides /etc/xdg/quickshell/caelestia."
echo "To let package updates apply again, delete it: rm -rf \"$TARGET\""
