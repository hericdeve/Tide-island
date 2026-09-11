import QtQuick
import IslandBackend
import "."
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property real diameter: (widgetContext && widgetContext.circleDiameter !== undefined && widgetContext.circleDiameter > 0) ? widgetContext.circleDiameter : Math.min(width, height)

    anchors.fill: parent

    WidgetProgressRing {
        anchors.fill: parent
        value: TimerService.mode === "countdown" ? TimerService.progress : ((TimerService.elapsedSeconds % 60) / 60.0)
        fillColor: TimerService.running ? StyleTokens.accent : StyleTokens.textSecondary
        trackColor: StyleTokens.track
        strokeWidth: Math.max(2.5, Math.min(4, root.diameter * 0.06))
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        WidgetIconGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: TimerService.mode === "stopwatch" ? "󰔛" : "󰔟"
            size: 13
            color: TimerService.running ? StyleTokens.accent : StyleTokens.textSecondary
            widgetContext: root.widgetContext
        }

        WidgetTimerClock {
            mode: TimerService.mode
            representation: "circle"
            running: false
            elapsedSeconds: TimerService.elapsedSeconds
            elapsedMilliseconds: TimerService.elapsedMilliseconds
            totalSeconds: TimerService.totalSeconds
            colorOverride: TimerService.running ? StyleTokens.accent : StyleTokens.textPrimary
            widgetContext: root.widgetContext
        }
    }
}