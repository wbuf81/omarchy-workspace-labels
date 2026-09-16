import QtQuick
import qs.Commons

// Four L-shaped corner accents around whatever this is anchored to, in the
// instrument-console spirit of OmaFinance. Paints nothing along the edges.
Item {
  id: frame
  property color color: Color.accent
  property int arm: Style.space(8)
  property int thickness: 1

  // top-left
  Rectangle { x: 0; y: 0; width: frame.arm; height: frame.thickness; color: frame.color }
  Rectangle { x: 0; y: 0; width: frame.thickness; height: frame.arm; color: frame.color }
  // top-right
  Rectangle { x: frame.width - frame.arm; y: 0; width: frame.arm; height: frame.thickness; color: frame.color }
  Rectangle { x: frame.width - frame.thickness; y: 0; width: frame.thickness; height: frame.arm; color: frame.color }
  // bottom-left
  Rectangle { x: 0; y: frame.height - frame.thickness; width: frame.arm; height: frame.thickness; color: frame.color }
  Rectangle { x: 0; y: frame.height - frame.arm; width: frame.thickness; height: frame.arm; color: frame.color }
  // bottom-right
  Rectangle { x: frame.width - frame.arm; y: frame.height - frame.thickness; width: frame.arm; height: frame.thickness; color: frame.color }
  Rectangle { x: frame.width - frame.thickness; y: frame.height - frame.arm; width: frame.thickness; height: frame.arm; color: frame.color }
}
