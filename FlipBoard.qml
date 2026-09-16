import QtQuick

// A row of stepped flip tiles that renders `value` one character per tile.
// Pure QtQuick on purpose: the panel feeds it theme colors from outside.
// Shared with Idle Screen Counter (same author, MIT), reduced to the one
// board style used here.
Item {
  id: board

  property string value: "00"
  property real tileWidth: 12
  property real tileHeight: 16
  property real gap: 2
  property color foreground: "#c0caf5"
  property color accent: "#7aa2f7"
  property color dim: "#565f89"
  property color line: "#2f3349"
  property color well: "#1a1b26"
  property string fontFamily: "monospace"
  property real speed: 1
  property bool animated: true

  implicitWidth: row.implicitWidth
  implicitHeight: tileHeight

  Row {
    id: row
    spacing: board.gap

    Repeater {
      model: board.value.length

      Loader {
        id: slot
        required property int index
        readonly property string character: board.value.charAt(index)
        width: board.tileWidth
        height: board.tileHeight

        // The character rides along as an initial property so a freshly built
        // tile settles silently instead of flipping in from its default.
        Component.onCompleted: setSource(Qt.resolvedUrl("FlipStep.qml"), { character: character })

        onCharacterChanged: if (item) item.character = character
        onLoaded: {
          item.foreground = Qt.binding(function() { return board.foreground })
          item.accent = Qt.binding(function() { return board.accent })
          item.dim = Qt.binding(function() { return board.dim })
          item.line = Qt.binding(function() { return board.line })
          item.well = Qt.binding(function() { return board.well })
          item.fontFamily = Qt.binding(function() { return board.fontFamily })
          item.speed = Qt.binding(function() { return board.speed })
          item.animated = Qt.binding(function() { return board.animated })
        }
      }
    }
  }
}
