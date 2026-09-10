import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false
    property int elapsedSeconds: 0

    readonly property real diameter: widgetContext ? widgetContext.circleDiameter : Math.min(width, height)

    anchors.fill: parent

    WidgetProgressRing {
        anchors.fill: parent
        value: (root.elapsedSeconds % 60) / 60.0
        fillColor: StyleTokens.accent
        trackColor: StyleTokens.track
        strokeWidth: Math.max(2.5, Math.min(4, root.diameter * 0.06))
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        WidgetIconGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "󰔛"
            size: 13
            color: StyleTokens.accent
            widgetContext: root.widgetContext
        }

        WidgetTimerClock {
            mode: "stopwatch"
            representation: "circle"
            running: false
            elapsedSeconds: root.elapsedSeconds
            colorOverride: StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }
    }
}