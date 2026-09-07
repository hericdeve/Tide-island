import QtQuick

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    property int totalSeconds: 1500
    property int remainingSeconds: 1500

    readonly property real progress: totalSeconds > 0 ? (totalSeconds - remainingSeconds) / totalSeconds : 0
    readonly property string timeDisplay: {
        const mins = Math.floor(root.remainingSeconds / 60);
        return String(mins) + "m";
    }

    readonly property real diameter: Math.min(width, height)

    anchors.fill: parent

    Canvas {
        id: pomodoroArc
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const center = root.diameter / 2;
            const radius = center - 2.5;

            ctx.strokeStyle = "#3a3a3c";
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(center, center, radius, 0, Math.PI * 2);
            ctx.stroke();

            ctx.strokeStyle = "#ff453a";
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.beginPath();
            const startAngle = -Math.PI / 2;
            const endAngle = startAngle + Math.PI * 2 * (1.0 - root.progress);
            ctx.arc(center, center, radius, startAngle, endAngle);
            ctx.stroke();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰄉"
            font.family: root.iconFontFamily
            font.pixelSize: 12
            color: "#ff453a"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeDisplay
            font.family: root.textFontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
            color: "white"
        }
    }
}
