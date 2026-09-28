#!/usr/bin/env bash
#
# Caelestia Notes Tab uninstaller
#
# Restores the files the installer backed up and removes NotesTab.qml.
# Your saved notes (~/.local/state/caelestia/notes_tab.json) are kept unless
# you pass --purge.
#
# Usage:  ./uninstall.sh [--purge]
#
set -euo pipefail

XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$XDG_CONFIG/quickshell/caelestia"
NOTES_DATA="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/notes_tab.json"

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this with sudo. It works on your user config."
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Nothing to uninstall: $TARGET does not exist."
    exit 0
fi

echo "Uninstalling Caelestia Notes Tab..."

restore() {
    local f="$TARGET/$1"
    if [ -f "$f.bak" ]; then
        mv "$f.bak" "$f"
        echo "  Restored $1"
    else
        echo "  No backup for $1, leaving it as is"
    fi
}

restore "modules/dashboard/Content.qml"
restore "modules/drawers/ContentWindow.qml"
restore "modules/bar/popouts/Battery.qml"

if [ -f "$TARGET/modules/dashboard/NotesTab.qml" ]; then
    rm -f "$TARGET/modules/dashboard/NotesTab.qml"
    echo "  Removed NotesTab.qml"
fi

if [ "$PURGE" -eq 1 ]; then
    if [ -f "$NOTES_DATA" ]; then
        rm -f "$NOTES_DATA"
        echo "  Deleted saved notes ($NOTES_DATA)"
    fi
else
    if [ -f "$NOTES_DATA" ]; then
        echo "  Kept your saved notes at $NOTES_DATA (use --purge to delete)"
    fi
fi

echo
echo "Done. Restart the shell to apply."
echo
echo "Note: the user copy at $TARGET still overrides /etc/xdg/quickshell/caelestia."
echo "If you want package updates to apply again, remove it:"
echo "    rm -rf \"$TARGET\""
