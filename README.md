# Caelestia Dashboard Mods

Three additions for the [Caelestia](https://github.com/caelestia-dots/shell) dashboard:

- **Notes tab**: notes that save between restarts
- **Hourly forecast** on the Weather tab: a temperature graph you scroll with arrows
- **Battery popout**: a fill gauge that turns green and shimmers while charging

## Install

```bash
git clone <this repo>
cd <folder>
./install.sh
```

Then restart the shell. Don't use sudo. It installs into `~/.config/quickshell/caelestia`, copying the system config there first if you don't have one, so package updates won't undo it.

## Uninstall

```bash
./uninstall.sh          # keeps your notes
./uninstall.sh --purge  # deletes them too
```

## Good to know

- The Weather and Battery files replace the stock ones. Originals are saved as `.bak`. If you've customised either, back it up first.
- Typing in Notes needs the dashboard to accept keyboard focus, so the installer adds one condition to `ContentWindow.qml`. The whole dashboard now grabs focus while open.
- The charging green is fixed, not taken from your colour scheme.
- Needs a recent Caelestia with the Weather tab. Only tested on Arch with Hyprland.

## Manual install

1. Copy the files in `qml/modules/` into `~/.config/quickshell/caelestia/modules/`.
2. In `modules/dashboard/Content.qml`, add a `Component { id: notesComponent; NotesTab {} }` next to the weather one, and this entry to the tab list:
   `{ component: notesComponent, iconName: "sticky_note_2", text: Tr.tr("Notes"), enabled: true }`
3. In `modules/drawers/ContentWindow.qml`, add `|| screenState.dashboard` to the `keyboardFocus` condition.

## License

GPL-3.0, since this builds on Caelestia's own code.
