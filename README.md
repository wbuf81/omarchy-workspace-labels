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

- **Editable in place** — right-click any workspace, rename it, pick an icon.
- **Icon picker built in** — 49 render-verified Nerd Font glyphs, searchable, or paste your own.
- **Add and remove workspaces** — `+` pins the next free slot; `×` gives it back.
- **Fully keyboard driven** — `j`/`k`, `Enter`, `i`, `a`, `x`, `Esc`.
- **Unbounded** — any workspace Hyprland reports gets a button, named or not.
- **Saves instantly** — writes straight to `shell.json`; nothing to reload.

<p align="center">
  <img src="docs/picker.png" alt="The inline icon picker" width="480">
</p>

## Install

```sh
omarchy plugin add https://github.com/wbuf81/omarchy-workspace-labels.git --enable
omarchy bar move wes.workspaces --section left
```

Requires Hyprland and a Nerd Font — the icon presets are verified against
JetBrainsMono Nerd Font.

## Use

| Action | Result |
| --- | --- |
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
| `labels` | object | `{"1": {"icon": "…", "name": "Code"}}` |
| `pinned` | array | Workspace numbers kept in the bar even when empty. Managed by `+` and `×`. |
| `minWorkspaces` | integer | Legacy. Only read while `pinned` is unset, where it pins `1..N`. |

Scriptable, and picked up live:

```sh
omarchy bar set wes.workspaces labels '{"1":{"icon":"","name":"Code"}}' --json
omarchy bar set wes.workspaces pinned '[1,2,3,4,5]' --json
```

## IPC

```sh
omarchy-shell wes.workspaces toggleEditor   # also: toggle / open / close
omarchy-shell wes.workspaces openFor 3      # open targeting workspace 3
omarchy-shell wes.workspaces picker 3       # jump to its icon picker
omarchy-shell wes.workspaces add
omarchy-shell wes.workspaces remove 6
omarchy-shell wes.workspaces next           # cycle workspaces
omarchy-shell wes.workspaces prev
omarchy-shell wes.workspaces reset          # back to built-in defaults
```

On a multi-monitor setup the panel opens on one bar instance, not all of them
— matching how the built-in wifi, clock and volume panels behave. Right-click
works on whichever monitor you click.

## Keybinding

In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + W", "Workspace labels", "omarchy-shell wes.workspaces toggleEditor")
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

## License

MIT — see [LICENSE](LICENSE).
