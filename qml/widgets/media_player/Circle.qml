import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property var activePlayer: widgetContext ? widgetContext.activePlayer : null
    readonly property string currentArtUrl: widgetContext ? widgetContext.currentArtUrl : ""
    readonly property real trackProgress: widgetContext ? widgetContext.trackProgress : 0
    readonly property bool isPlaying: widgetContext ? widgetContext.isPlaying : (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing)
    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

    anchors.fill: parent

    readonly property real diameter: Math.min(width, height)
    readonly property real ringStrokeWidth: Math.max(2.5, Math.min(4.5, 3.0 + (root.diameter - 44) * 0.04))

    function requestPaint() {
        if (progressArc) progressArc.requestPaint();
    }

    Canvas {
        id: progressArc
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const strokeWidth = root.ringStrokeWidth;
            const radius = Math.min(cx, cy) - strokeWidth / 2 - 1.0;
            if (radius <= 0) return;

            // Background track
            ctx.strokeStyle = "#3a3a3c";
            ctx.lineWidth = strokeWidth;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.stroke();

            // Active progress
            if (root.trackProgress > 0.01) {
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";
                ctx.beginPath();
                const startAngle = -Math.PI / 2;
                const endAngle = startAngle + Math.PI * 2 * Math.min(1.0, root.trackProgress);
                ctx.arc(cx, cy, radius, startAngle, endAngle);
                ctx.stroke();
            }
        }
    }

    onTrackProgressChanged: progressArc.requestPaint()
    onWidthChanged: progressArc.requestPaint()
    onHeightChanged: progressArc.requestPaint()
    onVisibleChanged: if (visible) progressArc.requestPaint()

    ClippingRectangle {
        anchors.centerIn: parent
        width: Math.max(20, root.diameter - Math.round(root.ringStrokeWidth * 2 + 8))
        height: width
        radius: width / 2
        color: "#2c2c2e"

        Image {
            anchors.fill: parent
            source: root.currentArtUrl
            fillMode: Image.PreserveAspectCrop
            visible: root.currentArtUrl !== ""
        }

        Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "󰎆" : "󰐊"
            font.family: root.iconFontFamily
            font.pixelSize: Math.round(parent.width * 0.45)
            color: "#ffffff"
            visible: !root.currentArtUrl || root.currentArtUrl === ""
        }
    }
}
