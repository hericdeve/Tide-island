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

    Canvas {
        id: pomodoroArc
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const center = root.diameter / 2;
            const strokeWidth = Math.max(2.5, Math.min(4, 3.0 + (root.diameter - 44) * 0.04));
            const radius = center - strokeWidth / 2 - 1.0;

            ctx.strokeStyle = "#27272a";
            ctx.lineWidth = strokeWidth;
            ctx.beginPath();
            ctx.arc(center, center, radius, 0, Math.PI * 2);
            ctx.stroke();

            if (root.connected) {
                ctx.strokeStyle = root.themeColor;
                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";
                ctx.beginPath();
                const startAngle = -Math.PI / 2;
                const endAngle = startAngle + Math.PI * 2 * (1.0 - root.progress);
                ctx.arc(center, center, radius, startAngle, endAngle);
                ctx.stroke();
            }
        }
    }

    onWidthChanged: pomodoroArc.requestPaint()
    onHeightChanged: pomodoroArc.requestPaint()

    Connections {
        target: PomotroidBackend
        function onTickChanged() { pomodoroArc.requestPaint(); }
        function onTimerStateChanged() { pomodoroArc.requestPaint(); }
        function onConnectedChanged() { pomodoroArc.requestPaint(); }
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.max(0, Math.round((root.diameter - 44) * 0.05))

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeDisplay
            font.family: root.textFontFamily
            font.pixelSize: Math.max(12, Math.min(18, Math.round(13 + (root.diameter - 44) * 0.18)))
            font.weight: Font.Bold
            font.letterSpacing: -0.3
            color: "white"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.connected ? (root.roundNumber + "/" + root.roundsTotal) : "Offline"
            font.family: root.textFontFamily
            font.pixelSize: Math.max(8, Math.min(12, Math.round(9 + (root.diameter - 44) * 0.08)))
            font.weight: Font.DemiBold
            color: root.connected ? "#a1a1aa" : "#71717a"
        }
    }
}
