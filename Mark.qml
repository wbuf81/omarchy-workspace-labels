import QtQuick
import qs.Commons

// The status mark from a departure board: an accent square that blinks in
// steps(1), no easing.
Rectangle {
  property bool blinking: false
  width: Style.space(6)
  height: width
  color: Color.accent

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
