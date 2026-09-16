import QtQuick
import qs.Commons

// Hairline rule. Separates sections and rows instead of cards or fills.
Rectangle {
  width: parent ? parent.width : 0
  height: 1
  color: Util.alpha(Color.popups.text, 0.14)
}
