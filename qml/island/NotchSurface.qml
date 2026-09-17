import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "#000000"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radius: 14
    property real topCornerRadius: 6
    property real bottomCornerRadius: radius

    readonly property real clampedTopCornerRadius: Math.max(0, Math.min(topCornerRadius, width / 2, height / 2))
    readonly property real clampedBottomCornerRadius: Math.max(0, Math.min(bottomCornerRadius, width / 2, height / 2))

    Shape {
        id: surface
        anchors.fill: parent
        z: -1
        asynchronous: false
        layer.enabled: true
        layer.samples: 4

        readonly property real topRadius: root.clampedTopCornerRadius
        readonly property real bottomRadius: root.clampedBottomCornerRadius
        readonly property real strokeW: Math.max(0, root.borderWidth)
        readonly property real halfStroke: strokeW / 2
        readonly property real leftPos: halfStroke
        readonly property real topPos: halfStroke
        readonly property real rightPos: Math.max(leftPos, width - halfStroke)
        readonly property real bottomPos: Math.max(topPos, height - halfStroke)

        ShapePath {
            strokeWidth: surface.strokeW
            strokeColor: surface.strokeW > 0 ? root.borderColor : "transparent"
            fillColor: root.color
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            startX: surface.leftPos
            startY: surface.topPos

            PathQuad {
                controlX: surface.leftPos + surface.topRadius
                controlY: surface.topPos
                x: surface.leftPos + surface.topRadius
                y: surface.topPos + surface.topRadius
            }
            PathLine {
                x: surface.leftPos + surface.topRadius
                y: surface.bottomPos - surface.bottomRadius
            }
            PathQuad {
                controlX: surface.leftPos + surface.topRadius
                controlY: surface.bottomPos
                x: surface.leftPos + surface.topRadius + surface.bottomRadius
                y: surface.bottomPos
            }
            PathLine {
                x: surface.rightPos - surface.topRadius - surface.bottomRadius
                y: surface.bottomPos
            }
            PathQuad {
                controlX: surface.rightPos - surface.topRadius
                controlY: surface.bottomPos
                x: surface.rightPos - surface.topRadius
                y: surface.bottomPos - surface.bottomRadius
            }
            PathLine {
                x: surface.rightPos - surface.topRadius
                y: surface.topPos + surface.topRadius
            }
            PathQuad {
                controlX: surface.rightPos - surface.topRadius
                controlY: surface.topPos
                x: surface.rightPos
                y: surface.topPos
            }
            PathLine {
                x: surface.leftPos
                y: surface.topPos
            }
        }
    }
}
