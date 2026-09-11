import QtQuick
import IslandBackend
import "."
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property real requestedContentWidth: Math.min(220, contentRow.implicitWidth + 16)
    readonly property real requestedContentHeight: 0

    anchors.fill: parent

    Item {
        anchors.fill: parent
        anchors.margins: 2

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            WidgetIconGlyph {
                glyph: TimerService.mode === "stopwatch" ? "󰔛" : "󰔟"
                size: 14
                color: TimerService.running ? StyleTokens.accent : StyleTokens.textSecondary
                widgetContext: root.widgetContext
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: timerClock.implicitWidth
                height: timerClock.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                WidgetTimerClock {
                    id: timerClock
                    anchors.centerIn: parent
                    mode: TimerService.mode
                    representation: "compact"
                    running: false
                    elapsedSeconds: TimerService.elapsedSeconds
                    elapsedMilliseconds: TimerService.elapsedMilliseconds
                    totalSeconds: TimerService.totalSeconds
                    colorOverride: TimerService.running ? StyleTokens.accent : StyleTokens.textPrimary
                    widgetContext: root.widgetContext
                }
            }

            WidgetTextView {
                text: TimerService.running
                    ? (TimerService.mode === "stopwatch" && TimerService.laps.length > 0 ? ("L" + (TimerService.laps.length + 1)) : "Run")
                    : (TimerService.elapsedSeconds > 0 ? "Pause" : "Ready")
                role: "caption"
                colorOverride: TimerService.running ? StyleTokens.accent : StyleTokens.textMuted
                widgetContext: root.widgetContext
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}