import QtQuick
import qs.Ui
import qs.Commons

// The inline icon picker: search, the apps running on the workspace being
// edited, the verified glyph set, every installed app, and a field for any
// glyph. Inline rather than a nested dropdown because a QQC.Popup inside the
// panel would be clipped by the ScrollView and could not take keyboard focus.
Column {
  id: picker
  required property var host

  spacing: Style.space(10)

  TextField {
    id: searchField
    width: parent.width
    height: Style.spacing.controlHeight
    text: host.iconQuery
    placeholderText: "Search icons…"
    foreground: host.ink
    font.family: host.panelFont
    onTextChanged: host.iconQuery = text
    Keys.onEscapePressed: function(event) { host.escapeFrom(); event.accepted = true }
    onActiveFocusChanged: host.noteFieldFocus(activeFocus)
    Component.onDestruction: if (activeFocus) host.noteFieldFocus(false)
    // The picker is summoned by a click, so put the caret where the user is
    // already looking.
    onVisibleChanged: if (visible) Qt.callLater(searchField.forceActiveFocus)
    Component.onCompleted: if (visible) Qt.callLater(searchField.forceActiveFocus)
  }

  // Apps running on this workspace, resolved class -> StartupWMClass.
  Item {
    visible: host.workspaceApps.length > 0
    width: parent.width
    height: onWorkspaceHeader.implicitHeight
    PanelSectionHeader {
      id: onWorkspaceHeader
      anchors.left: parent.left
      text: "ON THIS WORKSPACE"
      foreground: host.ink
      fontFamily: host.panelFont
    }
    Caption { anchors.right: parent.right; anchors.baseline: onWorkspaceHeader.baseline; text: host.pad(host.workspaceApps.length) }
  }

  Flow {
    width: parent.width
    visible: host.workspaceApps.length > 0
    spacing: Style.space(6)

    Repeater {
      model: host.workspaceApps

      PanelActionButton {
        required property var modelData
        readonly property bool selected: host.labelFor(host.pickerFor).icon === host.appIconPrefix + modelData.icon
        iconText: ""
        tooltipText: modelData.name
        bordered: true
        foreground: selected ? Color.accent : host.ink
        onClicked: host.chooseIcon(host.appIconPrefix + modelData.icon)

        Image {
          anchors.centerIn: parent
          width: Style.space(18)
          height: width
          fillMode: Image.PreserveAspectFit
          sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
          sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
          source: host.appIconSource(modelData.icon)
          asynchronous: true
        }
      }
    }
  }

  Item {
    visible: host.filteredIcons.length > 0
    width: parent.width
    height: glyphHeader.implicitHeight
    PanelSectionHeader {
      id: glyphHeader
      anchors.left: parent.left
      text: "GLYPHS"
      foreground: host.ink
      fontFamily: host.panelFont
    }
    Caption { anchors.right: parent.right; anchors.baseline: glyphHeader.baseline; text: host.pad(host.filteredIcons.length) }
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)

    Repeater {
      model: host.filteredIcons

      PanelActionButton {
        required property var modelData
        readonly property bool selected: host.labelFor(host.pickerFor).icon === modelData.value
        iconText: modelData.value !== "" ? modelData.value : "—"
        tooltipText: String(modelData.label).replace(modelData.value, "").trim() + "   " + modelData.description
        bordered: true
        foreground: selected ? Color.accent : host.ink
        fontFamily: host.panelFont
        onClicked: host.chooseIcon(modelData.value)
      }
    }
  }

  Item {
    visible: host.filteredApps.length > 0
    width: parent.width
    height: appsHeader.implicitHeight
    PanelSectionHeader {
      id: appsHeader
      anchors.left: parent.left
      text: "APPS"
      foreground: host.ink
      fontFamily: host.panelFont
    }
    Caption { anchors.right: parent.right; anchors.baseline: appsHeader.baseline; text: host.pad(host.filteredApps.length) }
  }

  Flow {
    width: parent.width
    visible: host.filteredApps.length > 0
    spacing: Style.space(6)

    Repeater {
      model: host.filteredApps

      PanelActionButton {
        required property var modelData
        readonly property bool selected: host.labelFor(host.pickerFor).icon === host.appIconPrefix + modelData.icon
        iconText: ""
        tooltipText: modelData.name
        bordered: true
        foreground: selected ? Color.accent : host.ink
        onClicked: host.chooseIcon(host.appIconPrefix + modelData.icon)

        Image {
          anchors.centerIn: parent
          width: Style.space(18)
          height: width
          fillMode: Image.PreserveAspectFit
          sourceSize.width: Math.max(1, width * Screen.devicePixelRatio)
          sourceSize.height: Math.max(1, height * Screen.devicePixelRatio)
          source: host.appIconSource(modelData.icon)
          asynchronous: true
        }
      }
    }
  }

  Caption {
    width: parent.width
    visible: host.filteredIcons.length === 0 && host.filteredApps.length === 0
    text: "No matching icons  ·  paste any glyph below"
  }

  Rule {}

  Item {
    width: parent.width
    height: Math.max(glyphNote.implicitHeight, pickerButtons.implicitHeight)

    Caption {
      id: glyphNote
      anchors.left: parent.left
      anchors.right: pickerButtons.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: "Any glyph"
    }

    Row {
      id: pickerButtons
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      TextField {
        id: customGlyph
        width: Style.space(64)
        height: Style.spacing.controlHeight
        anchors.verticalCenter: parent.verticalCenter
        placeholderText: "glyph"
        horizontalAlignment: Text.AlignHCenter
        foreground: host.ink
        font.family: host.panelFont
        onAccepted: host.chooseIcon(text)
        Keys.onEscapePressed: function(event) { host.escapeFrom(); event.accepted = true }
        onActiveFocusChanged: host.noteFieldFocus(activeFocus)
        Component.onDestruction: if (activeFocus) host.noteFieldFocus(false)
      }

      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: "USE"
        bordered: true
        selected: true
        foreground: host.ink
        accent: Color.accent
        fontFamily: host.panelFont
        fontSize: Style.font.caption
        onClicked: host.chooseIcon(customGlyph.text)
      }

      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: "BACK"
        iconText: "󰁍"
        bordered: true
        foreground: host.ink
        accent: Color.accent
        fontFamily: host.panelFont
        fontSize: Style.font.caption
        onClicked: host.closePicker()
      }
    }
  }
}
