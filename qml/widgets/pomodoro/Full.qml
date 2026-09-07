import QtQuick

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    property int totalSeconds: 1500 // 25 minutes default
    property int remainingSeconds: 1500
    property bool isRunning: false

    Timer {
        id: timer
        interval: 1000
        repeat: true
        running: root.isRunning && root.remainingSeconds > 0
        onTriggered: {
            if (root.remainingSeconds > 0) {
                root.remainingSeconds -= 1;
            } else {
                root.isRunning = false;
            }
        }
    }

    readonly property string timeDisplay: {
        const mins = Math.floor(root.remainingSeconds / 60);
        const secs = root.remainingSeconds % 60;
        return (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs);
    }

    readonly property real progress: totalSeconds > 0 ? (totalSeconds - remainingSeconds) / totalSeconds : 0

    anchors.fill: parent

    Row {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 12

        // Progress ring with time in center
        Item {
            width: Math.min(parent.height - 4, 110)
            height: width
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const center = width / 2;
                    const radius = center - 4;

                    ctx.strokeStyle = "#3a3a3c";
                    ctx.lineWidth = 4;
                    ctx.beginPath();
                    ctx.arc(center, center, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    if (root.progress > 0.001) {
                        ctx.strokeStyle = "#ff453a";
                        ctx.lineWidth = 4;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        const start = -Math.PI / 2;
                        const end = start + Math.PI * 2 * root.progress;
                        ctx.arc(center, center, radius, start, end);
                        ctx.stroke();
                    }
                }
            }

            onProgressChanged: canvas.requestPaint()

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.timeDisplay
                    font.family: root.textFontFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "white"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isRunning ? "FOCUS" : (root.remainingSeconds === 0 ? "DONE" : "PAUSED")
                    font.family: root.textFontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: root.isRunning ? "#ff453a" : "#8e8e93"
                }
            }
        }

        // Controls & Presets
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 110 - parent.spacing)
            spacing: 8

            // Preset buttons row
            Row {
                spacing: 6
                Rectangle {
                    width: 38
                    height: 22
                    radius: 6
                    color: root.totalSeconds === 1500 ? "#ff453a" : "#2c2c2e"
                    Text {
                        anchors.centerIn: parent
                        text: "25m"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isRunning = false;
                            root.totalSeconds = 1500;
                            root.remainingSeconds = 1500;
                        }
                    }
                }

                Rectangle {
                    width: 38
                    height: 22
                    radius: 6
                    color: root.totalSeconds === 300 ? "#30d158" : "#2c2c2e"
                    Text {
                        anchors.centerIn: parent
                        text: "5m"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isRunning = false;
                            root.totalSeconds = 300;
                            root.remainingSeconds = 300;
                        }
                    }
                }

                Rectangle {
                    width: 38
                    height: 22
                    radius: 6
                    color: root.totalSeconds === 900 ? "#0a84ff" : "#2c2c2e"
                    Text {
                        anchors.centerIn: parent
                        text: "15m"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isRunning = false;
                            root.totalSeconds = 900;
                            root.remainingSeconds = 900;
                        }
                    }
                }
            }

            // Play / Pause & Reset
            Row {
                spacing: 8

                Rectangle {
                    width: 58
                    height: 26
                    radius: 8
                    color: root.isRunning ? "#48484a" : "#ff453a"

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isRunning ? "󰏤" : "󰐊"
                            font.family: root.iconFontFamily
                            font.pixelSize: 12
                            color: "white"
                        }
                        Text {
                            text: root.isRunning ? "Pause" : "Start"
                            font.family: root.textFontFamily
                            font.pixelSize: 11
                            font.weight: Font.SemiBold
                            color: "white"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isRunning = !root.isRunning
                    }
                }

                Rectangle {
                    width: 50
                    height: 26
                    radius: 8
                    color: "#2c2c2e"

                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        color: "#8e8e93"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isRunning = false;
                            root.remainingSeconds = root.totalSeconds;
                        }
                    }
                }
            }
        }
    }
}
