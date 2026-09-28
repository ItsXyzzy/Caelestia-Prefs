#!/usr/bin/env bash
#
# Caelestia Notes Tab installer
#
# Installs into your USER config (~/.config/quickshell/caelestia), never into
# /etc or /usr, so it needs no sudo and survives package updates.
#
# Usage:  ./install.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="${CAELESTIA_SYSTEM_DIR:-/etc/xdg/quickshell/caelestia}"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$XDG_CONFIG/quickshell/caelestia"

DASH="$TARGET/modules/dashboard"
CONTENT="$DASH/Content.qml"
WINDOW="$TARGET/modules/drawers/ContentWindow.qml"
BATTERY="$TARGET/modules/bar/popouts/Battery.qml"
NOTES="$DASH/NotesTab.qml"

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this with sudo. It installs into your user config."
    exit 1
fi

warn() { echo "  WARN: $*" >&2; }
ok()   { echo "  OK:   $*"; }

backup() {
    # Keep the FIRST backup only, so re-running never overwrites the pristine original.
    if [ -f "$1" ] && [ ! -f "$1.bak" ]; then
        cp "$1" "$1.bak"
        ok "backed up $(basename "$1") -> $(basename "$1").bak"
    fi
}

echo "Installing Caelestia Notes Tab..."

# --- 0. Pre-flight: verify compatibility before touching anything -------------
if [ -d "$TARGET" ]; then
    SOURCE_ROOT="$TARGET"
else
    SOURCE_ROOT="$SYSTEM_DIR"
fi

if [ ! -f "$SOURCE_ROOT/modules/dashboard/Content.qml" ] || [ ! -f "$SOURCE_ROOT/modules/drawers/ContentWindow.qml" ]; then
    echo "Could not find Caelestia's dashboard files under $SOURCE_ROOT."
    echo "Install caelestia-shell first, or set CAELESTIA_SYSTEM_DIR / XDG_CONFIG_HOME."
    exit 1
fi

if ! grep -q "notesComponent" "$SOURCE_ROOT/modules/dashboard/Content.qml" \
   && ! grep -q "component: weatherComponent," "$SOURCE_ROOT/modules/dashboard/Content.qml"; then
    echo "Your Content.qml has no Weather dashboard tab, which this mod uses as its anchor."
    echo "It was written for a Caelestia version that ships the Weather tab."
    echo "Nothing was changed."
    exit 1
fi

# --- 1. Make sure a user-level copy of the shell exists -----------------------
if [ ! -d "$TARGET" ]; then
    if [ ! -d "$SYSTEM_DIR" ]; then
        echo "Could not find Caelestia at $TARGET or $SYSTEM_DIR."
        echo "Install caelestia-shell first, or set XDG_CONFIG_HOME if yours is elsewhere."
        exit 1
    fi
    echo "-> No user copy found. Copying $SYSTEM_DIR -> $TARGET"
    echo "   (quickshell prefers the user copy over the system one, and package"
    echo "    updates will no longer overwrite your changes)"
    mkdir -p "$XDG_CONFIG/quickshell"
    cp -r "$SYSTEM_DIR" "$TARGET"
else
    echo "-> Using existing user copy at $TARGET"
fi

for f in "$CONTENT" "$WINDOW"; do
    if [ ! -f "$f" ]; then
        echo "Expected file missing: $f"
        echo "Your caelestia version may differ from what this mod was written for."
        exit 1
    fi
done


# --- 2. Drop in the new files -------------------------------------------------
echo "-> Installing NotesTab.qml"
cp "$SCRIPT_DIR/qml/modules/dashboard/NotesTab.qml" "$NOTES"
ok "NotesTab.qml"

if [ -f "$SCRIPT_DIR/qml/modules/bar/popouts/Battery.qml" ]; then
    if [ -f "$BATTERY" ]; then
        echo "-> Installing charging battery popout"
        backup "$BATTERY"
        cp "$SCRIPT_DIR/qml/modules/bar/popouts/Battery.qml" "$BATTERY"
        ok "Battery.qml"
    else
        warn "Battery.qml not found at $BATTERY, skipping battery popout"
    fi
fi

# --- 3. Patch Content.qml: register the Notes tab ----------------------------
echo "-> Patching Content.qml (registering the Notes tab)"
backup "$CONTENT"

if grep -q "notesComponent" "$CONTENT"; then
    ok "Content.qml already patched, skipping"
else
    # 3a. add the tab entry after the weather entry inside dashboardTabs
    if grep -q "component: weatherComponent," "$CONTENT"; then
        python3 - "$CONTENT" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()

# Find the weather tab object and append a Notes tab object after it.
pattern = re.compile(
    r'(\{\s*component:\s*weatherComponent,.*?enabled:\s*[^\n]*\n\s*\})',
    re.DOTALL,
)
m = pattern.search(src)
if not m:
    sys.exit(2)

notes_entry = (
    ',\n            {\n'
    '                component: notesComponent,\n'
    '                iconName: "sticky_note_2",\n'
    '                text: Tr.tr("Notes"),\n'
    '                enabled: true\n'
    '            }'
)
src = src[:m.end()] + notes_entry + src[m.end():]

# 3b. add the Component block after the weatherComponent Component
comp = re.compile(r'(Component\s*\{\s*id:\s*weatherComponent.*?\n\s*\})', re.DOTALL)
cm = comp.search(src)
if not cm:
    sys.exit(3)
notes_comp = (
    '\n\n        Component {\n'
    '            id: notesComponent\n\n'
    '            NotesTab {}\n'
    '        }'
)
src = src[:cm.end()] + notes_comp + src[cm.end():]

open(path, "w").write(src)
PY
        rc=$?
        if [ $rc -ne 0 ]; then
            warn "Could not patch Content.qml automatically (code $rc)."
            warn "Your Content.qml differs from the expected layout. Restoring it."
            cp "$CONTENT.bak" "$CONTENT"
            echo
            echo "Manual step: add a Notes entry to dashboardTabs and a"
            echo "  Component { id: notesComponent; NotesTab {} }"
            echo "block in $CONTENT. See README.md."
            exit 1
        fi
    else
        warn "Could not find the weather tab entry in Content.qml."
        warn "This mod expects a Caelestia version that ships the Weather dashboard tab."
        exit 1
    fi

    if grep -q "notesComponent" "$CONTENT"; then
        ok "Content.qml patched"
    else
        warn "Patch did not apply. Restoring original Content.qml."
        cp "$CONTENT.bak" "$CONTENT"
        exit 1
    fi
fi

# --- 4. Patch ContentWindow.qml: let the dashboard take keyboard focus --------
# Without this, typing in the notes editor goes to whatever window was focused
# before, because the drawer window never asks the compositor for keyboard focus
# while only the dashboard is open.
echo "-> Patching ContentWindow.qml (keyboard focus for the dashboard)"
backup "$WINDOW"

if grep -q "screenState.session || screenState.dashboard" "$WINDOW"; then
    ok "ContentWindow.qml already patched, skipping"
else
    sed -i 's/screenState\.launcher || screenState\.session ? WlrKeyboardFocus\.OnDemand/screenState.launcher || screenState.session || screenState.dashboard ? WlrKeyboardFocus.OnDemand/' "$WINDOW"
    if grep -q "screenState.session || screenState.dashboard" "$WINDOW"; then
        ok "ContentWindow.qml patched"
    else
        warn "Could not patch ContentWindow.qml (line differs in your version)."
        warn "The Notes tab will show, but typing won't reach it."
        warn "See README.md for the one-line manual change."
    fi
fi

echo
echo "Done. Restart the shell to apply (stop it, then run: caelestia shell)."
echo "Or just log out and back in."
echo
echo "To undo everything later, run ./uninstall.sh"
