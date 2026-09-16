# Changelog

## 3.2.0

**Reliable previews, auto icons, and more of the station-board character.**

- **Fixed: windows opened after the shell started were invisible to the
  plugin.** Quickshell fills a new toplevel's IPC snapshot lazily, so its
  workspace, class, and geometry were missing until something else refreshed
  it; the bar showed the workspace as empty, previews skipped the window, and
  auto icons could not see it. The plugin now reads the tracked workspace and
  address properties first and asks Quickshell to refresh toplevels on window
  open, move, close, float, and fullscreen events and before a preview.
- **Preview modes.** New `previewMode` setting: `capture` (single-shot window
  screenshots, the old behavior), `map` (each window drawn as a block with its
  app icon, never any screen content), or `off`. A capture that yields nothing
  now falls back to the map block instead of a black tile, and captured windows
  carry a small app-icon badge so a wall of text still reads. The legacy
  `hoverPreview: false` still means off. The `preview` IPC verb is an explicit
  request and keeps working in `off` mode, drawing the map.
- **Auto icons.** A workspace with no icon of its own shows the icon of the
  app running on it, chosen by the most common window class. The editor dims
  a borrowed icon so you can tell it from one you picked. `autoIcons: false`
  turns it off.
- **Urgent workspaces** light up in the theme's urgent color, driven by
  Hyprland's urgent events and cleared when the window is activated, closed,
  or its workspace focused.
- **Middle-click sends the focused window** to that workspace without
  following. New IPC verb: `send <id>`. Right-click still opens the editor.
- **Sliding focus bar.** The focused workspace is marked by a hairline of
  accent that glides along the bar's edge instead of an underline.
- **Instrument-console preview.** The screen well gets a quiet reference
  grid, edge ticks, and corner frames; the header says `· now` on the focused
  workspace.
- **Block cursor and flip readouts** in the editor: a blinking `█` after the
  title, and the focused workspace number plus each row's window count on
  stepped split-flap tiles that flip when values change.
- **Two-step reset.** RESET arms on the first click (`SURE?` in the urgent
  color) and fires only on a second click within three seconds.
- `/` opens the icon picker for the highlighted row, alongside `i`.
- IPC verbs act on the bar instance on the focused monitor.
- The picker hides apps whose icon no installed theme can resolve.
- The widget is split into focused files: `BarButton`, `EditorPanel`,
  `IconPicker`, `PreviewCard`, `WindowTile`, the shared `Caption`, `Rule`,
  `Mark`, `BlockCursor`, `CornerFrame`, and the `FlipBoard`/`FlipStep` tiles
  shared with Idle Screen Counter. `Workspaces.qml` keeps the model, settings,
  and IPC.
- `scripts/dev-sync.sh --restart` restarts the shell after a sync, since
  Omarchy 4.0.3 does not reload changed QML live.

## 3.1.1

- Vertical bars: a workspace with a name but no icon showed the whole name
  horizontally and spilled past the bar. It now shows its number, like the
  stock widget; the tooltip keeps the name. The rule lives in `Logic.barName`
  with tests.
- Silenced a harmless `autoFocusTarget of undefined` warning fired by a
  deferred focus grab after the bar tore its rows down during a monitor or
  bar-position change.
- Verified on Omarchy 4.0.3-1 with the bar on the left edge and with a second
  (headless) Hyprland output: each output gets its own bar instance, and the
  hover preview maps a workspace on the other monitor with that monitor's
  geometry.

## 3.1.0

- **App icons work again on Omarchy 4.0.3.** The 4.0.3 shell hands bar-widget
  plugins a scoped API whose app library is empty, which left every
  `app:<icon>` label as a blank gap and hid the picker's APPS and ON THIS
  WORKSPACE sections. Desktop entries and icon lookups now go straight to
  Quickshell, and the class-to-app matching lives in the tested logic module
  with StartupWMClass first, then the desktop id, then the app name.
- **Station-board redesign** of the editor, icon picker, and hover preview in
  the flat monospace language shared with Idle Screen Counter: a header with a
  blinking mark and a live readout, hairline rules instead of separators,
  zero-padded row indices with a filled square for workspaces that hold
  windows, per-row window counts, uppercase letter-spaced captions, and
  bordered caption-size buttons in a footer row. Corner radius follows the
  theme as-is.
- The hover preview card now names the workspace, counts its windows, and
  reports the monitor it maps and whether anything floats.
- Picker sections show their counts, and the hero shows the icon being edited.
- Static checks pin the Quickshell desktop-entry path and fail if the shell's
  app library is reintroduced. Tested platform badge moved to Omarchy 4.0.3.

## 3.0.1

- Workspace occupancy, app matching, and hover previews now use Quickshell's
  complete Hyprland toplevel registry. This fixes missing sibling windows when
  one application owns multiple surfaces.
- Add/remove decisions moved into a shared, Qt-free logic module with
  executable coverage for legacy pin migration, lowest-free-slot selection,
  rapid adds, full capacity, occupied-workspace protection, saved-label rows,
  invalid IDs, and label cleanup.
- Malformed saved label data can no longer create editor rows beyond the
  plugin's 20 empty-slot limit; genuine live Hyprland workspaces remain
  unbounded.
- Added reproducible static/native release checks, GitHub Actions, local sync
  tooling, issue and pull-request templates, contribution guidance, and a
  maintainer handoff.

## 3.0.0

**Breaking: the plugin id changed** from `wes.workspaces` to
`io.github.wbuf81.workspace-labels`, to meet the Omarchy marketplace's
requirement that ids be globally unique and permanent. Done before listing,
since the id cannot change afterwards.

If you installed the earlier id, the settings under your old `shell.json`
layout entry (labels, pinned) need to move to the new one, and any keybinding
or script calling `omarchy-shell wes.workspaces ...` needs the new name.

- README now documents removal as well as installation.
- LICENSE and README document third-party components: none are bundled; glyphs
  and app icons come from the font and icon themes already on the machine.

## 2.3.0

- **App icons.** A workspace icon can now be a real application icon instead of
  a Nerd Font glyph, stored as `app:<icon-name>` and resolved through the
  shell's AppLibrary. Existing configs are untouched — no glyph starts with
  `app:`.
- The picker gained an **APPS** section listing every installed app, and an
  **ON THIS WORKSPACE** row that matches each running window's class against
  the desktop entry's `StartupWMClass`. That indirection matters: Brave's class
  is `brave-browser` but its icon is `brave-desktop`, so a naive class lookup
  returns the generic fallback.
- The bar button now builds its own content row rather than using
  WidgetButton's text label, since an app icon is an Image. As a side effect
  labels render as PlainText, so the rich-text escaping is gone entirely and a
  name like `R&D` or `<3` is safe by construction rather than by escaping.

## 2.2.0

- `preview` / `unpreview` IPC verbs, so a workspace can be peeked at from a
  keybinding rather than only by hovering.
- Screenshots regenerated against the current build.

## 2.1.0

- **Hover previews.** Hovering a workspace draws a scaled map of it, each
  window captured through Hyprland's toplevel export and placed at its real
  position and size. Works for workspaces you are not currently on — those
  have no single screenshot to grab, because screencopy captures an output and
  an output only ever shows the active workspace.
- New `hoverPreview` setting (default on).
- Fixed the preview card clipping its own content: `contentWidth` is the
  card's outer size, and `PopupCard.fittedContentHeight` adds the padding
  inset while `fittedContentWidth` does not.

## 2.0.0

- Rebuilt the editor on `Ui.Panel` + `Ui.KeyboardPanel`, the machinery behind
  the built-in wifi / volume / display menus. The editor now takes real
  keyboard focus, scrolls and clamps inside the screen, and hands the popout
  slot over correctly.
- Fixed the editor becoming permanently unopenable after the first click-away.
  `PopupCard.close()` assigns `open` directly when its owner has no `close()`,
  which destroyed the binding for good.
- Inline icon picker replacing the per-row dropdown, which could not take
  keyboard focus and was clipped by the scroll area.
- `+` to add a workspace and a per-row remove, backed by an explicit `pinned`
  list (seeded from the old `minWorkspaces`).
- Keyboard navigation: `j`/`k`, `Enter`, `i`, `a`, `x`, `Esc`.
- Scroll the bar to change workspace.
- Settings writes are staged and expire after 1.5s, so rapid edits can't
  clobber each other and an external `omarchy bar set` still wins.
- Labels are escaped before being wrapped as rich text, and a workspace with
  both fields cleared falls back to its number rather than becoming an
  invisible, unclickable gap.
