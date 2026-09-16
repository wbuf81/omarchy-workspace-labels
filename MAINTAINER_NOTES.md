# Maintainer Notes

This is the durable handoff for future releases. Keep details here that are
easy to lose between sessions; user-facing changes belong in `CHANGELOG.md`.

## Current state

- Manifest version prepared in this tree: **3.1.1**.
- Development branch: `main`.
- 3.1.0 and 3.1.1 were developed and verified against **Omarchy 4.0.3-1** on
  September 16, 2026. 3.0.1 was hardened against 4.0.2-1 on September 1, 2026.
- The `v3.0.1` tag was created retroactively at the release commit when 3.1.0
  shipped; earlier the changelog entry existed without a tag.

## Omarchy 4.0.3 plugin API

Third-party bar widgets no longer receive the shell object. `bar.shell` is a
`PluginShellApi` facade (`/usr/share/omarchy/shell/services/PluginShellApi.qml`,
built in `shell.qml`). What matters for this plugin:

- `updateEntryInline(id, settings)` still works for the plugin's own layout
  entry, so settings persistence and the staged-write overlay are unchanged.
- `appLibrary` is `null` unless the manifest declares the `menu` kind. Version
  3.1.0 therefore reads `DesktopEntries.applications.values` and resolves icons
  with `Quickshell.iconPath(name, true)` directly. Do not reintroduce
  `shell.appLibrary`; `scripts/static-check.sh` fails if it appears.
- A standalone `qs -p` harness sees zero desktop entries, so test the picker
  inside the running shell rather than in a throwaway config.
- The watcher logs "Local plugin changed, reloading" after `dev-sync.sh`, but
  the compiled QML stays stale until `omarchy restart shell`. Settings changes
  do apply live. Wait a few seconds after a sync before restarting; a restart
  during the reload has segfaulted Quickshell in the sibling plugin.

## Design language

The editor, picker, and hover card were redrawn on September 16, 2026 in the
flat monospace "station board" language shared with Idle Screen Counter (its
`Panel.qml` is the reference). Keep to it:

- Palette on `root`: `ink` (popup text), `dim` 0.55, `faint` 0.3, `line` 0.14,
  `well` 0.035, `screenWell` (darker popup background), plus `Color.accent`.
- `Caption` (uppercase, letter-spaced, dim), `Rule` (1px `line`), and `Mark`
  (steps(1) blinking accent square) are inline components; reuse them.
- Rows are separated by `Rule`s, indices are zero-padded via `pad()`, and the
  keyboard cursor is a `well` fill plus a 2px accent bar at the left edge.
- Buttons are `bordered` with `fontSize: Style.font.caption` and uppercase
  text; the primary action is `selected: true`.
- Honor `Style.cornerRadius` as-is. Never add radius, cards, or friendly copy.

## Workspace-state contract

`Logic.js` is production code imported by `Workspaces.qml`, not a test-only
model. It owns normalization, visible/editor workspace unions, next-free-slot
selection, and add/remove state transitions. Keep it free of Qt APIs so
`tests/logic.test.js` can execute those exact decisions under Node.

The invariants are:

- Empty slots created by the plugin are limited to 1–20.
- Live Hyprland workspaces remain visible even above 20.
- Add selects the lowest free slot and stages it in `pinned` immediately.
- Rapid adds see the staged pin list rather than stale shell settings.
- Remove is inert while a workspace contains any window.
- Removing an empty workspace unpins it and deletes only its label.
- A saved label keeps an empty workspace in the editor until it is removed.
- Malformed pinned/label settings cannot create duplicate, fractional,
  negative, or arbitrarily high empty rows.

## Toplevel contract

Use the complete `Hyprland.toplevels.values` registry and filter each client's
`lastIpcObject.workspace.id`. Do not revert occupancy, app matching, or preview
capture to `workspace.toplevels.values`; that collection was observed to lag or
omit sibling surfaces when one application owns multiple windows.

## Verification status

Automated checks completed for 3.1.0 on September 16, 2026:

- Node coverage as before, plus desktop-entry filtering, name search, and
  class-to-app matching (StartupWMClass, then desktop id, then app name).
- QML parser check with Qt's `qmlformat`.
- Omarchy's native `omarchy plugin validate`.
- Manifest, release asset, shell-script, integration-contract (including the
  Quickshell desktop-entry path), and unresolved marker checks.

Interactive checks completed on 4.0.3-1 with the shell running: app icons in
the bar and picker, ON THIS WORKSPACE matching for Ghostty and Brave, the
redesigned editor, picker, and hover card on a horizontal top bar.

Vertical bar (`omarchy bar position left`, 3.1.1): app icons, glyphs, and the
add button stack in the column; editor, picker, and preview open beside the
bar and clamp to the screen. An icon-less workspace now shows its number
(`Logic.barName`); before 3.1.1 the full name spilled past the bar.

Multi-monitor (Hyprland headless output, 3.1.1): each output gets its own bar
instance with the full widget. Hyprland 0.56 uses Lua dispatchers, so move a
workspace with `hyprctl dispatch 'hl.dsp.workspace.move({ monitor = "NAME" })'`
after focusing it; headless outputs are numbered HEADLESS-1, -2, ... per
session, so read the name from `hyprctl monitors -j`. The hover preview for a
workspace on the other output used that output's geometry and name
(HEADLESS-2 · 1920×1080, 16:9). Its window thumbnails rendered black while
the same workspace previewed fine once moved back to DP-1. The same-output
control preview showed real content, so this is most likely toplevel export
on a headless output rather than plugin logic, but it has not been confirmed
on a second physical monitor. IPC verbs (`openFor`, `preview`) act on the
first bar instance that registered the handler; only the built-in bar's
right-click path is per-instance.

## Future version checklist

1. Add user-facing changes to `CHANGELOG.md`.
2. Update `manifest.json` and the expected version in
   `scripts/static-check.sh` together.
3. Run `./scripts/static-check.sh` during development.
4. Run `./scripts/release-check.sh` and the README's manual checks on Omarchy.
5. Update the tested-version badge when appropriate.
6. Commit the release, create the matching Git tag, and verify GitHub Actions.
7. Upload `docs/social-preview.png` under the repository's Social preview
   setting if its artwork changed.
