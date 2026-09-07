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

    anchors.fill: parent

    readonly property real diameter: Math.min(width, height)

    Canvas {
        id: progressArc
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const center = root.diameter / 2;
            const radius = center - 2.5;

            // Background track
            ctx.strokeStyle = "#3a3a3c";
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(center, center, radius, 0, Math.PI * 2);
            ctx.stroke();

            // Active progress
            if (root.trackProgress > 0.01) {
                ctx.strokeStyle = "#b56cff";
                ctx.lineWidth = 3;
                ctx.lineCap = "round";
                ctx.beginPath();
                const startAngle = -Math.PI / 2;
                const endAngle = startAngle + Math.PI * 2 * Math.min(1.0, root.trackProgress);
                ctx.arc(center, center, radius, startAngle, endAngle);
                ctx.stroke();
            }
        }
    }

    onTrackProgressChanged: progressArc.requestPaint()

    ClippingRectangle {
        anchors.centerIn: parent
        width: root.diameter - 14
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
            color: "#b56cff"
            visible: !root.currentArtUrl || root.currentArtUrl === ""
        }
    }
}
