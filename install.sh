#!/usr/bin/env bash
#
# Caelestia dashboard mods: installer
#
# Installs into your user config (~/.config/quickshell/caelestia). No sudo needed,
# and package updates won't overwrite it.
#
# Usage: ./install.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="${CAELESTIA_SYSTEM_DIR:-/etc/xdg/quickshell/caelestia}"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$XDG_CONFIG/quickshell/caelestia"
SRC="$SCRIPT_DIR/qml/modules"

CONTENT="$TARGET/modules/dashboard/Content.qml"
WINDOW="$TARGET/modules/drawers/ContentWindow.qml"
NOTES="$TARGET/modules/dashboard/NotesTab.qml"
WEATHER="$TARGET/modules/dashboard/WeatherTab.qml"
BATTERY="$TARGET/modules/bar/popouts/Battery.qml"
WEATHER_SERVICE="$TARGET/services/Weather.qml"

ok()   { echo "  ok:   $*"; }
warn() { echo "  warn: $*" >&2; }

# Only the first backup is kept, so running the installer twice never overwrites the original.
backup() {
    if [ -f "$1" ] && [ ! -f "$1.bak" ]; then
        cp "$1" "$1.bak"
    fi
}

if [ "$EUID" -eq 0 ]; then
    echo "Don't run this with sudo. It installs into your user config."
    exit 1
fi

# Check everything before writing anything.
if [ -d "$TARGET" ]; then ROOT="$TARGET"; else ROOT="$SYSTEM_DIR"; fi

if [ ! -f "$ROOT/modules/dashboard/Content.qml" ] || [ ! -f "$ROOT/modules/drawers/ContentWindow.qml" ]; then
    echo "Couldn't find Caelestia under $ROOT."
    echo "Install caelestia-shell first, or set CAELESTIA_SYSTEM_DIR."
    exit 1
fi

if ! grep -q "notesComponent" "$ROOT/modules/dashboard/Content.qml" \
   && ! grep -q "component: weatherComponent," "$ROOT/modules/dashboard/Content.qml"; then
    echo "Your Content.qml has no Weather dashboard tab, which this mod hooks into."
    echo "Nothing was changed."
    exit 1
fi

echo "Installing Caelestia dashboard mods..."

# A user copy takes priority over /etc/xdg and survives package updates.
if [ ! -d "$TARGET" ]; then
    echo "-> Copying $SYSTEM_DIR to $TARGET"
    mkdir -p "$XDG_CONFIG/quickshell"
    cp -r "$SYSTEM_DIR" "$TARGET"
fi

echo "-> Notes tab"
cp "$SRC/dashboard/NotesTab.qml" "$NOTES"
if grep -q "notesComponent" "$CONTENT"; then
    ok "already registered in Content.qml"
else
    backup "$CONTENT"
    rc=0
    python3 - "$CONTENT" <<'PY' || rc=$?
import re, sys

path = sys.argv[1]
src = open(path).read()

# Component block, placed after the weather one (matching its indentation).
m = re.search(r'^([ ]*)Component\s*\{\n[ ]*id:\s*weatherComponent.*?\n\1\}', src, re.DOTALL | re.MULTILINE)
if not m:
    sys.exit(2)
ind = m.group(1)
comp = ("\n\n" + ind + "Component {\n" + ind + "    id: notesComponent\n\n"
        + ind + "    NotesTab {}\n" + ind + "}")
src = src[:m.end()] + comp + src[m.end():]

# Tab entry, placed after the weather entry.
m = re.search(r'^([ ]*)\{\n[ ]*component:\s*weatherComponent,.*?\n\1\}', src, re.DOTALL | re.MULTILINE)
if not m:
    sys.exit(3)
ind = m.group(1)
entry = (",\n" + ind + "{\n"
         + ind + "    component: notesComponent,\n"
         + ind + '    iconName: "sticky_note_2",\n'
         + ind + '    text: Tr.tr("Notes"),\n'
         + ind + "    enabled: true\n"
         + ind + "}")
src = src[:m.end()] + entry + src[m.end():]

open(path, "w").write(src)
PY
    if [ "$rc" -ne 0 ] || ! grep -q "notesComponent" "$CONTENT"; then
        rm -f "$NOTES"
        echo "Couldn't register the Notes tab: your Content.qml doesn't match what this expects."
        echo "Content.qml was not changed. See 'Manual install' in the README."
        exit 1
    fi
    ok "registered in Content.qml"
fi

echo "-> Weather tab (hourly forecast)"
if [ ! -f "$WEATHER" ]; then
    warn "WeatherTab.qml not found, skipping"
elif ! grep -q "hourlyForecast" "$WEATHER_SERVICE" 2>/dev/null; then
    warn "your Weather service has no hourlyForecast, skipping"
else
    backup "$WEATHER"
    cp "$SRC/dashboard/WeatherTab.qml" "$WEATHER"
    ok "WeatherTab.qml"
fi

echo "-> Battery popout"
if [ ! -f "$BATTERY" ]; then
    warn "Battery.qml not found, skipping"
else
    backup "$BATTERY"
    cp "$SRC/bar/popouts/Battery.qml" "$BATTERY"
    ok "Battery.qml"
fi

# Without this, typing in the notes editor goes to whichever window had focus before.
echo "-> Keyboard focus for the dashboard"
if grep -q "screenState.session || screenState.dashboard" "$WINDOW" \
   || grep -Eq "(keyboardFocus|wantsKeyboard).*dashboard" "$WINDOW"; then
    ok "dashboard already takes keyboard focus"
else
    backup "$WINDOW"
    sed -i 's/screenState\.launcher || screenState\.session ? WlrKeyboardFocus\.OnDemand/screenState.launcher || screenState.session || screenState.dashboard ? WlrKeyboardFocus.OnDemand/' "$WINDOW"
    if grep -q "screenState.session || screenState.dashboard" "$WINDOW"; then
        ok "ContentWindow.qml patched"
    else
        warn "couldn't patch ContentWindow.qml. The Notes tab will show but typing won't reach it."
        warn "See 'Manual install' in the README for the one-line change."
    fi
fi

echo
echo "Done. Restart the shell (log out and back in, or stop it and run 'caelestia shell')."
echo "To undo everything: ./uninstall.sh"
