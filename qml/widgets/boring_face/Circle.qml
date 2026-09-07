import QtQuick
import "../../island"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property real diameter: Math.min(width, height)
    readonly property real faceScale: Math.max(0.5, Math.min(1.0, 0.62 + (diameter - 44.0) * 0.008))

    anchors.fill: parent

    // Subtle outer boundary circle
    Rectangle {
        anchors.centerIn: parent
        width: root.diameter - 2
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: "#2c2c2e"
    }

    BoringFaceAnimation {
        anchors.centerIn: parent
        customScale: root.faceScale
    }
}
