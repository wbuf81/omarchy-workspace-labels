import QtQuick
import Quickshell.Wayland
import qs.Commons

// One window inside the preview's screen well, placed in real Hyprland
// coordinates scaled by `sx`.
//
// In `capture` mode the window is screenshotted once through ScreencopyView
// pointed at the toplevel's `wayland` handle (a HyprlandToplevel is not itself
// a capture source, it only carries a reference to one). Single-shot on
// purpose; a live feed per window is far too expensive for a hover. If the
// capture yields nothing, or in `map` mode, the window is drawn as a block
// with its app icon instead, so the preview never shows a black hole and
// never has to show screen content at all.
Rectangle {
  id: tile
  required property var host
  required property var win
  required property real sx
  required property real originX
  required property real originY
  property string mode: "capture"

  readonly property string iconName: host.iconForClass(win.cls)
  readonly property bool wantsCapture: mode === "capture" && win.toplevel && win.toplevel.wayland
  // Give a capture its chance before falling back; `hasContent` flips once a
  // frame lands.
  property bool settled: false
  readonly property bool captured: wantsCapture && shot.hasContent
  readonly property bool showBlock: !wantsCapture || (settled && !shot.hasContent)

  x: Math.round((win.ax - originX) * sx)
  y: Math.round((win.ay - originY) * sx)
  width: Math.max(3, Math.round(win.aw * sx))
  height: Math.max(3, Math.round(win.ah * sx))
  color: showBlock ? Util.alpha(host.ink, 0.06) : Color.popups.background
  border.width: 1
  border.color: Util.alpha(host.ink, win.floating ? 0.45 : 0.22)
  radius: 0
  clip: true

  Timer {
    interval: 600
    running: tile.wantsCapture
    onTriggered: tile.settled = true
  }

  ScreencopyView {
    id: shot
    anchors.fill: parent
    visible: tile.wantsCapture
    captureSource: tile.wantsCapture ? tile.win.toplevel.wayland : null
    live: false
    paintCursor: false
  }

  // Map block: the app icon centred, the class below it when there is room.
  Column {
    visible: tile.showBlock
    anchors.centerIn: parent
    spacing: Style.space(4)

    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: tile.iconName !== "" && tile.width >= Style.space(24) && tile.height >= Style.space(24)
      width: Math.min(Style.space(28), Math.round(Math.min(tile.width, tile.height) * 0.45))
      height: width
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
      sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
      source: tile.iconName !== "" ? host.appIconSource(tile.iconName) : ""
      asynchronous: true
    }

    Caption {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: tile.width >= Style.space(60) && tile.height >= Style.space(44)
      width: Math.min(implicitWidth, tile.width - Style.space(8))
      font.letterSpacing: 0.6
      font.pixelSize: Style.font.caption - 1
      text: tile.win.cls
    }
  }

  // Badge: a small app icon in the corner of a captured window, so the
  // thumbnail reads even when the screenshot is a wall of text.
  Image {
    visible: tile.captured && tile.iconName !== "" && tile.width >= Style.space(40) && tile.height >= Style.space(30)
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: Style.space(3)
    width: Style.space(12)
    height: width
    fillMode: Image.PreserveAspectFit
    sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
    sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
    source: tile.iconName !== "" ? host.appIconSource(tile.iconName) : ""
    asynchronous: true
  }
}
