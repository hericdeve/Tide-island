import QtQuick
import IslandBackend
import "."
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property real requestedContentWidth: 0
    readonly property real requestedContentHeight: 140
    readonly property int bodyFontSize: (widgetContext && widgetContext.bodyFontSize !== undefined) ? widgetContext.bodyFontSize : 16

    anchors.fill: parent
    anchors.margins: 6

    Item {
        anchors.fill: parent

        // 1. Header with mode selector on left and lap/precision indicator on right
        Item {
            id: headerArea
            width: parent.width
            height: 28
            anchors.top: parent.top

            Row {
                id: modeSelector
                spacing: 4
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                WidgetActionButton {
                    variant: "pill"
                    label: "Stopwatch"
                    buttonStyle: TimerService.mode === "stopwatch" ? "primary" : "ghost"
                    widgetContext: root.widgetContext
                    onClicked: TimerService.setMode("stopwatch")
                }

                WidgetActionButton {
                    variant: "pill"
                    label: "Timer"
                    buttonStyle: TimerService.mode === "countdown" ? "primary" : "ghost"
                    widgetContext: root.widgetContext
                    onClicked: TimerService.setMode("countdown")
                }
            }

            // Right header accessories
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Lap count badge (Stopwatch mode)
                Rectangle {
                    visible: TimerService.mode === "stopwatch" && TimerService.laps.length > 0
                    height: 20
                    width: lapText.implicitWidth + 12
                    radius: 10
                    color: StyleTokens.track
                    anchors.verticalCenter: parent.verticalCenter

                    WidgetTextView {
                        id: lapText
                        anchors.centerIn: parent
                        text: "Lap " + (TimerService.laps.length + 1)
                        role: "caption"
                        colorOverride: StyleTokens.accent
                        widgetContext: root.widgetContext
                    }
                }

                // Millisecond precision toggle (.00)
                WidgetActionButton {
                    visible: TimerService.mode === "stopwatch"
                    variant: "pill"
                    label: ".00"
                    buttonStyle: TimerService.showMilliseconds ? "primary" : "ghost"
                    widgetContext: root.widgetContext
                    onClicked: TimerService.showMilliseconds = !TimerService.showMilliseconds
                }

                // Countdown percent remaining
                WidgetTextView {
                    visible: TimerService.mode === "countdown" && TimerService.running
                    text: Math.round(TimerService.progress * 100) + "%"
                    role: "caption"
                    colorOverride: StyleTokens.accent
                    widgetContext: root.widgetContext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // 2. Center Clock Display with optional recent lap split
        Item {
            id: clockArea
            anchors.top: headerArea.bottom
            anchors.bottom: controlsRow.top
            anchors.left: parent.left
            anchors.right: parent.right

            Column {
                anchors.centerIn: parent
                spacing: 2

                WidgetTimerClock {
                    id: timerClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    mode: TimerService.mode
                    representation: "digital"
                    running: false
                    elapsedSeconds: TimerService.elapsedSeconds
                    elapsedMilliseconds: TimerService.elapsedMilliseconds
                    totalSeconds: TimerService.totalSeconds
                    showMilliseconds: TimerService.showMilliseconds && TimerService.mode === "stopwatch"
                    colorOverride: TimerService.running ? StyleTokens.accent : StyleTokens.textPrimaryBright
                    widgetContext: root.widgetContext
                }

                // Most recent lap time split display
                WidgetTextView {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: TimerService.mode === "stopwatch" && TimerService.laps.length > 0
                    text: TimerService.laps.length > 0 ? ("Lap " + TimerService.laps[0].index + ": " + TimerService.laps[0].lapFormatted) : ""
                    role: "caption"
                    colorOverride: StyleTokens.textSecondary
                    widgetContext: root.widgetContext
                }
            }
        }

        // 3. Action Buttons anchored to bottom
        Row {
            id: controlsRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.width < 210 ? 4 : 6

            // Start / Pause button with distinct semantic styles
            WidgetActionButton {
                variant: "capsule"
                icon: TimerService.running ? "󰏤" : "󰐊"
                label: TimerService.running ? "Pause" : "Start"
                buttonStyle: TimerService.running ? "secondary" : "primary"
                widgetContext: root.widgetContext
                onClicked: TimerService.toggle()
            }

            // Lap button (Stopwatch mode only)
            WidgetActionButton {
                visible: TimerService.mode === "stopwatch"
                variant: "capsule"
                icon: "󰑕"
                label: "Lap"
                buttonStyle: "secondary"
                enabled: TimerService.running
                opacity: TimerService.running ? 1.0 : 0.4
                widgetContext: root.widgetContext
                onClicked: TimerService.recordLap()
            }

            // Reset button
            WidgetActionButton {
                variant: "icon"
                icon: "󰑐"
                buttonStyle: "secondary"
                enabled: TimerService.elapsedSeconds > 0 || TimerService.laps.length > 0
                opacity: (TimerService.elapsedSeconds > 0 || TimerService.laps.length > 0) ? 1.0 : 0.4
                widgetContext: root.widgetContext
                onClicked: TimerService.reset()
            }

            // Presets (Countdown mode only)
            WidgetActionButton {
                visible: TimerService.mode === "countdown"
                variant: "pill"
                label: "5m"
                buttonStyle: TimerService.totalSeconds === 300 ? "secondary" : "ghost"
                widgetContext: root.widgetContext
                onClicked: TimerService.setDuration(300)
            }

            WidgetActionButton {
                visible: TimerService.mode === "countdown"
                variant: "pill"
                label: "25m"
                buttonStyle: TimerService.totalSeconds === 1500 ? "secondary" : "ghost"
                widgetContext: root.widgetContext
                onClicked: TimerService.setDuration(1500)
            }
        }
    }
}