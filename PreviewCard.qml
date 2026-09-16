import QtQuick
import Quickshell.Hyprland
import qs.Ui
import qs.Commons

// The hover preview: a station-board card with the workspace's number and
// name, a screen well holding its windows at their real positions, and a
// footer naming the monitor.
PopupCard {
  id: card
  required property var host

  anchorItem: host.hoverAnchor ? host.hoverAnchor : host.grid
  owner: host.hoverOwner
  bar: host.bar
  triggerMode: "hover"
  open: host.hoverPreviewId > 0 && host.previewMonitor !== null && host.previewWindows.length > 0

  // contentWidth/Height are the card's OUTER size. fittedContentHeight adds
  // the padding+border inset for you; fittedContentWidth does not, so the
  // horizontal one has to be added by hand or the card is exactly one inset
  // too narrow and clips the right edge of its own content.
  readonly property real horizontalContentInset: card.padding * 2
    + Border.left(card.borderSpec) + Border.right(card.borderSpec)

  contentWidth: card.fittedContentWidth(host.previewBoxWidth + card.horizontalContentInset)
  contentHeight: card.fittedContentHeight(
    previewHead.height + host.previewBoxHeight + previewFoot.height + Style.space(8) * 2)

  readonly property int floatingCount: {
    var n = 0
    for (var i = 0; i < host.previewWindows.length; i++) if (host.previewWindows[i].floating) n++
    return n
  }

  Column {
    anchors.centerIn: parent
    width: host.previewBoxWidth
    spacing: Style.space(8)

    // ---------- board header ----------
    Item {
      id: previewHead
      width: parent.width
      height: Math.max(previewTitle.implicitHeight, previewCount.implicitHeight)

      Mark {
        id: previewMark
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(5)
      }
      Caption {
        id: previewTitle
        anchors.left: previewMark.right
        anchors.leftMargin: Style.space(7)
        anchors.right: previewCount.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        color: host.ink
        font.bold: true
        text: host.pad(host.hoverPreviewId) + "  " + host.displayFor(host.hoverPreviewId).name
          + (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === host.hoverPreviewId ? "  ·  now" : "")
      }
      Caption {
        id: previewCount
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: {
          var n = host.previewWindows.length
          return n + (n === 1 ? " window" : " windows")
        }
      }
    }

    // Stands in for the monitor. Everything inside is positioned in real
    // Hyprland coordinates scaled by `sx`, so relative sizes and positions
    // survive.
    Rectangle {
      id: screenRect
      width: parent.width
      height: host.previewBoxHeight
      radius: Style.cornerRadius
      color: host.screenWell
      border.width: 1
      border.color: host.line
      clip: true

      readonly property real sx: host.previewScreen && host.previewScreen.width > 0
        ? width / host.previewScreen.width : 0
      readonly property real originX: host.previewScreen ? host.previewScreen.x : 0
      readonly property real originY: host.previewScreen ? host.previewScreen.y : 0

      // Instrument-console chrome: a quiet reference grid under the windows,
      // edge ticks at the midpoints, corner frames above everything.
      Repeater {
        model: 7
        Rectangle {
          required property int index
          x: Math.round(screenRect.width * (index + 1) / 8)
          y: 0
          width: 1
          height: screenRect.height
          color: Util.alpha(host.ink, 0.05)
        }
      }
      Repeater {
        model: 3
        Rectangle {
          required property int index
          x: 0
          y: Math.round(screenRect.height * (index + 1) / 4)
          width: screenRect.width
          height: 1
          color: Util.alpha(host.ink, 0.05)
        }
      }

      Repeater {
        model: host.previewWindows

        WindowTile {
          required property var modelData
          host: card.host
          win: modelData
          sx: screenRect.sx
          originX: screenRect.originX
          originY: screenRect.originY
          mode: card.host.previewMode
        }
      }

      // Edge ticks.
      Rectangle { x: Math.round(screenRect.width / 2) - 2; y: 0; width: 4; height: 3; color: Util.alpha(Color.accent, 0.6) }
      Rectangle { x: Math.round(screenRect.width / 2) - 2; y: screenRect.height - 3; width: 4; height: 3; color: Util.alpha(Color.accent, 0.6) }
      Rectangle { x: 0; y: Math.round(screenRect.height / 2) - 2; width: 3; height: 4; color: Util.alpha(Color.accent, 0.6) }
      Rectangle { x: screenRect.width - 3; y: Math.round(screenRect.height / 2) - 2; width: 3; height: 4; color: Util.alpha(Color.accent, 0.6) }

      CornerFrame {
        anchors.fill: parent
        color: Util.alpha(Color.accent, 0.75)
        arm: Style.space(9)
      }
    }

    // ---------- board footer ----------
    Item {
      id: previewFoot
      width: parent.width
      height: Math.max(previewMonitorText.implicitHeight, previewFloating.implicitHeight)

      Caption {
        id: previewMonitorText
        anchors.left: parent.left
        anchors.right: previewFloating.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: host.previewMonitor
          ? String(host.previewMonitor.name || "") + "  ·  " + host.previewMonitor.width + "×" + host.previewMonitor.height
            + (host.previewScreen && host.previewScreen.scale !== 1 ? "  ·  " + host.previewScreen.scale + "×" : "")
          : ""
      }
      Caption {
        id: previewFloating
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: card.floatingCount > 0 ? card.floatingCount + " floating" : "tiled"
      }
    }
  }
}
