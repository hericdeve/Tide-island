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

    Canvas {
        id: volArc
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

            ctx.strokeStyle = "#0a84ff";
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.beginPath();
            const startAngle = -Math.PI / 2;
            const endAngle = startAngle + Math.PI * 2 * root.currentVolume;
            ctx.arc(center, center, radius, startAngle, endAngle);
            ctx.stroke();
        }
    }

    onCurrentVolumeChanged: volArc.requestPaint()

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentVolume === 0 ? "󰖁" : "󰕾"
            font.family: root.iconFontFamily
            font.pixelSize: 14
            color: "#0a84ff"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.currentVolume * 100) + "%"
            font.family: root.textFontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
            color: "white"
        }
    }
}
