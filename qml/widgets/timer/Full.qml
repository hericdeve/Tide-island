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

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 7

            Row {
                width: parent.width
                height: 28

                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    WidgetIconGlyph {
                        glyph: root.mode === "stopwatch" ? "󰔛" : "󰔟"
                        size: 16
                        color: root.running ? StyleTokens.accent : StyleTokens.textSecondary
                        widgetContext: root.widgetContext
                    }

                    WidgetTextView {
                        text: root.mode === "stopwatch" ? "Stopwatch" : "Timer"
                        role: "title"
                        colorOverride: StyleTokens.textPrimary
                        widgetContext: root.widgetContext
                    }
                }

                Row {
                    spacing: 3
                    anchors.right: parent.right
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

            Item {
                width: parent.width
                height: 48

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

            Row {
                spacing: 6

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
}