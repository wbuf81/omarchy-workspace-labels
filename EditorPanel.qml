import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Ui
import qs.Commons

// The editor: a station board listing every workspace worth a row, with the
// icon picker swapped in place when one is being chosen. Built on
// KeyboardPanel so it takes real keyboard focus, clamps inside the screen, and
// hands the bar's popout slot over correctly.
KeyboardPanel {
  id: panel
  required property var host

  focusTarget: keyCatcher
  contentWidth: panel.fittedContentWidth(Style.space(420))
  contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(600))

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    // Stand down while any field owns input, or typing a name would be eaten
    // as j/k/x navigation.
    blocked: host.focusedFields > 0
    onCloseRequested: host.showPicker ? host.closePicker() : host.close()
    onTabRequested: function(direction) { host.switchPanel(direction) }
    onMoveRequested: function(dx, dy) { if (dy !== 0 && !host.showPicker) host.moveTarget(dy) }
    onActivateRequested: if (!host.showPicker) host.editTarget()
    onDeleteRequested: if (!host.showPicker && host.editorTarget > 0) host.removeWorkspace(host.editorTarget)
    onTextKey: function(t) {
      if (host.showPicker) return
      if (t === "i" && host.editorTarget > 0) host.openPicker(host.editorTarget)
      else if (t === "a" || t === "+") host.addWorkspace()
    }

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > scrollArea.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
      Binding {
        target: scrollArea.contentItem
        property: "interactive"
        value: panelColumn.implicitHeight > scrollArea.height
      }

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(12)

        // ---------- station row ----------
        Item {
          width: parent.width
          height: Math.max(stationLeft.implicitHeight, stationStatus.implicitHeight, Style.space(22))

          Row {
            id: stationLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            // In the picker the mark gives way to the icon being edited,
            // which may be a glyph or an app image.
            Mark {
              visible: !host.showPicker
              anchors.verticalCenter: parent.verticalCenter
              blinking: host.opened && !host.showPicker
            }

            Item {
              id: heroIcon
              visible: host.showPicker
              anchors.verticalCenter: parent.verticalCenter
              readonly property string current: host.showPicker ? host.labelFor(host.pickerFor).icon : ""
              readonly property bool isApp: host.isAppIcon(heroIcon.current)
              width: visible ? Style.space(22) : 0
              height: width

              Text {
                anchors.centerIn: parent
                visible: !heroIcon.isApp
                text: heroIcon.current !== "" ? heroIcon.current : "—"
                textFormat: Text.PlainText
                color: host.ink
                font.family: host.panelFont
                font.pixelSize: Style.font.title
              }

              Image {
                anchors.fill: parent
                visible: heroIcon.isApp
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
                sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
                source: heroIcon.isApp ? host.appIconSource(host.appIconName(heroIcon.current)) : ""
                asynchronous: true
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: host.showPicker ? "CHOOSE ICON" : "WORKSPACES"
              textFormat: Text.PlainText
              color: host.ink
              font.family: host.panelFont
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: 1.8
            }
          }

          Caption {
            id: stationStatus
            anchors.left: stationLeft.right
            anchors.leftMargin: Style.space(12)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            text: host.showPicker
              ? "workspace " + host.pad(host.pickerFor) + "  ·  "
                + (host.workspaceApps.length + host.filteredIcons.length + host.filteredApps.length) + " icons"
              : host.pad(host.editableIds().length) + " rows  ·  " + host.pad(host.liveCount) + " live"
          }
        }

        Rule {}

        // ---------- labels ----------
        Item {
          visible: !host.showPicker
          width: parent.width
          height: labelsHeader.implicitHeight

          PanelSectionHeader {
            id: labelsHeader
            anchors.left: parent.left
            text: "LABELS"
            foreground: host.ink
            fontFamily: host.panelFont
          }
          Caption {
            anchors.right: parent.right
            anchors.baseline: labelsHeader.baseline
            text: {
              var focusedWs = Hyprland.focusedWorkspace
              return focusedWs ? "now  " + host.pad(focusedWs.id) + "  " + host.displayFor(focusedWs.id).name : ""
            }
          }
        }

        Column {
          width: parent.width
          visible: !host.showPicker
          spacing: 0

          Repeater {
            model: host.editableIds()

            Column {
              id: editRow
              required property int modelData
              required property int index
              readonly property var wsLabel: host.labelFor(editRow.modelData)
              readonly property bool targeted: host.editorTarget === editRow.modelData
              readonly property int windows: host.toplevelsForWorkspace(editRow.modelData).length
              readonly property bool live: editRow.windows > 0
              readonly property bool focusedWs: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === editRow.modelData
              width: parent.width

              Rule { visible: editRow.index > 0; opacity: 0.7 }

              Rectangle {
                width: parent.width
                height: rowLayout.implicitHeight + Style.space(10)
                radius: Style.cornerRadius
                color: editRow.targeted ? host.well : "transparent"

                // The keyboard cursor: a hairline of accent down the left edge.
                Rectangle {
                  visible: editRow.targeted
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: Style.space(2)
                  color: Color.accent
                }

                RowLayout {
                  id: rowLayout
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  // Live mark: filled while the workspace holds windows, an
                  // outline when it is only a reserved slot.
                  Rectangle {
                    Layout.preferredWidth: Style.space(6)
                    Layout.preferredHeight: Style.space(6)
                    color: editRow.live ? (editRow.focusedWs ? Color.accent : host.ink) : "transparent"
                    border.width: editRow.live ? 0 : 1
                    border.color: host.faint
                  }

                  Caption {
                    Layout.preferredWidth: Style.space(18)
                    text: host.pad(editRow.modelData)
                    color: editRow.targeted ? Color.accent : (editRow.focusedWs ? host.ink : host.dim)
                    font.bold: true
                    font.letterSpacing: 0.6
                  }

                  PanelActionButton {
                    readonly property bool usesApp: host.isAppIcon(editRow.wsLabel.icon)
                    iconText: usesApp ? "" : (editRow.wsLabel.icon !== "" ? editRow.wsLabel.icon : "—")
                    tooltipText: "Choose icon for workspace " + editRow.modelData
                    bordered: true
                    foreground: host.ink
                    fontFamily: host.panelFont
                    onClicked: host.openPicker(editRow.modelData)

                    Image {
                      visible: parent.usesApp
                      anchors.centerIn: parent
                      width: Style.space(17)
                      height: width
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
                      sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
                      source: parent.usesApp ? host.appIconSource(host.appIconName(editRow.wsLabel.icon)) : ""
                      asynchronous: true
                    }
                  }

                  TextField {
                    id: nameField
                    Layout.fillWidth: true
                    height: Style.spacing.controlHeight
                    text: editRow.wsLabel.name
                    placeholderText: "name"
                    foreground: host.ink
                    font.family: host.panelFont
                    onEditingFinished: host.setName(editRow.modelData, text)
                    onAccepted: { host.setName(editRow.modelData, text); keyCatcher.forceActiveFocus() }
                    Keys.onEscapePressed: function(event) { host.escapeFrom(); event.accepted = true }
                    onActiveFocusChanged: host.noteFieldFocus(activeFocus)
                    Component.onDestruction: if (activeFocus) host.noteFieldFocus(false)

                    // Opening from a right-click (or from "+") drops the cursor
                    // straight into that workspace's name.
                    function grabIfTargeted() {
                      // Deferred through Qt.callLater, so the bar may have torn
                      // this row down (monitor or position change) first.
                      if (!host || !host.autoFocusTarget) return
                      if (host.opened && !host.showPicker && editRow.targeted) {
                        host.autoFocusTarget = false
                        nameField.forceActiveFocus()
                      }
                    }

                    Component.onCompleted: Qt.callLater(nameField.grabIfTargeted)

                    Connections {
                      target: panel.host
                      function onEditorTargetChanged() { Qt.callLater(nameField.grabIfTargeted) }
                      function onOpenedChanged() { Qt.callLater(nameField.grabIfTargeted) }
                      function onAutoFocusTargetChanged() { Qt.callLater(nameField.grabIfTargeted) }
                    }
                  }

                  Caption {
                    Layout.preferredWidth: Style.space(64)
                    horizontalAlignment: Text.AlignRight
                    font.letterSpacing: 0.6
                    text: editRow.live
                      ? editRow.windows + (editRow.windows === 1 ? " window" : " windows")
                      : "empty"
                    color: editRow.live ? host.dim : host.faint
                  }

                  PanelActionButton {
                    iconText: "×"
                    tooltipText: editRow.live
                      ? "Workspace " + editRow.modelData + " still has windows"
                      : "Remove workspace " + editRow.modelData
                    foreground: host.ink
                    opacity: editRow.live ? 0.25 : 0.8
                    fontFamily: host.panelFont
                    onClicked: host.removeWorkspace(editRow.modelData)
                  }
                }
              }
            }
          }
        }

        // ---------- icon picker ----------
        IconPicker {
          width: parent.width
          visible: host.showPicker
          host: panel.host
        }

        // ---------- footer ----------
        Rule { visible: !host.showPicker }

        Caption {
          visible: !host.showPicker
          width: parent.width
          font.letterSpacing: 0.8
          elide: Text.ElideNone
          wrapMode: Text.WordWrap
          lineHeight: 1.35
          text: "j/k move  ·  enter rename  ·  i icon\na add  ·  x remove  ·  esc close"
        }

        Item {
          visible: !host.showPicker
          width: parent.width
          height: Math.max(footNote.implicitHeight, footButtons.implicitHeight)

          Caption {
            id: footNote
            anchors.left: parent.left
            anchors.right: footButtons.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: host.canAdd
              ? "slot " + host.pad(host.nextFreeId()) + " free  ·  " + host.maxWorkspace + " max"
              : "all " + host.maxWorkspace + " slots used"
          }

          Row {
            id: footButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Button {
              text: "RESET"
              bordered: true
              foreground: host.ink
              accent: Color.accent
              fontFamily: host.panelFont
              fontSize: Style.font.caption
              onClicked: host.resetLabels()
            }

            Button {
              text: host.canAdd ? "ADD " + host.pad(host.nextFreeId()) : "FULL"
              iconText: "+"
              bordered: true
              selected: true
              enabled: host.canAdd
              opacity: host.canAdd ? 1 : 0.4
              foreground: host.ink
              accent: Color.accent
              fontFamily: host.panelFont
              fontSize: Style.font.caption
              onClicked: host.addWorkspace()
            }
          }
        }
      }
    }
  }
}
