# Caelestia Notes Tab

A Material 3 styled **Notes** tab for the [Caelestia](https://github.com/caelestia-dots/shell) dashboard, plus a
**charging battery popout** that fills like a tank and turns green while charging.

- Two-pane notes app: list on the left, editor on the right
- Notes persist across restarts (`~/.local/state/caelestia/notes_tab.json`)
- Uses the shell's own palette, tokens and animation types, so it follows your wallpaper colours
- Battery popout: horizontal fill gauge, animated shimmer and green shift while charging
## Screenshots
### Light mode
(screenshots/batt_1.png)
[[/screenshots/notes_1.png]]
## Install

```bash
git clone <this-repo>
cd caelestia-notes-tab
./install.sh
```

Then restart the shell (stop it and run `caelestia shell` again, or log out and back in).

**Do not run it with sudo.** It installs into `~/.config/quickshell/caelestia`, never into `/etc` or `/usr`.

### What the installer does

1. If you have no user copy of the shell, copies `/etc/xdg/quickshell/caelestia` to `~/.config/quickshell/caelestia`.
   Quickshell prefers the user copy, and package updates no longer overwrite your changes.
2. Adds `modules/dashboard/NotesTab.qml`.
3. Replaces `modules/bar/popouts/Battery.qml` (original saved as `Battery.qml.bak`).
4. Patches `modules/dashboard/Content.qml` to register the Notes tab (original saved as `Content.qml.bak`).
5. Patches one line in `modules/drawers/ContentWindow.qml` (original saved as `ContentWindow.qml.bak`), see below.

It is safe to run twice, and it checks compatibility before writing anything. If your Caelestia version
doesn't match, it stops and changes nothing.

## Uninstall

```bash
./uninstall.sh          # restores backups, keeps your notes
./uninstall.sh --purge  # also deletes your saved notes
```

## Things you should know

**Keyboard focus change.** Caelestia's drawer window only requests keyboard focus for the launcher and session
panels. Without a change, keystrokes typed into the notes editor go to whatever window was focused before, because
the dashboard was never built to hold text input. The installer adds `|| screenState.dashboard` to that condition.
The side effect is that the *whole dashboard* now takes keyboard focus while open, not just the Notes tab. If you
use hover-to-open for the dashboard, test that it doesn't steal focus in a way you dislike.

**Hardcoded green.** Material 3 has no "success" colour role, so the charging green is a fixed colour rather than
one derived from your scheme. It may clash with some wallpaper palettes.

**Version compatibility.** Written against a recent Caelestia (the version with the Weather dashboard tab and the
`Tokens` / `Caelestia.Config` imports). Older versions won't work. Newer versions may change files these patches
depend on. The installer verifies each patch applied and tells you if one didn't.

**Battery popout replaces a whole file.** If you've customised `Battery.qml` yourself, back it up first. The original
is saved as `Battery.qml.bak`, but only the first time the installer runs.

## Manual install

If the installer can't patch your files:

1. Copy `qml/modules/dashboard/NotesTab.qml` into `~/.config/quickshell/caelestia/modules/dashboard/`.
2. In `modules/dashboard/Content.qml`, add this to the `allTabs` array in `dashboardTabs`:

   ```qml
   {
       component: notesComponent,
       iconName: "sticky_note_2",
       text: Tr.tr("Notes"),
       enabled: true
   },
   ```

   and this next to the other `Component { ... }` blocks:

   ```qml
   Component {
       id: notesComponent

       NotesTab {}
   }
   ```

3. In `modules/drawers/ContentWindow.qml`, change

   ```qml
   WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? ...
   ```

   to

   ```qml
   WlrLayershell.keyboardFocus: screenState.launcher || screenState.session || screenState.dashboard ? ...
   ```

## Known issues

- `Content.qml` logs a "Binding loop detected for property active" warning when switching to the Notes tab. It
  doesn't affect functionality, but I haven't confirmed whether stock Caelestia produces it without this mod.
- Notes are saved as plain JSON, unencrypted.
- Only tested on Arch-based Hyprland (CachyOS).

## License

MIT
