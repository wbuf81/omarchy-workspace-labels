<h1 align="center">Workspace Labels</h1>

<p align="center">
  Named workspaces with per-workspace icons for the <a href="https://omarchy.org">Omarchy</a> bar.
</p>

<p align="center">
  <img src="docs/bar.png" alt="Named workspaces in the Omarchy bar" width="470">
</p>

Stock Omarchy gives you `1 2 3 4 5`. This gives them names and icons, underlines
the one you're on, and lets you edit all of it in place — no config file, no
shell restart.

<p align="center">
  <img src="docs/editor.png" alt="The workspace editor panel" width="480">
</p>

## Why it looks native

The editor isn't a bolted-on popup. It's built on `Ui.Panel` + `Ui.KeyboardPanel`
— the same machinery behind Omarchy's built-in wifi, volume and display menus —
so it takes real keyboard focus, scrolls and clamps inside the screen, and hands
the popout slot over correctly when you open another bar widget.

- **Hover to see what's on it** — a scaled map of the workspace, windows drawn at their real positions and sizes.
- **Editable in place** — right-click any workspace, rename it, pick an icon.
- **Real app icons** — use the actual Brave lion or Spotify mark, not an approximation. Apps running on the workspace you're editing are offered first.
- **Icon picker built in** — 49 render-verified Nerd Font glyphs plus every installed app, searchable, or paste your own.
- **Add and remove workspaces** — `+` pins the next free slot; `×` gives it back.
- **Fully keyboard driven** — `j`/`k`, `Enter`, `i`, `a`, `x`, `Esc`.
- **Unbounded** — any workspace Hyprland reports gets a button, named or not.
- **Saves instantly** — writes straight to `shell.json`; nothing to reload.

<p align="center">
  <img src="docs/preview.png" alt="Hover preview of a workspace" width="480">
</p>

Hovering a workspace draws a miniature of it — each window captured through
Hyprland's toplevel export and placed at its true position and size, so a
tiled pair reads as a tiled pair. It works for workspaces you aren't currently
on, which is the whole point: the compositor never renders those, so there is
no single screenshot to grab and the preview has to be assembled per window.

Captures are taken once per hover (`live: false`), not streamed — a live feed
per window every time the pointer crosses the bar would be far too expensive.

<p align="center">
  <img src="docs/picker.png" alt="The inline icon picker" width="480">
</p>

### App icons

The picker lists every installed application alongside the glyphs. Pick one and
the workspace shows that app's real icon.

An app icon is stored as `app:<icon-name>` — the name from the desktop entry's
`Icon=` field, **not** the window class. Those often differ: Brave's window
class is `brave-browser` but its icon is `brave-desktop`. The picker's
**ON THIS WORKSPACE** row resolves that for you by matching each running
window's class against `StartupWMClass`, so a workspace running Brave offers
the Brave icon in one click.

```sh
omarchy bar set io.github.wbuf81.workspace-labels labels '{"3":{"icon":"app:brave-desktop","name":"Brave"}}' --json
```

**No desktop entry for the thing on that workspace?** A site you keep open as a
browser tab has no icon to offer. Install it as a web app and it gains one:

```sh
omarchy webapp install "Gmail" https://mail.google.com/ <icon-url-or-file>
```

It drops a 256px icon into `~/.local/share/icons` and writes a launcher, after
which the app shows up in the picker like any other. Note that a site opened as
an ordinary tab still reports the browser's window class, so **ON THIS
WORKSPACE** will offer the browser — launch it through the web app to get its
own class.

`icon` also accepts an absolute path (`app:/home/you/icons/thing.png`) if you
would rather not install anything; type it into the picker's glyph field.

## Install

```sh
omarchy plugin add https://github.com/wbuf81/omarchy-workspace-labels.git --enable
omarchy bar move io.github.wbuf81.workspace-labels --section left
```

Requires Hyprland and a Nerd Font — the icon presets are verified against
JetBrainsMono Nerd Font.

## Remove

```sh
omarchy plugin disable io.github.wbuf81.workspace-labels      # take it off the bar, keep it installed
omarchy plugin remove io.github.wbuf81.workspace-labels       # uninstall it
omarchy plugin enable omarchy.workspaces   # put the stock indicators back
```

Your labels and pinned list live in `~/.config/omarchy/shell.json` under this
widget's layout entry and go with it. Nothing is written anywhere else — no
files outside that entry, no services, no state directories.

## Use

| Action | Result |
| --- | --- |
| Hover a workspace | Preview the windows on it (~0.5s delay) |
| Left-click a workspace | Switch to it |
| Right-click a workspace | Open the editor on that workspace's row |
| Scroll over the bar | Previous / next workspace |
| Click `+` | Pin, focus and name the next free workspace |
| `SUPER + ALT + W` | Toggle the editor |

Inside the editor:

| Key | Action |
| --- | --- |
| `j` `k` / arrows | Move the row cursor |
| `Enter` | Rename the highlighted workspace |
| `i` | Open its icon picker |
| `a` | Add a workspace |
| `x` | Remove the highlighted workspace |
| `Esc` | Leave the picker, then close the panel |

Removing only unpins a workspace and forgets its label. One that still holds
windows keeps its button until it empties.

An unnamed workspace falls back to its number, so a button can never become
invisible — clear both fields on a named one to get the bare number back.

## Settings

Stored inline in `~/.config/omarchy/shell.json` under this widget's layout entry.

| Key | Type | Meaning |
| --- | --- | --- |
| `labels` | object | `{"1": {"icon": "…", "name": "Code"}}`. `icon` is a glyph, or `app:<icon-name>` for an application icon. |
| `hoverPreview` | boolean | Hover previews. Default `true`; set `false` to turn them off. |
| `pinned` | array | Workspace numbers kept in the bar even when empty. Managed by `+` and `×`. |
| `minWorkspaces` | integer | Legacy. Only read while `pinned` is unset, where it pins `1..N`. |

Scriptable, and picked up live:

```sh
omarchy bar set io.github.wbuf81.workspace-labels labels '{"1":{"icon":"","name":"Code"}}' --json
omarchy bar set io.github.wbuf81.workspace-labels pinned '[1,2,3,4,5]' --json
```

## IPC

```sh
omarchy-shell io.github.wbuf81.workspace-labels toggleEditor   # also: toggle / open / close
omarchy-shell io.github.wbuf81.workspace-labels openFor 3      # open targeting workspace 3
omarchy-shell io.github.wbuf81.workspace-labels picker 3       # jump to its icon picker
omarchy-shell io.github.wbuf81.workspace-labels add
omarchy-shell io.github.wbuf81.workspace-labels remove 6
omarchy-shell io.github.wbuf81.workspace-labels next           # cycle workspaces
omarchy-shell io.github.wbuf81.workspace-labels prev
omarchy-shell io.github.wbuf81.workspace-labels reset          # back to built-in defaults
omarchy-shell io.github.wbuf81.workspace-labels preview 3      # peek at a workspace without hovering
omarchy-shell io.github.wbuf81.workspace-labels unpreview
```

On a multi-monitor setup the panel opens on one bar instance, not all of them
— matching how the built-in wifi, clock and volume panels behave. Right-click
works on whichever monitor you click.

## Keybinding

In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + W", "Workspace labels", "omarchy-shell io.github.wbuf81.workspace-labels toggleEditor")
```

`next` / `prev` work here too if you'd rather bind them than scroll.

## Notes

- Cloned from the built-in `omarchy.workspaces` widget.
- Editing the QML needs `omarchy restart shell`. The file watcher logs
  `Local plugin changed, reloading` on save, but that does **not** re-render
  the widget — the log line is emitted by the watcher, not by a successful
  reload.
- Verified on a single horizontal top bar and on a vertical (left) bar, where
  the widget renders icon-only in a column and the panel anchors beside it.
  Multi-monitor is implemented to the same convention as the built-in panels
  but has not been exercised on a second screen.

## Third-party

No third-party code is bundled. At runtime the plugin uses only APIs provided by
Omarchy's quickshell configuration (`qs.Ui`, `qs.Commons`) and Quickshell itself.

Icon glyphs come from whichever Nerd Font the bar is configured to use, and
application icons are read from the desktop entries and icon themes already
installed on the machine — neither is redistributed here. Application logos
visible in the screenshots are trademarks of their respective owners and appear
only to illustrate what the plugin does.

## License

MIT — see [LICENSE](LICENSE).
