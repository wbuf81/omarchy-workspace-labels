import QtQuick
import Quickshell.Wayland
import qs.Commons

// One window inside the preview's screen well, placed in real Hyprland
// coordinates scaled by `sx`. Capture goes through ScreencopyView pointed at
// the toplevel's `wayland` handle: a HyprlandToplevel is not itself a capture
// source, it only carries a reference to one. Single-shot on purpose; a live
// feed per window is far too expensive for a hover.
Rectangle {
  id: tile
  required property var host
  required property var win
  required property real sx
  required property real originX
  required property real originY

  x: Math.round((win.ax - originX) * sx)
  y: Math.round((win.ay - originY) * sx)
  width: Math.max(3, Math.round(win.aw * sx))
  height: Math.max(3, Math.round(win.ah * sx))
  color: Color.popups.background
  border.width: 1
  border.color: Util.alpha(host.ink, win.floating ? 0.45 : 0.22)
  radius: 0
  clip: true

  ScreencopyView {
    anchors.fill: parent
    captureSource: tile.win.toplevel ? tile.win.toplevel.wayland : null
    live: false
    paintCursor: false
  }
}
