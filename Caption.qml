import QtQuick
import qs.Commons

// Station caption: uppercase, letter-spaced, dim. The one small voice every
// surface in this plugin speaks with.
Text {
  textFormat: Text.PlainText
  color: Util.alpha(Color.popups.text, 0.55)
  font.family: Style.font.family
  font.pixelSize: Style.font.caption
  font.letterSpacing: 1.4
  font.capitalization: Font.AllUppercase
  elide: Text.ElideRight
}
