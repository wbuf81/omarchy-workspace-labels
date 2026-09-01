# Contributing

Careful fixes, useful workspace ideas, and screenshots from unusual desktop
setups are welcome.

## Development loop

1. Install the plugin once with `./scripts/dev-sync.sh --enable`.
2. Edit the repository copy.
3. Run `./scripts/dev-sync.sh` to validate, sync, and rescan.
4. Restart the shell when a QML change does not appear: `omarchy restart shell`.
5. Run `./scripts/release-check.sh` before opening a pull request.

Omarchy rejects plugin symlinks intentionally, so the sync helper copies this
tree into the user plugin directory.

## Design principles

- Keep the bar readable: every visible workspace must retain a clickable label.
- Treat Hyprland as the authority for live workspaces and windows.
- Never remove a workspace that still contains windows.
- Preserve rapid edits until `shell.json` round-trips through the shell.
- Use Omarchy's native panel, theme, spacing, and popout conventions.
- Keep hover capture single-shot and bounded; the bar should remain inexpensive.

## Useful commands

```sh
./scripts/static-check.sh
./scripts/release-check.sh
omarchy-shell io.github.wbuf81.workspace-labels open
omarchy-shell io.github.wbuf81.workspace-labels preview 2
quickshell log -p /usr/share/omarchy/shell -t 120 --no-color
```

For UI bugs, please include the Omarchy version, bar orientation, monitor
arrangement, workspace numbers involved, and whether each workspace contained
windows.
