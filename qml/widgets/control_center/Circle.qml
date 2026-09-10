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

    readonly property real diameter: Math.min(width, height)

    WidgetProgressRing {
        anchors.fill: parent
        strokeWidth: Math.max(2.5, Math.min(4.5, 3.0 + (root.diameter - 44) * 0.04))
        value: root.currentVolume
        fillColor: StyleTokens.accent
        trackColor: StyleTokens.track
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.max(0, Math.round((root.diameter - 44) * 0.04))

        WidgetIconGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: root.currentVolume === 0 ? "󰖁" : "󰕾"
            size: 14
            color: StyleTokens.accent
            widgetContext: root.widgetContext
        }

        WidgetTextView {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.currentVolume * 100) + "%"
            role: "caption"
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }
    }
}
