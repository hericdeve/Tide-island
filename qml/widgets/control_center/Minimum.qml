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
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

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
            font.pixelSize: Math.round(16 * root.iconFontSize / 18.0)
            color: StyleTokens.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Math.round(root.currentVolume * 100) + "%"
            font.family: root.textFontFamily
            font.pixelSize: Math.round(14 * root.bodyFontSize / 16.0)
            font.weight: Font.DemiBold
            color: StyleTokens.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
