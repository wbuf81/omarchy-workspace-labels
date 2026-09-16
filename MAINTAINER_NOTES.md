# Maintainer Notes

This is the durable handoff for future releases. Keep details here that are
easy to lose between sessions; user-facing changes belong in `CHANGELOG.md`.

## Current state

- Manifest version prepared in this tree: **3.2.2**.
- Development branch: `main`.
- 3.1.0 through 3.2.2 were developed and verified against **Omarchy 4.0.3-1**
  on September 16, 2026. 3.0.1 was hardened against 4.0.2-1 on September 1, 2026.
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

## File map and the host/child contract

`Workspaces.qml` is the manifest entry point and the only file that owns
state: settings plumbing, labels/pins, auto icons, desktop entries, urgent
tracking, preview state, IPC, and the bar row with the sliding focus bar.
Every visual child (`BarButton`, `EditorPanel`, `IconPicker`, `PreviewCard`,
`WindowTile`) takes `required property var host` and reads model state, the
palette (`ink`, `dim`, `faint`, `line`, `well`, `screenWell`, `panelFont`),
and `pad()` from it. Children never persist anything; they call `host.*`
mutators. Same-directory implicit imports resolve the sibling types; there is
no qmldir and no singleton.

`KeyboardPanel`'s default property only accepts Items, so a `Timer` or
`Connections` at the root of `EditorPanel` fails with "Cannot assign object of
type QQmlTimer to list property contentItem". Put non-visual helpers inside
the `PanelKeyCatcher`.

Urgency has no property on Quickshell's toplevels; it is tracked from
`Hyprland.rawEvent` (`urgent`, `activewindowv2`, `closewindow`) with addresses
normalized without the `0x` prefix, and pruned against the focused workspace.

`FlipBoard.qml`/`FlipStep.qml` are copies from Idle Screen Counter (same
author, MIT), reduced to the stepped style. Keep them pure QtQuick.

## Design language

The editor, picker, hover card, and bar were drawn in the flat monospace
"station board" language shared with Idle Screen Counter (its `Panel.qml` is
the reference) and borrow OmaFinance's instrument-console details for the
preview. Keep to it:

- Palette on `host`: `ink` (popup text), `dim` 0.55, `faint` 0.3, `line` 0.14,
  `well` 0.035, `screenWell` (darker popup background), plus `Color.accent`
  for focus/live/selected and `Color.urgent` for urgent only.
- `Caption` (uppercase, letter-spaced, dim), `Rule` (1px `line`), `Mark`
  (steps(1) blinking accent square), `BlockCursor` (blinking `█`), and
  `CornerFrame` are standalone files; reuse them.
- Rows are separated by `Rule`s, indices are zero-padded via `pad()`, and the
  keyboard cursor is a `well` fill plus a 2px accent bar at the left edge.
- Numbers that change while the panel is open sit on `FlipBoard` tiles.
- Buttons are `bordered` with `fontSize: Style.font.caption` and uppercase
  text; the primary action is `selected: true`; destructive actions arm first.
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

Use the complete `Hyprland.toplevels.values` registry. Do not revert
occupancy, app matching, or preview capture to `workspace.toplevels.values`;
that collection was observed to lag or omit sibling surfaces when one
application owns multiple windows.

Filter by `toplevelWorkspaceId()`, which reads only `lastIpcObject`.
Verified on 2026-09-16: a window opened after the shell starts has an empty
`lastIpcObject` (no address, workspace, class, or geometry) until Quickshell
next runs `hyprctl clients`. Before 3.2.0 such windows were invisible to the
plugin until a restart. `refreshToplevels()` (a 40 ms debounced Timer around
`Hyprland.refreshToplevels()`) is requested on `openwindow`,
`movewindow(v2)`, `closewindow`, `changefloatingmode`, and `fullscreen` raw
events and before a preview; that is what fills in workspace, class, and
geometry for counts, auto icons, and tiles. Reproduce with
`setsid -f ghostty --title=demo -e btop` on a fresh workspace and check the
editor row count.

**Never read `toplevel.workspace` (the object) inside bindings.** 3.2.0 did,
and the shell segfaulted twice at startup inside
`Qt::endPropertyUpdateGroup` while Quickshell re-parsed `j/clients` before
`j/workspaces` had answered ("Workspace N requested before creation,
performing early init with id -1" in the crash log). Cores: `coredumpctl list
quickshell`, 2026-09-16 13:26 and 14:19. Reading `toplevel.address` (a
string) is fine. 3.2.1 removed the object read; six consecutive restarts then
ran clean. This is correlation plus a plausible mechanism, not a symbolized
proof: Arch ships no Quickshell debug symbols.

Preview geometry must use `Logic.logicalMonitor(previewMonitor)`: Hyprland's
monitor width/height are physical pixels, window `at`/`size` are logical.
`Logic.previewLayout(snapshots, 12)` does the filtering, ordering, and cap;
note that in QML `lastIpcObject.at`/`.size` are Qt array-likes, not JS
Arrays, so the logic tests for an indexable pair rather than
`Array.isArray` (a regression caught live on 2026-09-16 before release).

## Verification status

Automated checks completed for 3.1.0 on September 16, 2026:

- Node coverage as before, plus desktop-entry filtering, name search, and
  class-to-app matching (StartupWMClass, then desktop id, then app name).
- QML parser check with Qt's `qmlformat`.
- Omarchy's native `omarchy plugin validate`.
- Manifest, release asset, shell-script, integration-contract (including the
  Quickshell desktop-entry path), and unresolved marker checks.

Interactive checks completed on 4.0.3-1 with the shell running (3.2.0 to
3.2.2): app icons in the bar and picker, auto icon on an icon-less workspace,
ON THIS WORKSPACE matching, preview in `capture` (thumbnails with badges),
`map` (icon blocks), and `off`, the sliding focus bar caught mid-slide, flip
readouts caught mid-flip, the block cursor blinking, grid/ticks/corners on the
preview, the `send` verb dispatching without error (dry run onto the window's
own workspace), a window spawned after a restart being counted, previewed,
and auto-iconed, closing a window while its preview is open (card updates
from 2 to 1 window, no crash), a theme switch (`omarchy theme set catppuccin`
and back) re-inking the open editor live, IPC `openFor` landing on the bar of
a focused headless output, and `scripts/restart-soak.sh 10` passing.

**Urgent state, what is and is not verified.** Hyprland's event socket
(`socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock -`)
shows `urgent>>ADDR` on every new window and on a terminal bell (Ghostty's
default `bell-features` includes `attention`). On Omarchy's defaults
(`misc.focus_on_activate = true`) the compositor focuses the ringing window
at once, so `activewindowv2` follows and the plugin clears the flag, which is
the correct outcome. The urgent color therefore only ever shows for apps
whose activation does not steal focus (Omarchy ships such a rule for
Telegram). A runtime `hl.window_rule` with `focus_on_activate = false` did
not prevent the focus jump in testing, so the colored state has still not
been seen on screen; the set logic is unit-tested. Not exercised live: a real
middle-click and RESET's second click.

**Tooling.** `scripts/restart-soak.sh N [settle]` restarts the shell and
fails on any new Quickshell core dump; run it before tagging.
`scripts/dev-sync.sh --restart` fails if a core dump appears within ten
seconds. CI installs `qt6-declarative-dev-tools` so every QML file is parsed
by qmlformat on push; the static check refuses to run in CI without it.

Vertical bar and headless multi-monitor results from 3.1.1 still apply (see
below); 3.2.0 was not re-run in those configurations.

Vertical bar (`omarchy bar position left`, 3.1.1): app icons, glyphs, and the
add button stack in the column; editor, picker, and preview open beside the
bar and clamp to the screen. An icon-less workspace shows its number
(`Logic.barName`).

Multi-monitor (Hyprland headless output, 3.1.1): each output gets its own bar
instance. Hyprland 0.56 uses Lua dispatchers, so move a workspace with
`hyprctl dispatch 'hl.dsp.workspace.move({ monitor = "NAME" })'` after
focusing it; headless outputs are numbered HEADLESS-1, -2, ... per session.
The hover preview for a workspace on the other output used that output's
geometry and name; its window thumbnails rendered black (now covered by the
map fallback), while the same-output control preview showed content. Likely
toplevel export on a headless output, unconfirmed on a physical second
monitor. Since 3.2.0 the IPC verbs route to the bar instance on the focused
monitor.

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
