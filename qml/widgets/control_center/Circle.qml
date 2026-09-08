import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    property real currentVolume: 0.65

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    Component.onCompleted: SystemServices.requestVolume()

    Connections {
        target: SystemServices
        function onVolumeSnapshotReady(value, muted, errorString) {
            root.currentVolume = Math.max(0, Math.min(1, value));
        }
    }

    anchors.fill: parent

    readonly property real diameter: Math.min(width, height)

    function requestPaint() {
        if (volArc) volArc.requestPaint();
    }

    Canvas {
        id: volArc
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const strokeWidth = Math.max(2.5, Math.min(4.5, 3.0 + (root.diameter - 44) * 0.04));
            const radius = Math.min(cx, cy) - strokeWidth / 2 - 1.0;
            if (radius <= 0) return;

            // Background track
            ctx.strokeStyle = "#3a3a3c";
            ctx.lineWidth = strokeWidth;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.stroke();

            // Active volume arc
            if (root.currentVolume > 0.005) {
                ctx.strokeStyle = "#0a84ff";
                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";
                ctx.beginPath();
                const startAngle = -Math.PI / 2;
                const endAngle = startAngle + Math.PI * 2 * Math.min(1.0, root.currentVolume);
                ctx.arc(cx, cy, radius, startAngle, endAngle);
                ctx.stroke();
            }
        }
    }

    onCurrentVolumeChanged: volArc.requestPaint()
    onWidthChanged: volArc.requestPaint()
    onHeightChanged: volArc.requestPaint()
    onVisibleChanged: if (visible) volArc.requestPaint()

    Column {
        anchors.centerIn: parent
        spacing: Math.max(0, Math.round((root.diameter - 44) * 0.04))

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentVolume === 0 ? "󰖁" : "󰕾"
            font.family: root.iconFontFamily
            font.pixelSize: Math.max(12, Math.min(22, Math.round(14 + (root.diameter - 44) * 0.2)))
            color: "#0a84ff"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.currentVolume * 100) + "%"
            font.family: root.textFontFamily
            font.pixelSize: Math.max(9, Math.min(15, Math.round(10 + (root.diameter - 44) * 0.12)))
            font.weight: Font.Bold
            color: "white"
        }
    }
}
