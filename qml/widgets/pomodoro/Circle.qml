import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    readonly property bool connected: PomotroidBackend.connected
    readonly property bool isRunning: PomotroidBackend.running
    readonly property bool isPaused: PomotroidBackend.paused
    readonly property string roundType: PomotroidBackend.roundType
    readonly property int elapsedSeconds: PomotroidBackend.elapsedSeconds
    readonly property int totalSeconds: PomotroidBackend.totalSeconds
    readonly property int remainingSeconds: PomotroidBackend.remainingSeconds
    readonly property double progress: PomotroidBackend.progress
    readonly property int roundNumber: PomotroidBackend.roundNumber
    readonly property int roundsTotal: PomotroidBackend.roundsTotal

    readonly property bool isWork: roundType === "work"
    readonly property bool isLongBreak: roundType === "long-break"
    readonly property color themeColor: !connected ? "#71717a" : (isWork ? "#ff453a" : (isLongBreak ? "#0a84ff" : "#30d158"))

    readonly property string timeDisplay: {
        if (!connected) return "--:--";
        return PomotroidBackend.formatTime(root.remainingSeconds);
    }

    readonly property real diameter: Math.min(width, height)

    anchors.fill: parent

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.connected) {
                PomotroidBackend.toggleTimer();
            } else {
                PomotroidBackend.launchPomotroid();
            }
        }
    }

    Canvas {
        id: pomodoroArc
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const center = root.diameter / 2;
            const radius = center - 2.5;

            ctx.strokeStyle = "#27272a";
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(center, center, radius, 0, Math.PI * 2);
            ctx.stroke();

            if (root.connected) {
                ctx.strokeStyle = root.themeColor;
                ctx.lineWidth = 3;
                ctx.lineCap = "round";
                ctx.beginPath();
                const startAngle = -Math.PI / 2;
                const endAngle = startAngle + Math.PI * 2 * (1.0 - root.progress);
                ctx.arc(center, center, radius, startAngle, endAngle);
                ctx.stroke();
            }
        }
    }

    Connections {
        target: PomotroidBackend
        function onTickChanged() { pomodoroArc.requestPaint(); }
        function onTimerStateChanged() { pomodoroArc.requestPaint(); }
        function onConnectedChanged() { pomodoroArc.requestPaint(); }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.isWork ? "󰄉" : "󱫠"
            font.family: root.iconFontFamily
            font.pixelSize: 12
            color: root.themeColor
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeDisplay
            font.family: root.textFontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
            color: "white"
        }

        Text {
            visible: root.connected
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.roundNumber + "/" + root.roundsTotal
            font.family: root.textFontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
            color: "#a1a1aa"
        }
    }
}
