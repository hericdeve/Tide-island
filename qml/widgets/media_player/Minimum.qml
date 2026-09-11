import QtQuick
import Quickshell.Services.Mpris
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property var activePlayer: widgetContext ? widgetContext.activePlayer : null
    readonly property string currentTrack: widgetContext ? widgetContext.currentTrack : ""
    readonly property string currentArtist: widgetContext ? widgetContext.currentArtist : ""
    readonly property bool isPlaying: widgetContext ? widgetContext.isPlaying : (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing)

    anchors.fill: parent

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 7

        WidgetIconGlyph {
            id: mediaIcon
            glyph: root.isPlaying ? "󰎆" : "󰐊"
            size: 14
            color: root.isPlaying ? StyleTokens.textPrimary : StyleTokens.textSecondary
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }

        WidgetTextView {
            id: trackTextView
            text: root.currentTrack !== "" ? (root.currentArtist !== "" ? root.currentTrack + " • " + root.currentArtist : root.currentTrack) : "Music"
            role: "body"
            overflowMode: "marquee"
            marqueeSpeed: 25
            maximumLineCount: 1
            colorOverride: StyleTokens.textPrimary
            width: Math.min(measuredWidth, Math.max(0, root.width - mediaIcon.width - contentRow.spacing - 12))
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
