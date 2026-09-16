import QtQuick
import Quickshell.Hyprland
import qs.Ui
import qs.Commons
import "Logic.js" as Logic

// One workspace in the bar. The built-in WidgetButton label is switched off
// and the content built here instead, because an app icon is an Image and
// WidgetButton only paints text. Names render as PlainText, so a name like
// "R&D" or "<3" is safe by construction.
WidgetButton {
  id: button
  required property var host
  required property int workspaceId

  readonly property bool occupied: host.hasWindows(workspaceId)
  readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId

  // Named wsLabel, not label: WidgetButton already has an internal `label`
  // item and a plain `label` property would shadow it.
  readonly property var wsLabel: host.displayFor(workspaceId)
  readonly property bool usesAppIcon: host.isAppIcon(wsLabel.icon)

  bar: host.bar
  labelVisible: false
  hasVisualContent: true
  text: ""

  fixedWidth: host.vertical
    ? host.barSize
    : Math.round(buttonContent.implicitWidth + scaledHorizontalMargin * 2)
  fixedHeight: host.barSize

  Row {
    id: buttonContent
    anchors.centerIn: parent
    spacing: Style.space(6)

    Image {
      visible: button.usesAppIcon
      width: visible ? Style.space(16) : 0
      height: width
      anchors.verticalCenter: parent.verticalCenter
      fillMode: Image.PreserveAspectFit
      // Decode at physical pixels, or PNG icons come out upscaled and
      // blurry on HiDPI.
      sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
      sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
      source: button.usesAppIcon ? host.appIconSource(host.appIconName(button.wsLabel.icon)) : ""
      asynchronous: true
    }

    Text {
      visible: !button.usesAppIcon && button.wsLabel.icon !== ""
      text: button.wsLabel.icon
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
    }

    Text {
      id: nameText
      // On a vertical bar only the icon fits. A workspace with no icon
      // falls back to its number there, the way the stock widget paints
      // every workspace; a full name would spill past the bar's width.
      // The tooltip still carries the name.
      visible: nameText.text !== ""
      text: Logic.barName(host.vertical, button.wsLabel.icon, button.wsLabel.name, button.workspaceId)
      textFormat: Text.PlainText
      font.underline: button.focused
      anchors.verticalCenter: parent.verticalCenter
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
    }
  }

  tooltipText: button.wsLabel.name + "  —  right-click to edit"
  opacity: button.occupied || button.focused ? 1 : 0.5
  horizontalMargin: 6
  verticalPadding: 6
  onPressed: function(mouseButton) {
    if (mouseButton === Qt.RightButton || mouseButton === Qt.MiddleButton) host.openFor(button.workspaceId, false)
    else host.focusWorkspace(button.workspaceId)
  }
  onWheelMoved: function(delta) { host.handleWheel(delta) }
  onTooltipHoveredChanged: {
    if (button.tooltipHovered) host.requestPreview(button.workspaceId, button)
    else host.cancelPreview(button.workspaceId)
  }
}
