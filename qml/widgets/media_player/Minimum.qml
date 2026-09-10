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
            glyph: root.isPlaying ? "󰎆" : "󰐊"
            size: 16
            color: root.isPlaying ? StyleTokens.textPrimary : StyleTokens.textSecondary
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }

        WidgetTextView {
            text: root.currentTrack !== "" ? (root.currentArtist !== "" ? root.currentTrack + " • " + root.currentArtist : root.currentTrack) : "Music"
            role: "title"
            overflowMode: "elide"
            maximumLineCount: 1
            colorOverride: StyleTokens.textPrimary
            width: Math.min(measuredWidth, Math.max(0, root.width - 24 - contentRow.spacing - 8))
            widgetContext: root.widgetContext
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
