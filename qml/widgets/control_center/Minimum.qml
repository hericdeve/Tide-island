import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    property real currentVolume: 0.65

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    Component.onCompleted: SystemServices.requestVolume()

    Connections {
        target: SystemServices
        function onVolumeSnapshotReady(value, muted, errorString) {
            root.currentVolume = Math.max(0, Math.min(1, value));
        }
    }

    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: root.currentVolume === 0 ? "󰖁" : "󰕾"
            font.family: root.iconFontFamily
            font.pixelSize: 16
            color: "#0a84ff"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Math.round(root.currentVolume * 100) + "%"
            font.family: root.textFontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
