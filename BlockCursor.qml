import QtQuick
import qs.Commons

// A terminal block cursor, blinking on the same clock as Mark.
Text {
  property bool blinking: true
  text: "█"
  textFormat: Text.PlainText
  color: Color.accent
  font.family: Style.font.family
  font.pixelSize: Style.font.caption

  SequentialAnimation on opacity {
    running: blinking
    loops: Animation.Infinite
    PropertyAction { value: 1 }
    PauseAnimation { duration: 550 }
    PropertyAction { value: 0 }
    PauseAnimation { duration: 550 }
  }
  onBlinkingChanged: if (!blinking) opacity = 1
}
