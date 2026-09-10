import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property var activePlayer: widgetContext ? widgetContext.activePlayer : null
    readonly property string currentArtUrl: widgetContext ? widgetContext.currentArtUrl : ""
    readonly property real trackProgress: widgetContext ? widgetContext.trackProgress : 0
    readonly property bool isPlaying: widgetContext ? widgetContext.isPlaying : (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing)

    readonly property real diameter: Math.min(width, height)
    readonly property real ringStrokeWidth: Math.max(2.5, Math.min(4.5, 3.0 + (root.diameter - 44) * 0.04))

    anchors.fill: parent

    WidgetProgressRing {
        anchors.fill: parent
        strokeWidth: root.ringStrokeWidth
        value: root.trackProgress
        fillColor: StyleTokens.accent
        trackColor: StyleTokens.track
    }

    ClippingRectangle {
        anchors.centerIn: parent
        width: Math.max(20, root.diameter - Math.round(root.ringStrokeWidth * 2 + 8))
        height: width
        radius: width / 2
        color: StyleTokens.track

        Image {
            anchors.fill: parent
            source: root.currentArtUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.currentArtUrl !== ""
        }

        WidgetIconGlyph {
            anchors.centerIn: parent
            glyph: root.isPlaying ? "󰎆" : "󰐊"
            size: Math.round(parent.width * 0.45)
            color: StyleTokens.textPrimary
            widgetContext: root.widgetContext
            visible: !root.currentArtUrl || root.currentArtUrl === ""
        }
    }
}
