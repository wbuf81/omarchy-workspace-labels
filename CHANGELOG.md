# Changelog

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
