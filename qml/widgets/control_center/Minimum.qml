import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    property real currentVolume: 0.65

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

        WidgetIconGlyph {
            glyph: root.currentVolume === 0 ? "󰖁" : "󰕾"
            size: 16
            color: StyleTokens.accent
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }

        WidgetTextView {
            text: Math.round(root.currentVolume * 100) + "%"
            role: "metric"
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
