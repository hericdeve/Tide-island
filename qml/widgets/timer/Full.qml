import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    property string mode: "stopwatch"
    property bool running: false
    property int elapsedSeconds: 0
    property int totalSeconds: 300

    readonly property int remainingSeconds: Math.max(0, totalSeconds - elapsedSeconds)
    readonly property real progress: totalSeconds > 0 ? Math.min(1.0, elapsedSeconds / totalSeconds) : 0
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16

    function reset() {
        root.elapsedSeconds = 0;
        root.running = false;
    }

    function setDuration(seconds) {
        root.mode = "countdown";
        root.totalSeconds = seconds;
        root.elapsedSeconds = 0;
        root.running = false;
    }

    Timer {
        interval: 1000
        running: root.running && root.visible
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (root.mode === "stopwatch") {
                root.elapsedSeconds += 1;
            } else if (root.elapsedSeconds < root.totalSeconds) {
                root.elapsedSeconds += 1;
                if (root.elapsedSeconds >= root.totalSeconds)
                    root.running = false;
            }
        }
    }

    anchors.fill: parent
    anchors.margins: 6

    Item {
        anchors.fill: parent

        // 1. Header with mode selector in header place
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
                    buttonStyle: root.mode === "stopwatch" ? "primary" : "ghost"
                    widgetContext: root.widgetContext
                    onClicked: {
                        if (root.mode === "stopwatch")
                            return;
                        root.mode = "stopwatch";
                        root.reset();
                    }
                }

                WidgetActionButton {
                    variant: "pill"
                    label: "Timer"
                    buttonStyle: root.mode === "countdown" ? "primary" : "ghost"
                    widgetContext: root.widgetContext
                    onClicked: {
                        if (root.mode === "countdown")
                            return;
                        root.mode = "countdown";
                        root.reset();
                    }
                }
            }
        }

        // 2. Center Clock Display
        Item {
            id: clockArea
            anchors.top: headerArea.bottom
            anchors.bottom: controlsRow.top
            anchors.left: parent.left
            anchors.right: parent.right

            WidgetTimerClock {
                anchors.centerIn: parent
                mode: root.mode
                representation: "digital"
                running: false
                elapsedSeconds: root.elapsedSeconds
                totalSeconds: root.totalSeconds
                colorOverride: root.running ? StyleTokens.accent : StyleTokens.textPrimaryBright
                widgetContext: root.widgetContext
            }
        }

        // 3. Action Buttons anchored to bottom
        Row {
            id: controlsRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.width < 210 ? 4 : 6

            WidgetActionButton {
                variant: "capsule"
                icon: root.running ? "󰏤" : "󰐊"
                label: root.running ? "Pause" : "Start"
                buttonStyle: "primary"
                widgetContext: root.widgetContext
                onClicked: {
                    if (root.mode === "countdown" && root.elapsedSeconds >= root.totalSeconds)
                        root.elapsedSeconds = 0;
                    root.running = !root.running;
                }
            }

            WidgetActionButton {
                variant: "icon"
                icon: "󰑐"
                buttonStyle: "secondary"
                widgetContext: root.widgetContext
                onClicked: root.reset()
            }

            WidgetActionButton {
                variant: "pill"
                label: "5m"
                buttonStyle: root.mode === "countdown" && root.totalSeconds === 300 ? "secondary" : "ghost"
                widgetContext: root.widgetContext
                onClicked: root.setDuration(300)
            }

            WidgetActionButton {
                variant: "pill"
                label: "25m"
                buttonStyle: root.mode === "countdown" && root.totalSeconds === 1500 ? "secondary" : "ghost"
                widgetContext: root.widgetContext
                onClicked: root.setDuration(1500)
            }
        }
    }
}